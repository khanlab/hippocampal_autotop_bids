import os
import numpy as np
import nibabel as nib

def nanChecker(A,B,E=None):
    if (np.isnan(A) == True and np.isnan(B) == True):
        C = np.NaN
    if(np.isnan(A) == True and np.isnan(B) == False):
        C = B
    if(np.isnan(A) == False and np.isnan(B) == True):
        C = A
    if(np.isnan(A) == False and np.isnan(B) == False):
        C = 0.5 * (A + B)
    return C

in_warp = snakemake.input[0]
out_jac = snakemake.output[0]

warp_nib = nib.load(in_warp)
warp_data = warp_nib.get_fdata()

#remove the singleton dimension to make easier to work with
warp_data = np.squeeze(warp_data)

#find subject number
x = in_warp.find('sub')
t =  in_warp[x:].find('/')
subnum = in_warp[x:x+t]

#find hemisphere
if 'hemi-L' in in_warp:
    hemi = 'L'
else:
    hemi = 'R'

#find which mask to use based on warp
if 'to-corobl' in in_warp:
    mask = f'work/{subnum}/{subnum}_hemi-{hemi}_space-corobl_desc-cropped_modality-T2w_autotop/coords-AP.nii.gz'
    masker = nib.load(mask)
    mask = masker.get_fdata()
    
elif 'to-cropT1w' in in_warp:
    mask = f'results/{subnum}/seg_T2w/{subnum}_dir-AP_hemi-{hemi}_space-cropT1w_coords.nii.gz'
    masker = nib.load(mask)
    mask = masker.get_fdata()

elif 'to-unfold' in in_warp:
    mask = np.ones((warp_data.shape[0:3]))

nan_warp = np.empty((warp_data.shape))

#nan out background
for i in range(warp_data.shape[0]):
    for j in range(warp_data.shape[1]):
        for k in range(warp_data.shape[2]):
            if mask[i,j,k] != 0: 
                nan_warp[i,j,k,:] = warp_data[i,j,k,:]
            else:
                nan_warp[i,j,k,:] = np.nan

#take derivative while considering nan border cases
hold = []
for a in range(3):
    E = nan_warp[:,:,:,a]
    dxEL=np.copy(E)
    dxEL[:]=np.NaN
    dxER = np.copy(dxEL)
    dxE = np.copy(dxEL)
    dyEL = np.copy(dxEL)
    dyER = np.copy(dxEL)
    dyE = np.copy(dxEL)
    dzEL = np.copy(dxEL)
    dzER = np.copy(dxEL)
    dzE = np.copy(dxEL)

    for i in range(E.shape[0]):
        for j in range(E.shape[1]):
            for k in range(E.shape[2]):
                if i+1<E.shape[0]:
                    dxEL[i, j, k] = E[i + 1, j, k] - E[i, j, k]
                if i>0:
                    dxER[i, j, k] = E[i, j, k] - E[i - 1, j, k]
                dxE[i,j,k]=nanChecker(dxEL[i, j, k],dxER[i, j, k],E[i,j,k])
                if j+1<E.shape[1]:
                    dyEL[i, j, k] = E[i , j + 1, k] - E[i, j, k]
                if j>0:
                    dyER[i, j, k] = E[i, j, k] - E[i, j-1, k]
                dyE[i, j, k] = nanChecker(dyEL[i, j, k], dyER[i, j, k],E[i,j,k])
                if k+1< E.shape[2]:
                    dzEL[i, j, k] = E[i, j, k+1] - E[i, j, k]
                if k> 0:
                    dzER[i, j, k] = E[i, j, k] - E[i, j, k-1]
                dzE[i,j,k]=nanChecker(dzEL[i, j, k],dzER[i, j, k],E[i,j,k])

    hold.append(dxE)
    hold.append(dyE)
    hold.append(dzE)

#append all derivatives
fulldat = np.array(hold)

#make shape vec for output
shape_jac = np.array(warp_data.shape)
shape_jac[3] = 9

#add all derivatives to jacobian vector. Going from 0:8 this format is: gx_wrt_u, gy_wrt_u, gz_wrt_u, gx_wrt_v ...
jac_data = np.zeros(shape_jac)
jac_data[:,:,:,0] = fulldat[0,:,:,:]
jac_data[:,:,:,1] = fulldat[3,:,:,:]
jac_data[:,:,:,2] = fulldat[6,:,:,:]
jac_data[:,:,:,3] = fulldat[1,:,:,:]
jac_data[:,:,:,4] = fulldat[4,:,:,:]
jac_data[:,:,:,5] = fulldat[7,:,:,:]
jac_data[:,:,:,6] = fulldat[2,:,:,:]
jac_data[:,:,:,7] = fulldat[5,:,:,:]
jac_data[:,:,:,8] = fulldat[8,:,:,:]

jac_nib = nib.Nifti1Image(jac_data, warp_nib.affine)

nib.save(jac_nib,out_jac)
