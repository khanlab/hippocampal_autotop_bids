rule import_t2:
    input: config['input_path']['T2w']
    output: bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz')
    shell: 'cp {input} {output}'

rule n4_t2:
    input:  bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz')
    output:  bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='n4')
    threads: 8
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'N4BiasFieldCorrection -d 3 -i {input} -o {output}'

#register to t1 
rule reg_t2_to_t1:
    input: 
        flo = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='n4'),
        ref = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='n4',suffix='T1w.nii.gz')
    output: 
        warped = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='n4',space='T1w'),
        xfm_ras = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='xfm.txt',from_='T2w',to='T1w',desc='rigid',type_='ras'),
        xfm_itk = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='xfm.txt',from_='T2w',to='T1w',desc='rigid',type_='itk')
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'reg_aladin -flo {input.flo} -ref {input.ref} -res {output.warped} -aff {output.xfm_ras} && '
        'c3d_affine_tool  {output.xfm_ras} -oitk {output.xfm_itk}'

#now have t2 to t1 xfm, compose this with t1 to corobl xfm
rule compose_t2_xfm_corobl:
    input:
        t2_to_t1 = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='xfm.txt',from_='T2w',to='T1w',desc='rigid',type_='itk'),
        t1_to_cor = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}corobl',desc='affine',type_='itk'),
    output:
        t2_to_cor = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='xfm.txt',from_='T2w',to='{template}corobl',desc='affine',type_='itk')
    container: config['singularity']['prepdwi']
    shell:
        'c3d_affine_tool -itk {input[0]} -itk {input[1]} -mult -oitk {output}'

#apply transform to get subject in corobl cropped space
rule warp_t2_to_corobl_crop:
    input:
        nii = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='n4'),
        xfm = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='xfm.txt',from_='T2w',to='{template}corobl',desc='affine',type_='itk'),
        ref = lambda wildcards: config['template_files'][wildcards.template]['crop_ref']
    output: 
        nii = bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}'),
    container: config['singularity']['prepdwi']
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation Linear -i {input.nii} -o {output.nii} -r {input.ref}  -t {input.xfm}' 


#take mean of all scans if >1, otherwise just copy the one scan
def get_avg_t2_scans_cmd (wildcards, input, output):
    if len(input) > 1:
        cmd = f'c3d {input} -mean -o {output}'
    else:
        cmd = f'cp {input} {output}'
    return cmd

# this also allows us to change from input_wildcards to subj_wildcards (e.g. removes any wildcards except subj/session)
rule avg_t2_scans:
    input: lambda wildcards: expand( bids(root='work/preproc_t2',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='cropped',space='{{template}}corobl',hemi='{{hemi}}'),\
                        zip, **snakebids.filter_list(config['input_zip_lists']['T2w'], wildcards))
    params: 
        cmd = get_avg_t2_scans_cmd
    output: bids(root='work/preproc_t2',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi,L|R}')
    container: config['singularity']['prepdwi']
    shell: '{params.cmd}'
    

rule lr_flip_t2:
    input:
        nii = bids(root='work/preproc_t2',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}'),
    output:
        nii = bids(root='work/preproc_t2',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi,L}flip'),
    container: config['singularity']['prepdwi']
    shell:
        'c3d {input} -flip x -o  {output}'

