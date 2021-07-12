import unfoldSubject
import nibabel as nib

#intilize subject
sub=unfoldSubject.unfoldSubject()

#load coordinates
sub.loadCoordinates(path='/home/uzair/PycharmProjects/Unfolding/data/oldUnfold/',prefix='')

#load native diffusion vol
sub.loadDiffusion(path='/home/uzair/PycharmProjects/Unfolding/data/oldUnfold/')
sub.pushToUnfold(type='diffusion')

#save unfolded volumes
nib.save(sub.diffUnfold.vol, "path/goes/here/data.nii.gz")
nib.save(sub.coords.gradDevUVW_nii, "path/goes/here/grad_dev.nii.gz")
nib.save(sub.coords.gradDevXYZ_nii, "path/goes/here/grad_devXYZ.nii.gz") #this is native space grad dev (optional)

#some steps to create a mask
temp_mask = sub.diffUnfold.mask.get_fdata()
temp_mask = nib.Nifti1Image(temp_mask, sub.diffUnfold.mask.affine)
nib.save(sub.diffUnfold.mask, 'path/goes/here/nodif_brain_mask.nii.gz')