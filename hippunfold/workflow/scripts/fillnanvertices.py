import nibabel as nib
import numpy as np

gii = nib.load(snakemake.input.gii)
varr = gii.get_arrays_from_intent('NIFTI_INTENT_POINTSET')[0]
V = varr.data
farr = gii.get_arrays_from_intent('NIFTI_INTENT_TRIANGLE')[0]
F = farr.data

# index of vertices containing nan
i = np.where(np.isnan(V))
ii = np.unique(i[0])

# replace with the nanmean of neighbouring vertices
newV = V
for n in ii:
    f = np.where(F==n)
    v = F[f[0]]
    newV[n] = np.nanmean(V[v[0]],0)
    #TODO: decide what happens if all connected vertices are also nan
V = newV

nib.save(gii,snakemake.output.gii)
