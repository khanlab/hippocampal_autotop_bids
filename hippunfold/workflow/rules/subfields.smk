
rule label_subfields_from_vol_coords_corobl:
    """ Label subfields using the volumetric coords and bigbrain labels"""
    input:  
        subfields_mat = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','BigBrain_ManualSubfieldsUnfolded.mat'),
        nii_ap = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-AP.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        nii_pd = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-PD.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
    params:
        mat_name = 'subfields_avg' #avg bigbrain over L/R hemis
    output:
        nii_label = bids(root='work',datatype='seg_{modality}',desc='subfieldsnotissue',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards'])
    group: 'subj'
    script: '../scripts/label_subfields_from_vol_coords.py'



rule combine_tissue_subfield_labels_corobl:
    """Combine subfield labels with the DG, SRLM and Cyst tissue labels
    
        add srlm, cyst, dg from postproc labels to subfields
        input dg label 8, output 6
        input srlm label 2, output 7
        input cyst label 7, output 8

        first remap tissue labels to get three sep labels
        then, we just need to add those in, using max(old,new) to override old with new in case of conflict
    """
    input:
        tissue = bids(root='work',**config['subj_wildcards'],suffix='autotop/labelmap-postProcess.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        subfields = bids(root='work',datatype='seg_{modality}',desc='subfieldsnotissue',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards'])
    params:
        remap_dg = '-threshold 8 8 6 0 -popas dg',
        remap_srlm = '-threshold 2 2 7 0 -popas srlm',
        remap_cyst = '-threshold 7 7 8 0 -popas cyst',
    output:
        combined = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell: 
        'c3d {input.tissue} -dup {params.remap_dg} -dup {params.remap_srlm} {params.remap_cyst} {input.subfields} -push dg -max -push srlm -max -push cyst -max -o {output}'




rule resample_subfields_to_T1w:
    """Resampling to T1w native space"""
    input:
        nii = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards']),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='results',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 


rule resample_postproc_to_T1w:
    """Resample post-processed tissue seg to T1w"""
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/labelmap-postProcess.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='postproc',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 
  
rule resample_unet_to_T1w:
    """Resample unet tissue seg to T1w"""
    input:
        nii = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='nnunet',space='corobl',hemi='{hemi}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='unet',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 



