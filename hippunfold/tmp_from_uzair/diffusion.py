import ioFunctions
import numpy as np
import dipy
from scipy.spatial import KDTree

class diffVolume():
    def __init__(self):
        """
        Class for storing gridded volume data
        """
        self.vol = []
        self.bvals = []
        self.bvecs = []
        self.bvecs_hemi_cart=[] #these are called _hemi_ because there is a part under
        self.bvecs_hemi_sphere=[] #shells which when uncommented maps these on a hemisphere
        self.bvecs_hemi_cart_kdtree=[]
        self.inds= []
        self.gtab = []
        self.img=[]
        self.sgrad_x=[]
        self.sgrad_y = []
        self.sgrad_z = []
        self.current_signal=[]
        self.mask=[]
        self.grad_dev_nii=[]

    def getVolume(self, folder=None):
        """
        Gets volume data
        :param filename: Path of volume file
        :return:
        """
        self.vol, self.gtab =ioFunctions.loadDiffVol(folder=folder)
        self.img = self.vol.get_data()
        self.mask = ioFunctions.loadVol(filename=folder+"/nodif_brain_mask.nii.gz")

    def shells(self):
        """
        Changes the format of the bvals and bvecs to make it a bit user-friendly
        :return: Updates bvals bvecs bvecs_hemi_..., etc in class
        """
        tempbvals=[]
        tempbvals=np.round(self.gtab.bvals,-2)
        inds_sort=np.argsort(tempbvals)
        bvals_sorted=self.gtab.bvals[inds_sort]
        bvecs_sorted=self.gtab.bvecs[inds_sort]
        tempbvals=np.sort(tempbvals)
        gradbvals=np.gradient(tempbvals)
        inds_shell_cuts=np.where(gradbvals!=0)
        shell_cuts=[]
        for i in range(int(len(inds_shell_cuts[0]) / 2)):
            shell_cuts.append(inds_shell_cuts[0][i * 2])
        shell_cuts.insert(0,-1)
        shell_cuts.append(len(bvals_sorted))
        print(shell_cuts)
        print(bvals_sorted.shape)
        temp_bvals=[]
        temp_bvecs=[]
        temp_inds=[]
        for t in range(int(len(shell_cuts)-1)):
            print(shell_cuts[t]+1,shell_cuts[t + 1])
            temp_bvals.append(bvals_sorted[shell_cuts[t]+1:1+shell_cuts[t+1]])
            temp_bvecs.append(bvecs_sorted[shell_cuts[t]+1:1+shell_cuts[t+1]])
            temp_inds.append(inds_sort[shell_cuts[t]+1:1+shell_cuts[t+1]])
        self.bvals=temp_bvals
        self.bvecs=temp_bvecs
        self.inds=temp_inds
        self.inds=np.asarray(self.inds)


        pi=3.14159265
        for bvecs in self.bvecs: #this is shells
            temp_bvec = []
            temp_vec = []

            for bvec in bvecs: #this is each vector in shell
                r, theta, phi=dipy.core.sphere.cart2sphere(bvec[0],bvec[1],bvec[2])
                #if theta > pi/2: #this is the anitpodal port becareful whether this is on or off
                #    theta= pi- theta
                #    phi=phi+3.14159265
                phi=(phi)%(2*pi)
                x,y,z=dipy.core.sphere.sphere2cart(1,theta,phi)
                temp_vec.append([x,y,z])
                temp_bvec.append([r,theta,phi])
            self.bvecs_hemi_cart_kdtree.append(KDTree(temp_vec,10))
            self.bvecs_hemi_sphere.append(temp_bvec)
            self.bvecs_hemi_cart.append(temp_vec)

        self.bvecs_hemi_cart=np.asarray(self.bvecs_hemi_cart)
        self.bvecs_hemi_sphere=np.asarray(self.bvecs_hemi_sphere)
