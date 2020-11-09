import numpy as np

#concatenates bval or bvec files
concat_bv = np.hstack([np.loadtxt(bvfile,ndmin=2) for bvfile in snakemake.input])
np.savetxt(snakemake.output[0], concat_bv,fmt='%.5f')

