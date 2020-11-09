import nibabel as nib
import json
import numpy as np


#load nifti
bzero = nib.load(snakemake.input.bzero_nii)

#load json
with open(snakemake.input.json) as f:
  json_dwi = json.load(f)

#print(bzero.header)
#print(json_dwi)

imsize = np.array(bzero.header.get_data_shape())

phenc_axis = json_dwi['PhaseEncodingDirection'][0] #either i, j, k

if phenc_axis == 'i':
    vec = np.array([1,0,0])
elif phenc_axis == 'j':
    vec = np.array([0,1,0])
elif phenc_axis == 'k':
    vec = np.array([0,0,1])

#print(f'vec: {vec}')
#print(f'imsize: {imsize}')

numPhaseEncodes = imsize[np.where(vec>0)]

#print(f'numPhaseEncodes: {numPhaseEncodes}')

#check for i-, j-, k-; flip to -1 if so..
if (len(json_dwi['PhaseEncodingDirection']) == 2):
    if json_dwi['PhaseEncodingDirection'][1] == '-':
        vec[ np.where(vec>0)] = -1

#create the phenc_line row
phenc_line = np.hstack([ vec, np.array(json_dwi['EffectiveEchoSpacing'] * numPhaseEncodes) ])


#replicate to the number of volumes, if it is 4d
if len(imsize)==4:
    phenc_data = np.tile(phenc_line,[imsize[3],1])
else:
    phenc_data = np.column_stack(phenc_line) 
    #need to column_stack so that it becomes 2d array
    # otherwwise savetxt will always save 1d array as column..

#save to txt
np.savetxt(snakemake.output.phenc_txt, phenc_data, fmt='%.5f')


