import nibabel as nib
import numpy as np

ref_mask = nib.load(snakemake.input.ref).get_fdata()
nnunet_rois = nib.load(snakemake.input.res_mask).get_fdata()

nnunet_bin = np.zeros(nnunet_rois.shape())
for l in snakemake.params.hipp_lbls:
    nnunet_bin[nnunet_rois==l] = 1


dice = np.sum(ref_mask[nnunet_bin==1])*2.0 / (np.sum(ref_mask) + np.sum(nnunet_bin))

f = open(snakemake.output.dice,"w")
f.write(dice)
f.close()

