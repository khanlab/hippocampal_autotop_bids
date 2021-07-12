import diffusion
import coordinates
import numpy as np
import nibabel as nib
from scipy.interpolate import griddata, LinearNDInterpolator, Rbf
import copy
from scipy.spatial import KDTree
#from pyshtools.shtools import SHExpandLSQ, MakeGridPoint

class unfoldSubject:
    def __init__(self):
        self.coords= []
        self.T1= []
        self.diff = diffusion.diffVolume()
        self.diffUnfold=[]
        self.diffUnfoldNograd=[]
        # -------put other volumes functions----------------#

        # -----------------------------------------------#

    def loadCoordinates(self,path=None,prefix=None):
        self.coords=coordinates.coordinates(path,prefix)

    def loadDiffusion(self,path=None):
        self.diff.getVolume(folder=path)
        self.diff.shells()

    #-------put other load functions----------------#

    #-----------------------------------------------#

    def pushToUnfold(self,volume_nii=None,type=None):

        if type=='diffusion':
            volume_nii=copy.deepcopy(self.diff.vol)
        interp='nearest'
        function='linear'
        Xuvw = self.coords.X_uvwa_nii.get_data()
        Yuvw = self.coords.Y_uvwa_nii.get_data()
        Zuvw = self.coords.Z_uvwa_nii.get_data()

        condition=np.isnan(Xuvw) == 1

        Xuvw[condition] = 0
        Yuvw[condition] = 0
        Zuvw[condition] = 0

        Ndims=volume_nii.header['dim']
        size = tuple(self.coords.X_uvwa_nii.header['dim'][1:4])
        if Ndims[0]>3:
            size=size+ (Ndims[4],)
            volume_out_nii=np.zeros(size) #not yet nifti
            volume_out_nii[volume_out_nii==0]=np.NaN
            for i in range(0,Ndims[4]):
                print("vol: %d" % (i))
                points,S = coordinates.getPointsData(volume_nii,i)
                #interpolator = LinearNDInterpolator(points, S)
                interpolator = Rbf(points[:,0],points[:,1],points[:,2],S, function=function)
                #temp=griddata(points,S,(Xuvw,Yuvw,Zuvw),method=interp)
                temp = interpolator(Xuvw, Yuvw, Zuvw)
                temp[condition]=np.NaN
                volume_out_nii[:,:,:,i]=temp
            volume_out_nii=nib.Nifti1Image(volume_out_nii,self.coords.X_uvwa_nii.affine)
        else:
            volume_out_nii = np.zeros(size)  # not yet nifti
            volume_out_nii[volume_out_nii==0]=np.NaN
            points, S = coordinates.getPointsData(volume_nii)
            #interpolator = LinearNDInterpolator(points, S)
            interpolator = Rbf(points[:,0],points[:,1],points[:,2], S,function=function)
            #volume_out_nii= griddata(points, S,(Xuvw,Yuvw,Zuvw),method=interp)
            volume_out_nii=interpolator((Xuvw, Yuvw, Zuvw))
            volume_out_nii[condition] = np.NaN
            volume_out_nii = nib.Nifti1Image(volume_out_nii, self.coords.X_uvwa_nii.affine)

        if type==None:
            return volume_out_nii

        if type=='diffusion':
            self.diffUnfold=copy.deepcopy(self.diff)
            self.diffUnfold.vol=volume_out_nii
            self.diffUnfold.grad_dev_nii=self.coords.gradDevUVW_nii
            self.diffUnfold.mask = self.makeMask(self.diffUnfold.vol)

            # print("Creating diffusion volume with nograd")
            # self.diffUnfoldNograd=diffusion.diffVolume()
            # self.diffUnfoldNograd.vol= self.diffNoGradDev()
            # self.diffUnfoldNograd.mask=copy.deepcopy(self.diffUnfold.mask)


    def makeMask(self,volume_nii):
        volume_out_nii=copy.deepcopy(self.coords.X_uvwa_nii.get_fdata())
        volume_out_nii[np.isnan(volume_out_nii)==0]=1
        return nib.Nifti1Image(volume_out_nii,self.coords.X_uvwa_nii.affine)

    def invDistInterp(self,tree, S, vec):
        if S.shape[0] < 3:
            NN = 1
        else:
            NN = 20
        dis, inds = tree.query(vec, NN)
        p = 1
        dis=np.arcsin(dis/2)
        w = 1/ dis ** p
        S = S[inds]
        return np.sum(S * w) / np.sum(w)


    def diffNoGradDev(self):



        diff_no_grad_nii = np.zeros(self.diffUnfold.vol.get_data().shape)
        diff_no_grad_nii[:]=np.NaN
        graddevsum=np.sum(self.coords.gradDevUVW_nii.get_data(),axis=3)
        inds=np.asarray(np.where(np.isnan(graddevsum)==0))
        S=self.diffUnfold.vol.get_data()[inds[0],inds[1],inds[2],:]
        gd=self.coords.gradDevUVW_nii.get_data()[inds[0],inds[1],inds[2],:]
        gd=gd.reshape([len(inds[0]),3,3],order='F')
        #we want to generate a new image with bval directions
        for shell in range(0,len(self.diffUnfold.bvecs)):
            print(shell)
            bvecs=np.array( self.diffUnfold.bvecs_hemi_cart[shell])
            S_shell = S[:,self.diffUnfold.inds[shell]]
            S_shell_out=copy.deepcopy(S_shell)
            S_shell_out[:]=np.NaN

            for p in range(0,len(inds[0])):
                J=(gd[p,:,:])+np.eye(3)
                Jbvecsp=np.einsum('ij,bj->bi',J,bvecs)
                Jbvecs=copy.deepcopy(Jbvecsp)
                for b in range(0,Jbvecs.shape[0]):
                    Jbvecs[b,:]= np.asarray( Jbvecsp[b,:])/np.asarray( np.linalg.norm(Jbvecsp[b,:]))
                Jbvecs_tree=KDTree(Jbvecs,20)
                b=0
                for bvec in bvecs:
                    if shell > 0:
                        diff_no_grad_nii[inds[0][p],
                                         inds[1][p],
                                         inds[2][p],
                                         self.diffUnfold.inds[shell][b]]=self.invDistInterp(Jbvecs_tree,S_shell[p,:],bvec)
                    else:
                         diff_no_grad_nii[inds[0][p], inds[1][p], inds[2][p], self.diffUnfold.inds[shell][b]]=S_shell[p,0]
                    b=b+1

        return nib.Nifti1Image(diff_no_grad_nii,self.diffUnfold.vol.affine)









