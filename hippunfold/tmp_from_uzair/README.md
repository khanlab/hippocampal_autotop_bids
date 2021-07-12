# unfoldingForDiffusion

In example.py is a typical way you would use the unfolding class.

You can use loadCoordinates to load the coordinates (here you will likely need to go in and modify what you want your trailing suffix to be for each coordinate file, right now it is set to U.nii.gz, V.nii.gz and W.nii.gz). This is in the coordinates.py file under the function loadCoordinates, you can also supply a prefix here. It is designed to concatenate and load. When coordinates are loaded it will do all neccessary computations including grad_dev which DOES NOT use acquisition graddev at the moment and is set to rotation only.

Then you may load diffustion and then unfold it. This will populate various unfolding volume related attributes in the unfolding class which you can then save in the folder of your choice. From here on you can fit which ever model you want. Make sure that where ever you save your unfolding volumes you also copy over the bvecs and bvals.

