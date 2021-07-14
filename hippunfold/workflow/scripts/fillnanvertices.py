import nibabel as nib
import numpy as np

gii = nib.load('/data/mica3/jordand/testinground/test_vertexcorrect2/work/sub-01/surf_T1w/sub-01_hemi-Lflip_space-corobl_den-7k_desc-nonancorrect_outer.surf.gii')

#gii = nib.load(snakemake.input.gii)
varr = gii.get_arrays_from_intent('NIFTI_INTENT_POINTSET')[0]
V = varr.data
farr = gii.get_arrays_from_intent('NIFTI_INTENT_TRIANGLE')[0]
F = farr.data

# most nans should be just isolated points, but in case there is an island of nans this will erode it, replacing with decent (but not perfect) guesses of where vertices should be
while np.isnan(np.sum(V)):
    # index of vertices containing nan
    i = np.where(np.isnan(V))
    ii = np.unique(i[0])
    # replace with the nanmean of neighbouring vertices
    newV = V
    for n in ii:
        f = np.where(F==n)
        v = F[f[0]]
        vv = np.unique(v)
        newV[n,:] = np.nanmean(V[vv,:],0)
    V = newV

nib.save(gii,snakemake.output.gii)
