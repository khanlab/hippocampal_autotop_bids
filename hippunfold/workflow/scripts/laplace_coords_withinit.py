import nibabel as nib
import numpy as np
from astropy.convolution import convolve as nan_convolve


logfile = open(snakemake.log[0], 'w')


# this function solves the Laplace equation for Anterior-Posterior, Proximal-distal, and Inner-Outer axes of the hippocamps
convergence_threshold = snakemake.params.convergence_threshold
max_iters = snakemake.params.max_iters

print(f'Starting laplace solver', file=logfile, flush=True)
# initialize foreground (gm), source, and sink

lblnib = nib.load(snakemake.input.lbl[0])
lbl = lblnib.get_fdata()

print(f'Loaded lbl', file=logfile, flush=True)

try:
    print(f'initializing laplace coords with {snakemake.params.init_coords}', file=logfile, flush=True)
    init_coords_nib = nib.load(snakemake.params.init_coords)
    init_coords = init_coords_nib.get_fdata()
except:
    print(f'no initializing laplace coords found', file=logfile, flush=True)
    init_coords = []


idxgm = np.zeros(lbl.shape)
for i in snakemake.params.gm_labels:
    idxgm[lbl==i] = 1

source = np.zeros(lbl.shape)
for i in snakemake.params.src_labels:
    source[lbl==i] = 1

sink = np.zeros(lbl.shape)
for i in snakemake.params.sink_labels:
    sink[lbl==i] = 1


# set up filter (18NN)
hl=np.zeros([3,3,3])
hl[1,:,:] = 1
hl[:,1,:] = 1
hl[:,:,1] = 1
hl[1,1,1] = 0
hl = hl/np.sum(hl)

# initialize coords, setting outside domain to nan
bg = 1-idxgm
bg[source==1] = 0
bg[sink==1] = 0
if bool(init_coords):
    coords = init_coords
else:
    coords = idxgm - 0.5
coords[bg==1] = np.nan
coords[sink==1] = 1

upd_coords = coords.copy()

# iterate until the solution doesn't change anymore (or reach max iters)
for i in range(max_iters): 

 # debug: save niftis to check progress 
 #   if (i % 100 == 0):
 #       tonii = coords.copy()
 #       tonii[np.isnan(tonii)] = -1
 #       nib.Nifti1Image(tonii,lbl_nib.affine,lbl_nib.header).to_filename(f'debug_iter-{i:02d}.nii')


    upd_coords = nan_convolve(coords,hl,preserve_nan=True)
    
    upd_coords[source==1] = 0
    upd_coords[sink==1] = 1

    #check difference between last
    diff_coords = coords - upd_coords
    diff_coords[np.isnan(diff_coords)] = 0
    ssd = (diff_coords * diff_coords).sum(axis=None)

    print(f'i: {i}, ssd: {ssd}', file=logfile, flush=True)
    if ssd < convergence_threshold:
        print(f'ssd less than {convergence_threshold}, stopping..', file=logfile, flush=True)
        break
   
    coords = upd_coords

coords[idxgm==0] = np.nan #setting outside GM to nan -- this was zero before.. 


#save file
coords_nib = nib.Nifti1Image(coords,lblnib.affine,lblnib.header)
nib.save(coords_nib,snakemake.output.coords)

logfile.close()
