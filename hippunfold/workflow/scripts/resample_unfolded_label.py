import numpy as np
import scipy
import nibabel as nib
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
from scipy.interpolate import RegularGridInterpolator

n_ap = snakemake.config['unfold_mesh_ref']['dims'][0]
n_pd = snakemake.config['unfold_mesh_ref']['dims'][1]
start_ap = snakemake.config['unfold_mesh_ref']['start'][0]
end_ap = snakemake.config['unfold_mesh_ref']['end'][0]
start_pd = snakemake.config['unfold_mesh_ref']['start'][1]
end_pd = snakemake.config['unfold_mesh_ref']['end'][1]


# in label 
# in current surf (to define input grid)
# in new surf (to define new grid)
# out label


#  might be easier to assume 256x126 grid, and use regular grid interpolator
# -- then, wouldn't need current surf

#load average surface area metric
label_gii = nib.load(snakemake.input.label)
arr_label = label_gii.get_arrays_from_intent('NIFTI_INTENT_LABEL')[0].data.reshape(n_pd,n_ap).transpose()

print(arr_label.shape)
# create an interpolator to sample the surfarea on each new grid
orig_x = np.linspace(start_ap,end_ap,n_ap) #since the original flat space was offset a bit from 0-40,0-20
orig_y = np.linspace(start_pd,end_pd,n_pd)
print(orig_x.shape)
print(orig_y.shape)

interpolator = RegularGridInterpolator((orig_x, orig_y), arr_label,method='nearest')

#interpolate at the points of the new grid
surf_gii = nib.load(snakemake.input.new_surf)
new_vertices = surf_gii.get_arrays_from_intent('NIFTI_INTENT_POINTSET')[0].data

print(f'shape of new_vertices before: {new_vertices.shape}')
new_vertices[:,0] = -new_vertices[:,0]
new_vertices[:,1] = new_vertices[:,1]+200

print(f'shape of new_vertices after: {new_vertices.shape}')

print(np.min(new_vertices,0))
print(np.max(new_vertices,0))
interpolated = interpolator((new_vertices[:,0],new_vertices[:,1]))

    
print(f'interpolated.shape: {interpolated.shape}')

#write to nii
nib_nii = nib.nifti1.Nifti1Image(interpolated,affine=np.eye(4))
nib_nii.to_filename(snakemake.output.label_nii)

