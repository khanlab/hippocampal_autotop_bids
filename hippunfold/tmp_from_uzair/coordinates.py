import ioFunctions
import numpy as np
from scipy.interpolate import griddata, LinearNDInterpolator, Rbf
from scipy.spatial import KDTree
import nibabel as nib
import copy
from scipy.linalg import polar


class domainParams:
    def __init__(self,min_a,max_a,min_b,max_b,min_c,max_c,dims=[None],deltas=[None]):
        self.min_a = min_a
        self.max_a = max_a
        self.min_b = min_b
        self.max_b = max_b
        self.min_c = min_c
        self.max_c = max_c
        if dims[0]==None and deltas[0]==None:
            raise ValueError('Please provide either number of voxels dims=[Na,Nb,Nc] or provide'
                             'size of voxels deltas=[da,db,dc] if both provided, dims is taken'
                             ' and deltas are discarded')
        if dims[0] !=None:
            self.Na = dims[0]
            self.Nb = dims[1]
            self.Nc = dims[2]
            # self.da = (max_a - min_a) / (self.Na - 1)
            # self.db = (max_b - min_b) / (self.Nb - 1)
            # self.dc = (max_c - min_c) / (self.Nc - 1)
            self.da = self.delta(max_a,min_a,self.Na)
            self.db = self.delta(max_b,min_b,self.Nb)
            self.dc = self.delta(max_c,min_c,self.Nc)
        else:
            self.da = deltas[0]
            self.db = deltas[1]
            self.dc = deltas[2]
            # self.Na = round((max_a - min_a) / self.da + 1)
            # self.Nb = round( (max_b - min_b) / self.db + 1)
            # self.Nc = round((max_c - min_c) / self.dc + 1)
            self.Na = self.number(max_a,min_a,self.da)
            self.Nb = self.number(max_b,min_b,self.db)
            self.Nc = self.number(max_c,min_c,self.dc)

        self.affine = np.asarray([[ self.da,       0,       0,    self.min_a],
                                 [        0, self.db,       0,    self.min_b],
                                 [        0,       0, self.dc,    self.min_c],
                                 [        0,       0,       0,             1]])
        self.A, self.B,self.C = self.makeMeshGrid()

        
    def makeMeshGrid(self):
        A = np.linspace(self.min_a, self.max_a, self.Na)
        B = np.linspace(self.min_b, self.max_b, self.Nb)
        C = np.linspace(self.min_c, self.max_c, self.Nc)
        return np.meshgrid(A, B, C, indexing='ij')

    def griddata3(self,points,S):
        Sout1 = griddata(points, S[0], (self.A, self.B, self.C))
        Sout2 = griddata(points, S[1], (self.A, self.B, self.C))
        Sout3 = griddata(points, S[2], (self.A, self.B, self.C))
        return [Sout1, Sout2, Sout3]

    def interpolator3(self,interps):
        Sout1 = interps[0](self.A, self.B, self.C)
        Sout2 = interps[1](self.A, self.B, self.C)
        Sout3 = interps[2](self.A, self.B, self.C)
        return [Sout1, Sout2, Sout3]

    def delta(self,xx,x,N):
        if N==1:
            return xx-x
        if N>1:
            return (xx-x)/(N-1)

    def number(self,xx,x,dx):
        #if dx<xx-x:
        return round((xx-x)/dx+1)
        #else:
        #    return 1


def getPointsData(img_nii, i=None):
    if i == None:
        S = img_nii.get_fdata()
        inds = np.transpose(np.asarray(np.where(np.isnan(S) == 0)))
        S = S[np.isnan(S) == 0]
    else:
        S = img_nii.get_fdata()[:, :, :, i]
        inds = np.transpose(np.asarray(np.where(np.isnan(S) == 0)))
        S = S[np.isnan(S) == 0]

    worlds = toWorld(img_nii, inds)
    X = worlds[:, 0]
    Y = worlds[:, 1]
    Z = worlds[:, 2]

    points = np.asarray([X, Y, Z]).transpose()

    return points, S

def applyMask(U, V, W, dParams):
    """
    Makes a mask based on min max of curvilinear coordinates
    :param U,V,W: Coordinates
    :param dParams: domain parameter class dParams
    :return:
    """
    condition = np.invert(((U >= dParams.min_a) &
                           (U <= dParams.max_a) &
                           (V >= dParams.min_b) &
                           (V <= dParams.max_b) &
                           (W >= dParams.min_c) &
                           (W <= dParams.max_c)))

    U[condition] = np.NaN
    V[condition] = np.NaN
    W[condition] = np.NaN

    return U, V, W


