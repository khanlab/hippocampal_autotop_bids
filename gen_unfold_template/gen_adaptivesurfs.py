import numpy as np
import scipy
import nibabel as nib
import matplotlib.pyplot as plt
from scipy.spatial import Delaunay
import matplotlib
matplotlib.use('Agg')
from scipy.interpolate import RegularGridInterpolator


# this script creates a mesh with triangulation density locally-adaptive based on an average surface area.

# the original grid spacing was 128 points over 20mm (or 20/128)

# since surf vertex area is proportional to grid spacing squared,
# if S_target and S_in are the target and input surface areas, then,
# adjustment to get corrected grid spacing: 

# (20/N)^2 = (S_target / S_in)  * (20/128)^2

# equiv to:
# N = 128 * sqrt(S_in / S_target)


# the approach this script takes is to create a set of grids at diff resolutions, and pick the grid points based on the binned input surface area..

# all the points from the different resolutions are then triangulated


target_surfarea = snakemake.params.targetarea
num_bins = snakemake.params.nbins

n_ap = snakemake.config['in_surfarea']['dims'][0]
n_pd = snakemake.config['in_surfarea']['dims'][1]
start_ap = snakemake.config['in_surfarea']['start'][0]
end_ap = snakemake.config['in_surfarea']['end'][0]
start_pd = snakemake.config['in_surfarea']['start'][1]
end_pd = snakemake.config['in_surfarea']['end'][1]


#load average surface area metric
surfarea_gii = nib.load(snakemake.input.surfarea_gii)
arr_surfarea = surfarea_gii.get_arrays_from_intent('NIFTI_INTENT_NORMAL')[0].data.reshape(n_pd,n_ap)


#replace nan with 0.01 (actually, shouldn't be any nans with the latest workflow) 
arr_surfarea = np.nan_to_num(arr_surfarea,nan=0.01)

#bin the image into discrete regions using histogram
(histval,histedges) = np.histogram(arr_surfarea.flat,bins=num_bins)
binned_area = np.zeros(arr_surfarea.shape)

for i in range(len(histedges)-1):

    masked = np.logical_and(arr_surfarea>=histedges[i],arr_surfarea<histedges[i+1])
    binned_area[masked] = i

print(binned_area.shape)



# create an interpolator to sample the surfarea on each new grid

orig_x = np.linspace(start_ap,end_ap,n_ap) #since the original flat space was offset a bit from 0-40,0-20
orig_y = np.linspace(start_pd,end_pd,n_pd)
print(orig_x)
print(orig_y)

#now, for each multi-res grid, interpolate the bin value
interpolator = RegularGridInterpolator((orig_y, orig_x), binned_area,method='nearest')




multires_points = list()

#create grid for each bin centre
for i in range(len(histedges)-1):
    
    in_surfarea = (histedges[i] + histedges[i+1]) * 0.5 # histogram bin centre 
    #bin_centre is the mean vertex area for those vertices


    # adjustment to get corrected grid spacing (1/N)
    # 1/N = (S_target / S_in)^2  * (1/128)

    # equiv to:
    # N = 128 * sqrt(S_in / S_target)

    print(f'input surf area at bin {i}: {in_surfarea}')

    
    N = int(128 * np.sqrt(in_surfarea/ target_surfarea))
    #N = int(snakemake.params.scaling_factor * np.power(in_surfarea / target_surfarea,snakemake.params.power_factor))
    print(f'N for gridding is: {N}')
    print(N)

    nx, ny = (2*N,N)
    x = np.linspace(start_ap,end_ap, nx)
    y = np.linspace(start_pd,end_pd, ny)
    #print(x)
    #print(y)
    xv, yv = np.meshgrid(y,x)

   # print(xv.max())
   # print(yv.max())
    binval = interpolator((xv,yv))

    #now get points for the binval
    #coords = np.unravel_index(np.where(binval==i),xv.shape)
    #print(coords)

    coords_x = xv[np.where(binval==i)]
   # print(coords_x)

    coords_y = yv[np.where(binval==i)]
   # print(coords_y)

    multires_points.append(np.transpose(np.vstack((coords_x,coords_y))))


all_points = np.vstack(multires_points)
print(all_points.shape)

#plot a grid
tri = Delaunay(all_points)
plt.figure(figsize=(50,100))
plt.triplot(all_points[:,0], all_points[:,1], tri.simplices)
plt.plot(all_points[:,0], all_points[:,1], '.')
plt.savefig(snakemake.output.grid_png)


#write the vertices and triangles as csv 
#so we can create gifti from matlab

nverts = all_points.shape[0]
print(f'nverts: {nverts}')
nbins = num_bins
vertices_fname = snakemake.output.points_csv
triangles_fname = snakemake.output.triangles_csv


np.savetxt(vertices_fname,tri.points,fmt='%f')
np.savetxt(triangles_fname,tri.simplices,fmt='%u')

