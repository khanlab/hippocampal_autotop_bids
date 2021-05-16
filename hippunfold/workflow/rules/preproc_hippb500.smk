#get _b500.nii.gz from the bids dataset - this is a preprocessed avg b500 image

rule resample_hippdwi_to_template:
    """ Hipp DWI is already corobl, but just needs to be cropped
        to get L and R subvolumes. We use predefined X and Y 
        bounding boxes, and keep all Z slices (since is Z 
        is smaller than in template). """
    input:
        b500 = config['input_path']['hippb500']
    params:
        resample_dim = config['hippdwi_opts']['resample_dim'],
        bbox_x = lambda wildcards: config['hippdwi_opts']['bbox_x'][wildcards.hemi],
        bbox_y = config['hippdwi_opts']['bbox_y']
    output:
        crop_b500 = bids(root='work',datatype='dwi',hemi='{hemi,L|R}',desc='cropped',space='corobl',suffix='b500.nii.gz',**config['subj_wildcards'] )
    group: 'subj'
    shell:
        'c3d {input} -resample {params.resample_dim} -as UPSAMPLED '
        ' -push UPSAMPLED -cmv -pop -popas COORDY -popas COORDX '
        ' -push COORDX -thresh {params.bbox_x} 1 0 -as MASKX '
        ' -push COORDY -thresh {params.bbox_y} 1 0 -as MASKY '
        ' -push MASKX -push MASKY -multiply '
        ' -push UPSAMPLED -multiply '
        ' -trim 0vox -o {output}'


rule lr_flip_b500:
    input:
        nii = bids(root='work',datatype='dwi',**config['subj_wildcards'],suffix='b500.nii.gz',desc='cropped',space='corobl',hemi='{hemi}'),
    output:
        nii = bids(root='work',datatype='dwi',**config['subj_wildcards'],suffix='b500.nii.gz',desc='cropped',space='corobl',hemi='{hemi,L}flip'),
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'c3d {input} -flip x -o  {output}'

rule cp_b500_to_seg_dir:
    input:
        nii = bids(root='work',datatype='dwi',**config['subj_wildcards'],suffix='b500.nii.gz',desc='cropped',space='corobl',hemi='{hemi}')
    output:
        nii = bids(root='work',datatype='seg_hippb500',desc='preproc',suffix='b500.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards'])
    group: 'subj'
    shell: 'cp {input} {output}'
