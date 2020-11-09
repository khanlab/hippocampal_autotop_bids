import numpy as np
import json

#TO DO -- finish this script, to merge json files
with open(snakemake.input[0]) as f:
  json_dwi = json.load(f)


#load slice timing
slice_timing = np.array(json_dwi['SliceTiming'])

#arg sorting has the order in which slices were acquired
arg_sorting = np.argsort(slice_timing)

#number of slice groups (by # of unique slice times)
sg = len(set(slice_timing))

#multiband factor
mb = int(len(slice_timing) / sg)

#reshape arg_sorting to get slspec
slspec = np.reshape(arg_sorting,[sg,mb])

#then sort each row to make prettier
slspec = np.sort(slspec,axis=1)

#write to txt
np.savetxt(snakemake.output[0], slspec, fmt='%d')
