import json
import nibabel as nib
import numpy as np


with open(snakemake.input.shells) as f:
  shells_dict = json.load(f)

nshells = len(shells_dict['shells'])
print(f'nshells: {nshells}')
dwi_nib = nib.load(snakemake.input.dwi)
print(dwi_nib.shape)
#create output shape
newshape = np.zeros([4,])
newshape[:3] = np.array(dwi_nib.shape[:3])
newshape[3] = nshells
#newshape = np.array([dwi_nib.shape[:3].asarray(),nshells])
print(newshape)
avg_shells = np.zeros(newshape.astype(int))


for i,shell in enumerate(shells_dict['shells']):
   indices = shells_dict['shell_to_vol'][str(shell)] 
   avg_shells[:,:,:,i] = np.mean(dwi_nib.get_fdata()[:,:,:,indices],3)

#now save as image
avg_shells_nii = nib.Nifti1Image(avg_shells, affine=dwi_nib.affine )
avg_shells_nii.to_filename(snakemake.output[0])
