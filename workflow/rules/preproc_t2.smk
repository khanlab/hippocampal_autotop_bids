rule import_t2:
    input: config['input_path']['T2w']
    output: bids(root='work',datatype='anat',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz')
    group: 'preproc'
    shell: 'cp {input} {output}'

rule n4_t2:
    input:  bids(root='work',datatype='anat',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz')
    output:  bids(root='work',datatype='anat',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='n4')
    threads: 8
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'N4BiasFieldCorrection -d 3 -i {input} -o {output}'


def get_ref_n4_t2 (wildcards):
    #get the first image
    t2_imgs =  expand(bids(root='work',datatype='anat',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='n4'),
            zip,**snakebids.filter_list(config['input_zip_lists']['T2w'],wildcards))
    return t2_imgs[0]

def get_floating_n4_t2 (wildcards):
    t2_imgs =  expand(bids(root='work',datatype='anat',**config['input_wildcards']['T2w'],suffix='T2w.nii.gz',desc='n4'),
            zip,**snakebids.filter_list(config['input_zip_lists']['T2w'],wildcards))
    return t2_imgs[int(wildcards.idx)]


#register scan to the ref t2
rule reg_t2_to_ref:
    input:
        ref = get_ref_n4_t2,
        flo = get_floating_n4_t2
    output:
        xfm_ras = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T2w{idx}',to='T2w0',desc='rigid',type_='ras'),
        xfm_itk = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T2w{idx}',to='T2w0',desc='rigid',type_='itk'),
        warped = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='aligned',floating='{idx}')
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'reg_aladin -flo {input.flo} -ref {input.ref} -res {output.warped} -aff {output.xfm_ras} -rigOnly -nac && '
        'c3d_affine_tool  {output.xfm_ras} -oitk {output.xfm_itk}'



def get_aligned_n4_t2 (wildcards):

    #first get the number of floating t2s
    filtered = snakebids.filter_list(config['input_zip_lists']['T2w'],wildcards)
    num_scans = len(filtered['subject'])

    #then, return the path, expanding over range(1,num_scans) -i.e excludes 0 (ref image)
    t2_imgs =  expand(bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='aligned',floating='{idx}'),
                        **wildcards, idx=range(1,num_scans))
    return t2_imgs



#average aligned n4 images to get preproc T2w (or if single scan, just copy it)
rule avg_aligned_or_cp_t2:
    input:
        ref = get_ref_n4_t2,
        flo = get_aligned_n4_t2,
    params:
        cmd = get_avg_or_cp_scans_cmd
    output:
        bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='preproc')
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell: '{params.cmd}'
        


#register to t1 
rule reg_t2_to_t1:
    input: 
        flo = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='preproc'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],desc='n4',suffix='T1w.nii.gz')
    output: 
        warped = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='n4',space='T1w'),
        xfm_ras = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T2w',to='T1w',desc='rigid',type_='ras'),
        xfm_itk = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T2w',to='T1w',desc='rigid',type_='itk')
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'reg_aladin -flo {input.flo} -ref {input.ref} -res {output.warped} -aff {output.xfm_ras} -rigOnly -nac && '
        'c3d_affine_tool  {output.xfm_ras} -oitk {output.xfm_itk}'

#now have t2 to t1 xfm, compose this with t1 to corobl xfm
rule compose_t2_xfm_corobl:
    input:
        t2_to_t1 = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T2w',to='T1w',desc='rigid',type_='itk'),
        t1_to_cor = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='{template}corobl',desc='affine',type_='itk'),
    output:
        t2_to_cor = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T2w',to='{template}corobl',desc='affine',type_='itk')
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'c3d_affine_tool -itk {input[0]} -itk {input[1]} -mult -oitk {output}'

#apply transform to get subject in corobl cropped space -- note that this could be marginally improved if we xfm each T2 to the cropped space in single resample (instead of avgT2w first)
rule warp_t2_to_corobl_crop:
    input:
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='preproc'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T2w',to='{template}corobl',desc='affine',type_='itk'),
        ref = lambda wildcards: os.path.join(config['snakemake_dir'],config['template_files'][wildcards.template]['crop_ref'])
    output: 
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation Linear -i {input.nii} -o {output.nii} -r {input.ref}  -t {input.xfm}' 



rule lr_flip_t2:
    input:
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}'),
    output:
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi,L}flip'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell:
        'c3d {input} -flip x -o  {output}'

