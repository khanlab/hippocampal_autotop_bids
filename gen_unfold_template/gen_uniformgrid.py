import numpy as np
import scipy
import matplotlib.pyplot as plt
from scipy.spatial import Delaunay
import matplotlib
matplotlib.use('Agg')

multires_points = list()


N=128

print(f'N for gridding is: {N}')
nx, ny = (2*N,N)
print(f'nx: {nx}')
print(f'ny: {ny}')
x = np.linspace(0,40, nx)
y = np.linspace(0,20, ny)
print(x)
print(y)
coords_x, coords_y = np.meshgrid(y, x)
print(coords_x.shape)
print(coords_y.shape)

all_points = np.transpose(np.vstack((coords_x.flat,coords_y.flat)))


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
vertices_fname = snakemake.output.points_csv
triangles_fname = snakemake.output.triangles_csv


np.savetxt(vertices_fname,tri.points,fmt='%f')
np.savetxt(triangles_fname,tri.simplices,fmt='%u')

