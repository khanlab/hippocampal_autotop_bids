import json
import nibabel as nib
import numpy as np
import sys

with open(snakemake.input.shells) as f:
  shells_dict = json.load(f)

#get bval parameter:
bval = snakemake.params.bval

#input dwi
dwi_nib = nib.load(snakemake.input.dwi)
print(dwi_nib.shape)

#create output shape
newshape = np.array(dwi_nib.shape[:3])

avg_shell = np.zeros(newshape.astype(int))


indices = shells_dict['shell_to_vol'][bval] 

if len(dwi_nib.shape) == 3 and len(indices) == 1 and indices[0] == 0:
    #we have 3d vol (e.g. b0 only), so just grab it..
    avg_shell = dwi_nib.get_fdata()[:,:,:]
elif len(dwi_nib.shape) == 4:
    #otherwise, pick out indices and average
    avg_shell = np.mean(dwi_nib.get_fdata()[:,:,:,indices],3)
else:
    #if not either of these cases, then something weird with indices and volumes
    print('unable to get map indices to get avg shell')
    sys.exit()

#now save as image
avg_shell_nii = nib.Nifti1Image(avg_shell, affine=dwi_nib.affine )
avg_shell_nii.to_filename(snakemake.output[0])
