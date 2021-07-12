import nibabel as nib
import numpy as np

#Load in vector
img = nib.load(snakemake.input[0])
imgdat = img.get_fdata()
affine = img.affine

#Load in grad_dev
grad = nib.load(snakemake.input[1])
graddev = grad.get_fdata()

nodunf = np.zeros((imgdat.shape))

#Reshape grad_dev to 3x3 using column style
newgrad = graddev.reshape(graddev.shape[0],graddev.shape[1],graddev.shape[2],3,3,order='F')

#Add back identity matrix
grad_new = newgrad + np.identity(3)

#At each point in unfolded space, multiply the vector by the grad_dev
for ii in range(imgdat.shape[0]):
    for jj in range(imgdat.shape[1]):
        for kk in range(imgdat.shape[2]):
            nodunf[ii,jj,kk,:] = grad_new[ii,jj,kk,:,:] @ imgdat[ii,jj,kk,:]      



newer = nib.Nifti1Image(nodunf, affine)
nib.save(newer,snakemake.output[0])

      
