#---- snakebids boilerplate

import snakebids
from snakebids import bids

configfile: 'config/snakebids.yml'

rule import_seg:
    input: lambda wildcards: expand(config['input_path']['seg'],zip,**snakebids.filter_list(config['input_zip_lists']['seg'],wildcards))[0]
    output: 
        crop = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',from_='ExVivo'),
        nocrop = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='dseg.nii.gz',space='corobl',hemi='{hemi}',from_='ExVivo'),
    group: 'subj'
    shell: 
        'cp {input} {output.crop} &'
        'cp {input} {output.nocrop}'


