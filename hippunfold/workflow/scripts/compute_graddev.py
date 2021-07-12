import os
import numpy as np
import nibabel as nib
from scipy.linalg import polar

in_jac = snakemake.input[0] 
out_graddev = snakemake.output[0]

jac_nib = nib.load(in_jac)
jac_data = jac_nib.get_fdata()

#shape of Jacobian is (256, 128, 16, 9)

#Reshape to 3x3 for decomposition
grads = jac_data.reshape(-1,3,3,order='F')

#graddev = grads[:,:,:]/jac_nib.affine[0][0]
graddev = grads
#graddev = jac_data.reshape(-1,3,3,order='F')

temp_graddev=np.copy(graddev)
graddev[:]=np.NaN

#Polar decomposition of jacobian where we only take rotation
for g in range(0,graddev.shape[0]):
    m=temp_graddev[g,:,:]
    x = ~np.isnan(m)
    if x.all(): 
        rot, deform = polar(m)
        graddev[g,:,:]= rot

grad_hold = graddev - np.identity(3)

#reshape back to 256,128,16,9 for saving
grad_dev = grad_hold.reshape(jac_data.shape,order='F')

grad_nib= nib.Nifti1Image(grad_dev,jac_nib.affine)
nib.save(grad_nib,out_graddev)