def toWorld(nii,inds):
    world = []
    for ind in inds:
        world.append(np.matmul(nii.affine,np.append(ind,1))[0:3])
    return np.asarray(world)

def toInds(nii,worlds):
    affine=np.linalg.inv(nii.affine)
    inds=[]
    for world in worlds:
        inds.append((np.matmul(affine,np.append(world,1)))[0:3])
    return np.asarray(inds)

class coordinates:
    """
    this is a class to handle various operations
    related to 3d coordinates defined on usual
    cartesian coordinates
    """
    def __init__(self,path=None,prefix=None):

        self.U_xyz_nii=[] #original coordinates that are loaded in (3D)
        self.V_xyz_nii=[]
        self.W_xyz_nii=[]

        self.Ua_xyz_nii = [] #coordinates after meanlength correction (3D)
        self.Va_xyz_nii = []
        self.Wa_xyz_nii = []

        self.X_uvwa_nii=[] #this will be in world coordinates in terms of arc length corrected coords
        self.Y_uvwa_nii=[]
        self.Z_uvwa_nii=[]

        self.X_uvw_low = []  # these are low res mostly just to calculate arc length (can be made local)
        self.Y_uvw_low = []  # these are low res mostly just to calculate arc length (can be made local)
        self.Z_uvw_low = []  # these are low res mostly just to calculate arc length (can be made local)

        # the following may not need to be kept in memory
        self.mean_u = []
        self.mean_v = []
        self.mean_w = []
        self.grads = []
        self.cumsum=[]

        #misc but likely important to hold on to
        self.listsInds=[]
        self.Uparams=[]
        self.Nparams=[]
        self.gradDevXYZ_nii=[]
        self.gradDevUVW_nii=[]
        self.gradDevPolarDecompUVW_nii=[]

        #for interpolation
        #linear interpolants
        self.FX_uvwa=  []
        self.FY_uvwa = []
        self.FZ_uvwa = []
        self.FUa_xyz = []
        self.FVa_xyz = []
        self.FWa_xyz = []
        #radial basis interpolants #these are very memory hungry, nor reliable
        self.rFX_uvwa = []
        self.rFY_uvwa = []
        self.rFZ_uvwa = []
        self.rFUa_xyz = []
        self.rFVa_xyz = []
        self.rFWa_xyz = []
        self.U = []  # these are as lists, XYZ is in world coordinates, size of lists inferred from inputs can be used
        self.V = []  # to make kinds of interpolations
        self.W = []
        self.X = []
        self.Y = []
        self.Z = []
        self.Ua = []
        self.Va = []
        self.Wa = []

        #initial calculations
        self.loadCoordinates(path,prefix)
        self.initialize()

    def loadCoordinates(self,path=None,prefix=None):
        if path is None:
            raise ValueError("Please provide path (with trailing slash) for nifti coordinate files, path=...")
        if prefix is None:
            raise ValueError("Please provide provide prefix for coordinates. prefix=... "
                             "Coordinates should end with ...U.nii.gz, ...V.nii.gz, ...W.nii.gz")


        self.U_xyz_nii = ioFunctions.loadVol(path+prefix+"U.nii.gz")
        self.V_xyz_nii = ioFunctions.loadVol(path+prefix+"V.nii.gz")
        self.W_xyz_nii = ioFunctions.loadVol(path+prefix+"W.nii.gz")

    def initialize(self):

        self.meanArcLength()
        self.nativeUnfold()

    def meanArcLength(self):

        print("Inverting coordinates...")
        #extract lists for original loaded coordinates
        self.U = self.U_xyz_nii.get_data()[np.isnan(self.U_xyz_nii.get_data()) == 0]
        self.V = self.V_xyz_nii.get_data()[np.isnan(self.V_xyz_nii.get_data()) == 0]
        self.W = self.W_xyz_nii.get_data()[np.isnan(self.W_xyz_nii.get_data()) == 0]

        #inds for the above lists
        inds = np.transpose(np.asarray(np.where(np.isnan(self.U_xyz_nii.get_data()) == 0)))
        self.listsInds=inds
        worlds = toWorld(self.U_xyz_nii, inds)

        #convert inds to world
        self.X = worlds[:, 0]
        self.Y = worlds[:, 1]
        self.Z = worlds[:, 2]

        ######----------- compute mean arclength----------------------------######
        N = 25  # make a low res NxNxN grid and calculate arclength
        UALParams = domainParams(min(self.U), max(self.U), 
                                 min(self.V), max(self.V), 
                                 min(self.W), max(self.W), dims=[N, N, N])

        # create X_uvw, Y_uvw, Z_uvw for mean arclength
        points = np.asarray([self.U, self.V, self.W]).transpose()

        print("Computing mean arc lengths...")
        #interpolant for x,y,z in terms of original coordinates
        # tempFXuvw=LinearNDInterpolator(points,self.X)
        # tempFYuvw=LinearNDInterpolator(points,self.Y)
        # tempFZuvw=LinearNDInterpolator(points,self.Z)

        #xyz in terms of original uvw (low res) to perform intergration for arc length
        #[self.X_uvw_low, self.Y_uvw_low, self.Z_uvw_low] = UALParams.interpolator3([tempFXuvw,
                                                                              #tempFYuvw,
                                                                              #tempFZuvw])
        [self.X_uvw_low, self.Y_uvw_low, self.Z_uvw_low]=UALParams.griddata3(points,[self.X,self.Y,self.Z])

        #some quantitites needed to do integration (probably should be local variables in later versions)
        self.grads=np.zeros((3,3)+self.X_uvw_low.shape)
        self.cumsum=np.zeros((3,)+self.X_uvw_low.shape)
        self.grads[:]=np.NaN
        self.cumsum[:] = np.NaN
        cumsum=np.zeros((3,)+self.X_uvw_low.shape)

        #writing as a list
        Xi_uvw_a=[self.X_uvw_low, self.Y_uvw_low, self.Z_uvw_low]

        #compute the grads
        for i in range(0,3):
            #self.grads[i][0],self.grads[i][1],self.grads[i][2]= np.gradient(Xi_uvw_a[i],edge_order=1)
            self.grads[i][0], self.grads[i][1], self.grads[i][2] = self.gradientNaN(Xi_uvw_a[i])

        #calculate the distances
        for i in range(0,3):
            cumsum[i]=np.sqrt(self.grads[0][i]*self.grads[0][i]+ \
                      self.grads[1][i] * self.grads[1][i] + \
                      self.grads[2][i] * self.grads[2][i])

        #calculate cumalative sum
        for i in range(0,3):
            self.cumsum[i] = np.nancumsum(cumsum[i], axis=i)

        #now calculate the mean arclenth
        self.mean_u = abs(self.cumsum[0][0, :, :] - self.cumsum[0][-2, :, :])
        self.mean_v = abs(self.cumsum[1][:, 0, :] - self.cumsum[1][:, -2, :])
        self.mean_w = abs(self.cumsum[2][:, :, 0] - self.cumsum[2][:,  :,-2])
        self.mean_u[self.mean_u == 0] = np.NaN
        self.mean_v[self.mean_v == 0] = np.NaN
        self.mean_w[self.mean_w == 0] = np.NaN
        self.mean_u = np.nanmean(self.mean_u.flatten())
        self.mean_v = np.nanmean(self.mean_v.flatten())
        self.mean_w = np.nanmean(self.mean_w.flatten())

        # #correcting original incoming coordinates (list)
        # self.U = self.mean_u * (self.U - np.nanmin(self.U)) / np.nanmax(self.U)
        # self.V = self.mean_v * (self.V - np.nanmin(self.V)) / np.nanmax(self.V)
        # self.W = self.mean_w * (self.W - np.nanmin(self.W)) / np.nanmax(self.W)

        #make new arclength scales coordinates
        self.Ua_xyz_nii = self.U_xyz_nii.get_fdata() #copy from original
        self.Va_xyz_nii = self.V_xyz_nii.get_fdata()
        self.Wa_xyz_nii = self.W_xyz_nii.get_fdata()

        #rescaling
        self.Ua_xyz_nii = self.mean_u * (self.Ua_xyz_nii - np.nanmin(self.Ua_xyz_nii)) / \
                          np.nanmax(self.Ua_xyz_nii - 1*np.nanmin(self.Ua_xyz_nii))
        self.Va_xyz_nii = self.mean_v * (self.Va_xyz_nii - np.nanmin(self.Va_xyz_nii)) / \
                          np.nanmax(self.Va_xyz_nii - 1*np.nanmin(self.Va_xyz_nii))
        #self.Wa_xyz_nii = self.mean_w * (self.Wa_xyz_nii - np.nanmin(self.Wa_xyz_nii)) / \
        #                  np.nanmax(self.Wa_xyz_nii - 1*np.nanmin(self.Wa_xyz_nii))




        self.grads = []
        self.cumsum=[]
        self.X_uvw_low = []
        self.Y_uvw_low = []
        self.Z_uvw_low = []

        #extraction as lists
        self.Ua = self.Ua_xyz_nii[inds[:,0],inds[:,1],inds[:,2]]
        self.Va = self.Va_xyz_nii[inds[:,0],inds[:,1],inds[:,2]]
        self.Wa = self.Wa_xyz_nii[inds[:,0],inds[:,1],inds[:,2]]

        #making the interpolator
        #function='multiquadric' #this is for rbf
        function='linear' #this is for rbf
        print('Making uvwa in terms of xyz linear interpolator')
        points = np.asarray([self.X, self.Y, self.Z]).transpose()
        self.FUa_xyz = LinearNDInterpolator(points, self.Ua)
        self.FVa_xyz = LinearNDInterpolator(points, self.Va)
        self.FWa_xyz = LinearNDInterpolator(points, self.Wa)
        print('Making xyz in terms of uvw linear interpolator')
        points = np.asarray([self.Ua, self.Va, self.Wa]).transpose()
        self.FX_uvwa=  LinearNDInterpolator(points, self.X)
        self.FY_uvwa = LinearNDInterpolator(points, self.Y)
        self.FZ_uvwa = LinearNDInterpolator(points, self.Z)
        print('Making uvwa in terms of xyz Rbf interpolator')
        points = np.asarray([self.X, self.Y, self.Z]).transpose()
        self.rFUa_xyz = Rbf(self.X, self.Y, self.Z, self.Ua,function=function)
        self.rFVa_xyz = Rbf(self.X, self.Y, self.Z, self.Va,function=function)
        self.rFWa_xyz = Rbf(self.X, self.Y, self.Z, self.Wa,function=function)
        print('Making xyz in terms of uvw Rbf interpolator')
        points = np.asarray([self.Ua, self.Va, self.Wa]).transpose()
        self.rFX_uvwa=  Rbf(self.Ua, self.Va, self.Wa, self.X,function=function)
        self.rFY_uvwa = Rbf(self.Ua, self.Va, self.Wa, self.Y,function=function)
        self.rFZ_uvwa = Rbf(self.Ua, self.Va, self.Wa, self.Z,function=function)



        #converting to nifti
        self.Ua_xyz_nii = nib.Nifti1Image(self.Ua_xyz_nii, self.U_xyz_nii.affine)
        self.Va_xyz_nii = nib.Nifti1Image(self.Va_xyz_nii, self.V_xyz_nii.affine)
        self.Wa_xyz_nii = nib.Nifti1Image(self.Wa_xyz_nii, self.W_xyz_nii.affine)

    def nativeUnfold(self):
        """
        Native world coordinates in terms of unfold
        :return:
        """
        print("Creating cartesian coordinates in terms of mean arc length unfolded space...")
        res = self.U_xyz_nii.header['pixdim'][1]
        #
        #create the unfolded space (arclength corrected) domain parameter class instance
        self.Uparams = domainParams(np.nanmin(self.Ua), np.nanmax(self.Ua),  # these are arclength corrected
                               np.nanmin(self.Va), np.nanmax(self.Va),
                               np.nanmin(self.Wa), np.nanmax(self.Wa),
                               deltas=[res, res, res])

        # points = np.asarray([self.Ua, self.Va, self.Wa]).transpose()
        # self.FX_uvwa=  LinearNDInterpolator(points, self.X) #these can be made in meanArcLength() also
        # self.FY_uvwa = LinearNDInterpolator(points, self.Y)
        # self.FZ_uvwa = LinearNDInterpolator(points, self.Z)

        interps=[self.rFX_uvwa,self.rFY_uvwa,self.rFZ_uvwa] #putting interpolants in list to pass to interpolator3
        #interps = [self.FX_uvwa, self.FY_uvwa, self.FZ_uvwa]
        #computing xyz in terms of arclength corrected uvwa
        [self.X_uvwa_nii, self.Y_uvwa_nii, self.Z_uvwa_nii] = self.Uparams.interpolator3(interps)
        #self.X_uvwa_nii, self.Y_uvwa_nii, self.Z_uvwa_nii = self.Uparams.griddata3(points,[self.X,self.Y,self.Z])

        affine=self.Uparams.affine
        self.X_uvwa_nii = nib.Nifti1Image(self.X_uvwa_nii, affine)
        self.Y_uvwa_nii = nib.Nifti1Image(self.Y_uvwa_nii, affine)
        self.Z_uvwa_nii = nib.Nifti1Image(self.Z_uvwa_nii, affine)



    def computeGradDev(self):
        """
        Computes all the different graddevs
        :return: grad_dev_nii
        """
        C = [self.Ua_xyz_nii.get_data(),self.Va_xyz_nii.get_data(),self.Wa_xyz_nii.get_data()]

        grads = np.zeros((C[0].shape)+(3,3))

        for i in range(0,3):
            grads[:,:,:,i,0], grads[:,:,:,i,1],grads[:,:,:,i,2]=self.gradientNaN(C[i])/self.Ua_xyz_nii.affine[0][0]

        graddev=np.asarray(grads.reshape(-1,3,3),order='F')

        temp_graddev=copy.deepcopy(graddev)
        graddev[:]=np.NaN
        for g in range(0,graddev.shape[0]):
            m=temp_graddev[g,:,:]
            if(np.isnan( sum(sum(m)))==0): #this part controls whether you want rotation or deformation or both
                #print(sum(sum(m)))
                rot, deform=polar(m)
                graddev[g,:,:]=rot


        #grads = graddev - np.identity(3)


        grads=graddev
        grads=grads.reshape((C[0].shape)+(3,3))
        grads=grads-np.identity(3)

        self.gradDevXYZ_nii=grads.reshape((C[0].shape)+(9,),order='F') #not yet nifti
        self.gradDevXYZ_nii=nib.Nifti1Image(self.gradDevXYZ_nii,self.Ua_xyz_nii.affine)

        #move this data to unfolded space
        self.gradDevUVW_nii=np.zeros(self.Uparams.A.shape+(9,))
        self.gradDevUVW_nii[self.gradDevUVW_nii==0]=np.NaN

        interp = 'linear'
        Xuvw = self.X_uvwa_nii.get_data()
        Yuvw = self.Y_uvwa_nii.get_data()
        Zuvw = self.Z_uvwa_nii.get_data()

        condition = np.isnan(Xuvw) == 1

        Xuvw[condition] = 0
        Yuvw[condition] = 0
        Zuvw[condition] = 0

        function='multiquadric' #for rbf
        for i in range(0,9):
            print("vol: %d" % (i))
            points, S = getPointsData(self.gradDevXYZ_nii,i)
            #interpolator=LinearNDInterpolator(points,S)
            interpolator=Rbf(points[:,0],points[:,1],points[:,2],S,function=function)
            #temp=griddata(points, S, (Xuvw, Yuvw, Zuvw), method=interp)
            temp=interpolator(Xuvw, Yuvw, Zuvw)
            temp[condition]=np.NaN
            self.gradDevUVW_nii[:,:,:,i]=temp

        self.gradDevUVW_nii=nib.Nifti1Image(self.gradDevUVW_nii,self.X_uvwa_nii.affine)


    def gradientNaN(self,E):

        def nanChecker(A,B,E=None):
            if (np.isnan(A) == True and np.isnan(B) == True):
                C = np.NaN
            if(np.isnan(A) == True and np.isnan(B) == False):
                C = B
            if(np.isnan(A) == False and np.isnan(B) == True):
                C = A
            if(np.isnan(A) == False and np.isnan(B) == False):
                C = 0.5 * (A + B)
            return C

        dxEL=np.copy(E)
        dxEL[:]=np.NaN
        dxER = np.copy(dxEL)
        dxE = np.copy(dxEL)
        dyEL = np.copy(dxEL)
        dyER = np.copy(dxEL)
        dyE = np.copy(dxEL)
        dzEL = np.copy(dxEL)
        dzER = np.copy(dxEL)
        dzE = np.copy(dxEL)

        for i in range(0,E.shape[0]):
            for j in range(0,E.shape[1]):
                for k in range(0,E.shape[2]):

                    if i+1<E.shape[0]:
                        dxEL[i, j, k] = E[i + 1, j, k] - E[i, j, k]
                    if i>0:
                        dxER[i, j, k] = E[i, j, k] - E[i - 1, j, k]
                    dxE[i,j,k]=nanChecker(dxEL[i, j, k],dxER[i, j, k],E[i,j,k])

                    if j+1<E.shape[1]:
                        dyEL[i, j, k] = E[i , j + 1, k] - E[i, j, k]
                    if j>0:
                        dyER[i, j, k] = E[i, j, k] - E[i, j-1, k]
                    dyE[i, j, k] = nanChecker(dyEL[i, j, k], dyER[i, j, k],E[i,j,k])

                    if k+1< E.shape[2]:
                        dzEL[i, j, k] = E[i, j, k+1] - E[i, j, k]
                    if k> 0:
                        dzER[i, j, k] = E[i, j, k] - E[i, j, k-1]
                    dzE[i,j,k]=nanChecker(dzEL[i, j, k],dzER[i, j, k],E[i,j,k])

        return dxE,dyE,dzE






    def matrix2gradev(self):
        pass

    def graddev2matrix(self,graddev):
        """
        :param graddev: ...,3,3 matrix to be converted to [...,9]
        :return: graddev with size [...,9]
        """








