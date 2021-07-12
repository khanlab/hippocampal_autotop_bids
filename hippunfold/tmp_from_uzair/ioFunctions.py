import nibabel
from pathlib import Path
from dipy.io import read_bvals_bvecs
from dipy.core.gradients import gradient_table


def loadVol(filename=None, **kwargs):
    if filename is None:
        raise ValueError("Please provide filename, filename=...")
    print("loading: " + filename)
    return nibabel.load(filename)

def loadgetVol(filename=None, **kwargs):
    if filename is None:
        raise ValueError("Please provide filename, filename=...")
    print("loading: " + filename)
    temp=nibabel.load(filename)
    return temp.get_data()

def loadDiffVol(folder=None, **kwargs):
    if folder is None:
        raise ValueError("Please provide diffusion folder path, folder=...")

    folder=Path(folder)
    diffile =folder / "data.nii.gz"
    bvecsf = folder / "bvecs"
    bvalsf = folder / "bvals"
    print("loading " + str(diffile.resolve()))
    diff=nibabel.load(str(diffile.resolve()))
    print("loading " + str(bvecsf.resolve()))
    print("loading " + str(bvalsf.resolve()))
    bvals, bvecs = read_bvals_bvecs(str(bvalsf.resolve() ),str(bvecsf.resolve() ))
    gtab=gradient_table(bvals,bvecs)
    return (diff, gtab)

