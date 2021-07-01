import nibabel as nib
import numpy as np

epsilon = 0.01

#load gifti surf
gii = nib.load(snakemake.input.gii)
arr = gii.get_arrays_from_intent('NIFTI_INTENT_POINTSET')[0]
vertices = arr.data


#get ref nii (for defining bbox)
img = nib.load(snakemake.input.ref_nii)
affine = img.affine
print(affine)

lower_coord = np.array([0,0,0,1])
upper_coord = np.hstack([np.subtract(img.shape[0:3],1),1])
print(lower_coord)
print(upper_coord)
    
#get bounds by taking corners of img and getting phys coords
bounds = np.vstack([affine@lower_coord,affine@upper_coord]);
print(bounds)

#drop the 4-th dim
bounds = bounds[:,0:3]
print(bounds)
#and sort from neg to pos in each dim
bounds = np.sort(bounds,0);
print(bounds)    

#replicate to enable comparison with g.vertices
minrep = np.add(np.tile(bounds[0,:],(vertices.shape[0],1))  , epsilon)
maxrep = np.subtract(np.tile(bounds[1,:],(vertices.shape[0],1))  , epsilon)
    
#get indices where too low or high
too_low = np.where(vertices<minrep);
too_high = np.where(vertices>maxrep);
print(f'surface {snakemake.input.gii}:')
print(f'{too_low[0].size} vertices below minimum')
print(f'{too_high[0].size} vertices above maximum')

#replace with the min or max
vertices[too_low] = minrep[too_low]
vertices[too_high] = maxrep[too_high]

#save gifti
nib.save(gii,snakemake.output.gii)
