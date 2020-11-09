import nibabel as nib
import numpy as np



#get imsize for each nifti
imsizes = [nib.load(nii).header.get_data_shape() for nii in snakemake.input ]


eddy_indices = []
for i in range(0,len(imsizes)): #for each dwi nii

    index = i+1
    if len(imsizes[i]) < 4: #3d vol
        eddy_indices.append(index)
    else:
        for j in range(imsizes[i][3]):
            eddy_indices.append(index)


#write to file
np.savetxt(snakemake.output.eddy_index_txt, np.array(eddy_indices), fmt='%d')

