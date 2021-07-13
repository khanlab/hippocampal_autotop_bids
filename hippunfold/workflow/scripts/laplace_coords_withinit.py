import nibabel as nib
import numpy as np
from astropy.convolution import convolve as nan_convolve


logfile = open(snakemake.log[0], 'w')
print(f'starting', file=logfile, flush=True)
# this function solves the Laplace equation for Anterior-Posterior, Proximal-distal, and Inner-Outer axes of the hippocamps
convergence_threshold = snakemake.params.convergence_threshold
max_iters = snakemake.params.max_iters


# initialize foreground (gm), source, and sink

lbl_nib = nib.load(snakemake.input.lbl)
lbl = lbl_nib.get_fdata()
print(f'loaded lbl', file=logfile, flush=True)

try:
    init_coords_nib = nib.load(snakemake.input.init_coords)
except:
    init_coords_nib = nib.load(snakemake.input.init_coords[0])
init_coords = init_coords_nib.get_fdata()
print(f'loaded init', file=logfile, flush=True)

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
coords = init_coords
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
coords_nib = nib.Nifti1Image(coords,lbl_nib.affine,lbl_nib.header)
nib.save(coords_nib,snakemake.output.coords)

logfile.close()
