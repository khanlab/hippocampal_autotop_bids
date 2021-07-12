import pandas as pd
import numpy as np
import nibabel as nib

#Designed to take in an ITK affine transform and apply it to a bvector file. Will save resulting transformed bvec to savingpath

transformfile = snakemake.input[1]
data = pd.read_csv(transformfile)
#This part is very specific to the way ITK provides transforms
x = data.iloc[2][0][12:]
x = x.split()
arr = np.array(x)

trans = arr[0:9]
translation = arr[9:]

transform = np.zeros(9)

for i in range(len(trans)):
    transform[i] = float(trans[i])  

transform = transform.reshape((3,3))

vecfile = snakemake.input[0]
vec = nib.load(vecfile)
nodvec = vec.get_fdata()
affine = vec.affine

#coords = snakemake.input[2]
#coord = nib.load(coords)
#affine = coord.affine


nodvecCO = np.zeros((nodvec.shape))

for ii in range(nodvec.shape[0]):
    for jj in range(nodvec.shape[1]):
        for kk in range(nodvec.shape[2]):
            nodvecCO[ii,jj,kk,:] = transform @ nodvec[ii,jj,kk,:]      




savingpath = snakemake.output[0]

newer = nib.Nifti1Image(nodvecCO, affine)
nib.save(newer,savingpath)
