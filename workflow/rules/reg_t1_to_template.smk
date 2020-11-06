wildcard_constraints:
    desc='[a-zA-Z0-9]+',
    template='[a-zA-Z0-9]+',

#just grab the first T1w for now:
rule import_subj_t1:
    input: lambda wildcards: expand(config['input_path']['T1w'],zip,**snakebids.filter_list(config['input_zip_lists']['T1w'],wildcards))[0]
    output: bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='T1w.nii.gz')
    group: 'preproc'
    shell: 'cp {input} {output}'

rule n4biasfield:
    input: 
        t1 = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='T1w.nii.gz'),
    output:
        t1 = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],desc='n4', suffix='T1w.nii.gz'),
    threads: 8
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'N4BiasFieldCorrection -d 3 -i {input.t1} -o {output}'



rule affine_aladin:
    input: 
        flo = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],desc='n4',suffix='T1w.nii.gz'),
        ref = config['template_T1w'],
    output: 
        warped_subj = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='T1w.nii.gz',space='{template}',desc='affine'),
        xfm_ras = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='ras'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'reg_aladin -flo {input.flo} -ref {input.ref} -res {output.warped_subj} -aff {output.xfm_ras}'

rule convert_template_xfm_ras2itk:
    input:
        bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='ras'),
    output:
        bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='itk'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'c3d_affine_tool {input}  -oitk {output}'


#now have subject -> template transform, can compose that with template -> corobl to get subject -> corobl
rule compose_template_xfm_corobl:
    input:
        sub_to_std = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='itk'),
        std_to_cor = config['template_xfm_corobl']
    output:
        sub_to_cor = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}corobl',desc='affine',type_='itk'),
    shell:
        'c3d_affine_tool -itk {input.sub_to_std} -itk {input.std_to_cor} -mult -oitk {output}'


#apply transform to get subject in corobl cropped space
rule warp_t1_to_corobl_crop:
    input:
        t1 = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],desc='n4', suffix='T1w.nii.gz'),
        xfm = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}corobl',desc='affine',type_='itk'),
        ref = config['template_crop_ref']
    output: 
        t1 = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],desc='cropped', suffix='T1w.nii.gz',space='{template}corobl',hemi='{hemi}'),
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation Linear -i {input.t1} -o {output.t1} -r {input.ref}  -t {input.xfm}' 


"""
#--- unused:
rule warp_dseg_from_template:
    input: 
        dseg = config['template_atlas_dseg_nii'],
        ref = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='T1w.nii.gz'),
        inv_composite = bids(root='work/reg_t1_to_template',suffix='InverseComposite.h5',from_='subject',to='{template}',**config['subj_wildcards']),
    output:
        dseg = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='dseg.nii.gz',atlas='{atlas}',from_='{template}',reg='SyN'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    threads: 1
    resources:
        mem_mb = 16000
    shell: 
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation NearestNeighbor -i {input.dseg} -o {output.dseg} -r {input.ref} '
            ' -t {input.inv_composite} ' #use inverse xfm (going from template to subject)


rule warp_tissue_probseg_from_template:
    input: 
        probseg = config['template_tissue_probseg'],
        ref = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='T1w.nii.gz'),
        inv_composite = bids(root='work/reg_t1_to_template',suffix='InverseComposite.h5',from_='subject',to='{template}',**config['subj_wildcards']),
    output:
        probseg = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='probseg.nii.gz',label='{tissue}',from_='{template}',reg='SyN'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    threads: 1
    resources:
        mem_mb = 16000
    shell: 
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation Linear -i {input.probseg} -o {output.probseg} -r {input.ref} '
            ' -t {input.inv_composite} ' #use inverse xfm (going from template to subject)

rule warp_brainmask_from_template:
    input: 
        mask = config['template_mask'],
        ref = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='T1w.nii.gz'),
        inv_composite = bids(root='work/reg_t1_to_template',suffix='InverseComposite.h5',from_='subject',to='{template}',**config['subj_wildcards']),
    output:
        mask = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='mask.nii.gz',from_='{template}',reg='SyN',desc='brain'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    threads: 1
    resources:
        mem_mb = 16000
    shell: 
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation NearestNeighbor -i {input.mask} -o {output.mask} -r {input.ref} '
            ' -t {input.inv_composite} ' #use inverse xfm (going from template to subject)

rule warp_brainmask_from_template_affine:
    input: 
        mask = config['template_mask'],
        ref = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='T1w.nii.gz'),
        xfm = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='itk'),
    output:
        mask = bids(root='work/reg_t1_to_template',**config['subj_wildcards'],suffix='mask.nii.gz',from_='{template}',reg='affine',desc='brain'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell: 'antsApplyTransforms -d 3 --interpolation NearestNeighbor -i {input.mask} -o {output.mask} -r {input.ref} '
            ' -t [{input.xfm},1] ' #use inverse xfm (going from template to subject)

"""
