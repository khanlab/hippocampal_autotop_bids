
rule import_seg:
    input: lambda wildcards: expand(config['input_path']['seg'],zip,**snakebids.filter_list(config['input_zip_lists']['seg'],wildcards))[0]
    output: bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='postproc',space='corobl',hemi='R').format(**wildcards) # always import as hemi-R
    group: 'subj'
    shell: 'cp {input} {output}'

