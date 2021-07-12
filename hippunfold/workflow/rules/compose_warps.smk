
rule compose_warps_corobl2unfold_rhemi:
    """ Compose corobl to unfold (unfold-template), for right hemi (ie no flip)"""
    input:
        native2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_native2unfold.nii',desc='cropped',space='corobl',hemi='R',modality='{modality}'),
        unfold2unfoldtemplate = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0Warp.nii.gz',desc='cropped',space='corobl',hemi='R',modality='{modality}'),
        ref = bids(root='work',space='unfold',suffix='refvol.nii.gz',**config['subj_wildcards']),
    output:
        corobl2unfold = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='R',from_='corobl',to='unfold',mode='image')
    container: config['singularity']['autotop'] 
    group: 'subj'
    shell: 'ComposeMultiTransform 3 {output.corobl2unfold} -R {input.ref} {input.unfold2unfoldtemplate} {input.native2unfold}'


rule compose_warps_corobl2unfold_lhemi:
    """ Compose corobl to unfold (unfold-template), for left hemi (ie with flip)"""
    input:
        native2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_native2unfold.nii',desc='cropped',space='corobl',hemi='Lflip',modality='{modality}'),
        unfold2unfoldtemplate = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0Warp.nii.gz',desc='cropped',space='corobl',hemi='Lflip',modality='{modality}'),
        ref = bids(root='work',space='unfold',suffix='refvol.nii.gz',**config['subj_wildcards']),
        flipLR_xfm = os.path.join(config['snakemake_dir'],'resources','desc-flipLR_type-itk_xfm.txt')
    output:
        corobl2unfold = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='L',from_='corobl',to='unfold',mode='image')
    container: config['singularity']['autotop'] 
    group: 'subj'
    shell: 'ComposeMultiTransform 3 {output.corobl2unfold} -R {input.ref} {input.unfold2unfoldtemplate} {input.native2unfold} {input.flipLR_xfm}'




rule compose_warps_unfold2corobl_rhemi:
    """ Compose unfold (unfold-template) to corobl, for right hemi (ie no flip)"""
    input:
        unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2native_RPI.nii',desc='cropped',space='corobl',hemi='R',modality='{modality}'),
        unfoldtemplate2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0InverseWarp.nii.gz',desc='cropped',space='corobl',hemi='R',modality='{modality}'),
        unfold_ref = bids(root='work',space='unfold',suffix='refvol.nii.gz',**config['subj_wildcards']),
        ref = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-AP.nii.gz',desc='cropped',space='corobl',hemi='R',modality='{modality}')
    output:
        unfold2corobl = bids(root='results',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='R',from_='unfold',to='corobl',mode='image')
    container: config['singularity']['ants']
    group: 'subj'
    shell: 'antsApplyTransforms -o [{output.unfold2corobl},1] -r {input.unfold2native} -t {input.unfold2native} -t {input.unfoldtemplate2unfold} -i {input.unfold_ref} -v'


rule compose_warps_unfold2corobl_lhemi:
    """ Compose unfold (unfold-template) to corobl, for left hemi (ie with flip)"""
    input:
        unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2native_RPI.nii',desc='cropped',space='corobl',hemi='Lflip',modality='{modality}'),
        unfoldtemplate2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0InverseWarp.nii.gz',desc='cropped',space='corobl',hemi='Lflip',modality='{modality}'),
        flipLR_xfm = os.path.join(config['snakemake_dir'],'resources','desc-flipLR_type-itk_xfm.txt'),
        unfold_ref = bids(root='work',space='unfold',suffix='refvol.nii.gz',**config['subj_wildcards']),
        ref = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-AP.nii.gz',desc='cropped',space='corobl',hemi='L',modality='{modality}') #use unflipped ref here
    output:
        unfold2corobl = bids(root='results',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='L',from_='unfold',to='corobl',mode='image')
    container: config['singularity']['ants']
    group: 'subj'
    shell: 'antsApplyTransforms -o [{output.unfold2corobl},1] -r {input.ref} -t {input.flipLR_xfm} -t {input.unfold2native} -t {input.unfoldtemplate2unfold} -i {input.unfold_ref} -v'


 
rule compose_warps_t1_to_unfold:
    """ Compose warps from T1w to unfold """
    input:
        corobl2unfold = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='{hemi}',from_='corobl',to='unfold',mode='image'),
        ref = bids(root='work',space='unfold',suffix='refvol.nii.gz',**config['subj_wildcards']),
        t1w2corobl = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
    output: 
        bids(root='results',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='{hemi}',from_='T1w',to='unfold',mode='image')
    container: config['singularity']['ants']
    group: 'subj'
    shell: 'ComposeMultiTransform 3 {output} -R {input.ref} {input.corobl2unfold} {input.t1w2corobl}'


rule compose_warps_unfold_to_cropt1:
    """ Compose warps from unfold to cropT1w """
    input:
        unfold2corobl = bids(root='results',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='{hemi}',from_='unfold',to='corobl',mode='image'),
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards']),
        t1w2corobl = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        unfold_ref = bids(root='work',space='unfold',suffix='refvol.nii.gz',**config['subj_wildcards']),
    output: 
        unfold2cropt1 = bids(root='results',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='{hemi}',from_='unfold',to='cropT1w',mode='image')
    container: config['singularity']['ants']
    group: 'subj'
    shell: 'antsApplyTransforms -o [{output.unfold2cropt1},1] -r {input.ref} -t [{input.t1w2corobl},1] -t {input.unfold2corobl} -i {input.unfold_ref} -v'


rule compute_warp_jacobian:
    """ Generic rule for computing warp jacobian 
        
        Note: can be made generic since the input is just the output filename with different xfm as suffix"""
    input: '{prefix}_xfm.nii.gz'
    output: '{prefix}_jacobian.nii.gz'
    group: 'subj'
    script: '../scripts/compute_jacobian.py'

rule compute_graddev:
    """ Generic rule for computing graddev from jacobian"""

    input: '{prefix}_jacobian.nii.gz'
    output: '{prefix}_graddev.nii.gz'
    group: 'subj'
    script: '../scripts/compute_graddev.py'

