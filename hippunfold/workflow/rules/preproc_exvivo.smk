#---- snakebids boilerplate

import snakebids
from snakebids import bids

configfile: 'config/snakebids.yml'

rule import_seg:
    input: lambda wildcards: expand(config['input_path']['seg'],zip,**snakebids.filter_list(config['input_zip_lists']['seg'],wildcards))[0]
    output: bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='cropped',space='corobl',hemi='{hemi,R}',from_='{space}')
    group: 'subj'
    shell: 'cp {input} {output}'

rule import_exvivo:
    input: lambda wildcards: expand(config['input_path']['ExVivo'],zip,**snakebids.filter_list(config['input_zip_lists']['ExVivo'],wildcards))[0]
    output: bids(root='work',datatype='anat',**config['subj_wildcards'],desc='cropped', suffix='T1w.nii.gz',space='corobl',hemi='{hemi,R}')
    group: 'subj'
    shell: 'cp {input} {output}'


