ruleorder:  compose_template_xfm_corobl > convert_template_xfm_ras2itk


#just grab the first T1w for now:
rule import_t1:
    input: lambda wildcards: expand(config['input_path']['T1w'],zip,**snakebids.filter_list(config['input_zip_lists']['T1w'],wildcards))[0]
    output: bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='T1w.nii.gz')
    group: 'preproc'
    shell: 'cp {input} {output}'

rule n4_t1:
    input: 
        t1 = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='T1w.nii.gz'),
    output:
        t1 = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='n4', suffix='T1w.nii.gz'),
    threads: 8
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'N4BiasFieldCorrection -d 3 -i {input.t1} -o {output}'



rule affine_aladin:
    input: 
        flo = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='n4',suffix='T1w.nii.gz'),
        ref = lambda wildcards: os.path.join(config['snakemake_dir'],config['template_files'][wildcards.template]['T1w']),
    output: 
        warped_subj = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='T1w.nii.gz',space='{template}',desc='affine'),
        xfm_ras = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='ras'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'reg_aladin -flo {input.flo} -ref {input.ref} -res {output.warped_subj} -aff {output.xfm_ras}'

rule convert_template_xfm_ras2itk:
    input:
        bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='ras'),
    output:
        bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='itk'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'c3d_affine_tool {input}  -oitk {output}'


#now have subject -> template transform, can compose that with template -> corobl to get subject -> corobl
rule compose_template_xfm_corobl:
    input:
        sub_to_std = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='itk'),
        std_to_cor = lambda wildcards: os.path.join(config['snakemake_dir'],config['template_files'][wildcards.template]['xfm_corobl'])
    output:
        sub_to_cor = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}corobl',desc='affine',type_='itk'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'c3d_affine_tool -itk {input.sub_to_std} -itk {input.std_to_cor} -mult -oitk {output}'


#create inverted T1w image (to fool autotop trained on T2w):
rule invert_t1w_intensity:
    input:
        t1 = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='n4', suffix='T1w.nii.gz'),
    output:
        t1 = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='n4', suffix='InvT1w.nii.gz'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell: 'c3d {input}  -scale -1 -stretch 0% 100% 0 1000 -o {output}'

#apply transform to get subject in corobl cropped space
rule warp_t1_to_corobl_crop:
    input:
        t1 = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='n4', suffix='InvT1w.nii.gz'),
        xfm = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}corobl',desc='affine',type_='itk'),
        ref = lambda wildcards: os.path.join(config['snakemake_dir'],config['template_files'][wildcards.template]['crop_ref']),
        std_to_cor = lambda wildcards: os.path.join(config['snakemake_dir'],config['template_files'][wildcards.template]['xfm_corobl'])
    output: 
        t1 = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='cropped', suffix='InvT1w.nii.gz',space='{template}corobl',hemi='{hemi,L|R}'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation Linear -i {input.t1} -o {output.t1} -r {input.ref}  -t {input.xfm}' 


rule lr_flip_t1:
    input:
        nii = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='InvT1w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}'),
    output:
        nii = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='InvT1w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi,L}flip'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'c3d {input} -flip x -o  {output}'



