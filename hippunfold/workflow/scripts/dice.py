import nibabel as nib
import numpy as np

r = nib.load(snakemake.input.ref)
ref_mask = r.get_fdata()
n = nib.load(snakemake.input.res_mask)
nnunet_rois = n.get_fdata()

nnunet_bin = np.zeros(nnunet_rois.shape)
lbls = snakemake.params.hipp_lbls
for l in lbls:
    nnunet_bin[nnunet_rois==l] = 1

dice = np.sum(ref_mask[nnunet_bin==1])*2.0 / (np.sum(ref_mask) + np.sum(nnunet_bin))

#write to txt file
with open(snakemake.output.dice,'w') as f:
    f.write(str(dice))
    
