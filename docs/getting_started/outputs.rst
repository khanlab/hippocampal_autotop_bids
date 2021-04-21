Outputs of hippunfold
=====================


The ``results`` folder is a BIDS-derivatives dataset that contains the pre-processed anatomicals used for the segmentation, segmentatioons and hippocampal coordinate images, and HCP-style surfaces of the hippocampus in native and unfolded configurations::

    results/
    ├── dataset_description.json
    └── sub-{subject}
        ├── anat
        ├── seg_T2w
        └── surf_T2w 

        
Volumetric outputs
------------------


Anatomical images that have been non-uniformity corrected, motion-corrected, averaged and registered to the ``T1w`` space are placed in each subject's ``anat`` subfolder::

    sub-{subject}
     └── anat
         ├── sub-{subject}_desc-preproc_T1w.nii.gz
         └── sub-{subject}_space-T1w_desc-preproc_T2w.nii.gz


Segmentations are derived from the U-net segmentation, which is by default performed on the ``T2w`` image, but can also be performed on the ``T1w`` image (or other modalities) using the ``--modality`` parameter. To distinguish between these outputs, segmentations are placed in each subject's ``seg_{modality}`` subfolder::

    sub-{subject}
     └── seg_T2w
         ├── sub-{subject}_dir-{AP,PD,IO}_hemi-{L,R}_space-cropT1w_coords.nii.gz
         ├── sub-{subject}_hemi-{L,R}_space-cropT1w_desc-preproc_T2w.nii.gz
         └── sub-{subject}_hemi-{L,R}_space-{T1w,cropT1w,unfold}_desc-subfields_dseg.nii.gz

Images in this folder are provided in the ``T1w`` space (same resolution and FOV as the ``T1w`` image, as well as in a 0.3mm upsampled FOV cropped around each hippocampus, but still aligned to the ``T1w`` image, which is denoted as the ``cropT1w`` space. 

Image Transforms
^^^^^^^^^^^^^^^^

ITK transforms to warp images from the ``T1w`` space to the ``unfold`` space are provided for each hippocampus::

    sub-{subject}
     └── seg_T2w
         └── sub-{subject}_hemi-{L,R}_from-T1w_to-unfold_mode-image_xfm.nii.gz

This is an ITK transform that can transform any image that is in ``T1w`` space (can be any resolution and FOV, as long as aligned to ``T1w``), to the ``unfold`` hippocampal volume space. You can use the warp itself as a reference image, e.g.::

    antsApplyTransforms -i sub-001_space-T1w_FA.nii.gz -o sub-001_hemi-L_space-unfold_FA.nii.gz -t sub-001_hemi-L_from-T1w_to-unfold_mode-image_xfm.nii.gz -r sub-001_hemi-L_from-T1w_to-unfold_mode-image_xfm.nii.gz -v


Subfield segmentations
^^^^^^^^^^^^^^^^^^^^^^

Hippocampal subfield segmentations are suffixed with ``desc-subfields_dseg.nii.gz``, and have the following look-up table:

=====   =================== ============
index   name                abbreviation
=====   =================== ============
1       subiculum           Sub
2       CA1                 CA1
3       CA2                 CA2
4       CA3                 CA3
5       CA4                 CA4
6       dentate gyrus       DG
7       SRLM or 'dark band' SRLM
8       cysts               Cyst
=====   =================== ============

Coordinate images
^^^^^^^^^^^^^^^^^

Hippunfold also provides images that represent anatomical gradients along the 3 principal axes of the hippocampus, longitudinal from anterior to posterior, lamellar from proximal (dentate gyrus) to distal (subiculum), and laminar from inner (SRLM) to outer. These are provided in the images suffixed with ``coords.nii.gz`` with the direction indicated by ``dir-{direction}`` as ``AP``, ``PD`` or ``IO``, and intensities from 0 to 100, e.g. 0 representing the Anterior end and 100 the Posterior end.



Surface-based GIFTI outputs
---------------------------

Hippunfold produces HCP-style surface-based data in GIFTI format. Similar to the volumetric segmentation data, these files are found in a subfolder named according to the modality used to perform the segmentation, ``surf_{modality}``, which is ``surf_T2w`` by default.



Surface meshes (geometry files) are in ``.surf.gii`` format, and are provided in both the native space (``space-T1w``) and the unfolded space (``space-unfolded``). In each space, there are ``inner``, ``midthickness``, and ``outer`` surfaces, which correspond to ``white``, ``midthickness``, and ``pial`` for cortical surfaces::

    sub-{subject}
     └── surf_T2w
         └── sub-{subject}_hemi-{L,R}_space-{T1w,unfolded}_{inner,midthickness,outer}.surf.gii
 
All surfaces, both ``space-T1w`` and ``space-unfolded``, share the same mesh topology and have corresponding vertices with each other. The vertex locations for unfolded surfaces are identical for all subjects as well (note that this of course is not the case for the ``space-T1w`` surfaces). 

In addition to the geometry files, surface-based shape metrics are provided in ``.shape.gii`` format. The thickness, curvature and gyrification are computed using the same methods as cortical surfaces, based on the surface geometry files, and are provided in the ``T1w`` space::

    sub-{subject}
     └── surf_T2w
         └── sub-{subject}_hemi-{L,R}_space-T1w_{thickness,curvature,gyrification}.shape.gii

Finally, these files are packaged together for easy viewing in Connectome Workbench, ``wb_view``, in the following ``.spec`` files, for each hemisphere separately, and combined::

    sub-{subject}
     └── surf_T2w
         ├── sub-{subject}_hemi-{L,R}_hippunfold.spec
         └── sub-{subject}_hippunfold.spec


CIFTI outputs
-------------

**Coming soon:** functionality to create CIFTI data based on functional imaging data
        


Additional Files
----------------

The top-level folder structure of hippunfold is::

    ├── config
    ├── logs
    ├── results
    └── work

The ``config`` folder contains the hippunfold ``snakebids.yml`` config file, and ``inputs_config.yml`` that contain a record of the parameters used, and paths to the inputs.

Workflow steps that write logs to file are stored in the ``logs`` subfolder, with file names based on the rule wildcards (e.g. subject, hemi, etc..).

Intermediate files are stored in the ``work`` folder. These files and folders, similar to results, are generally  named according to BIDS.


