import os
    

#creates command based on mcr or matlab
def get_autotop_cmd (wildcards, input, output):
    autotop_dir = os.path.join(config['snakemake_dir'],'hippocampal_autotop')
    singularity_cmd = f"singularity exec -B {autotop_dir}:/src -e {config['singularity']['autotop']}" 

    if config['use_mcr'] == True:
        cmd = f"{singularity_cmd} /src/mcr_v97/run_AutoTops_TransformAndRollOut.sh /opt/mcr/v97 "\
                f"{input.nii} {output.out_dir} '' {config['cnn_model'][wildcards.modality]}"
    else:
        set_matlab_lic = f"SINGULARITYENV_MLM_LICENSE_FILE={config['mlm_license_file']}"
        set_java_home = f"SINGULARITYENV_JAVA_HOME={config['java_home']}"

        cmd = f"{set_matlab_lic} {set_java_home} {singularity_cmd} "\
                f"{config['matlab_bin']} -batch \"addpath(genpath('{autotop_dir}')); "\
                f"AutoTops_TransformAndRollOut('{input.nii}','{output.out_dir}',[],'{config['cnn_model'][wildcards.modality]}')\""
    return cmd   



def get_autotop_input (wildcards):
    if wildcards.modality == 'T2w':
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}'),
    elif wildcards.modality == 'T1w':
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='InvT1w.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}'),
    elif wildcards.modality == 'b500':
        nii = bids(root='work/preproc_dwi',suffix='b500.nii.gz',desc='cropped',datatype='dwi',**config['subj_wildcards'],space='{template}corobl',hemi='{hemi}'),
    elif wildcards.modality == 'b1000':
        nii = bids(root='work/preproc_dwi',suffix='b1000.nii.gz',desc='cropped',datatype='dwi',**config['subj_wildcards'],space='{template}corobl',hemi='{hemi}'),
    else:
        nii = ''

    return nii



rule run_autotop:
    input:
        nii = get_autotop_input
    params:
        autotop_cmd = get_autotop_cmd
    output:
        out_dir = directory(bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='{template}corobl',hemi='{hemi,Lflip|R}',modality='{modality}')),
        subfields = bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi,Lflip|R}',modality='{modality}')
    threads: 8
    group: 'autotop'
    shell:
        'SINGULARITYENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        "{params.autotop_cmd}"

def get_autotop_inputseg_cmd (wildcards, input, output):
    autotop_dir = os.path.join(config['snakemake_dir'],'hippocampal_autotop')
    singularity_cmd = f"singularity exec -B {autotop_dir}:/src -e {config['singularity']['autotop']}" 

    if config['use_mcr'] == True:
        cmd = f"{singularity_cmd} /src/mcr_v97/run_AutoTops_TransformAndRollOut.sh /opt/mcr/v97 "\
                f"{input.nii} {output.out_dir} '{input.seg}' {config['cnn_model'][wildcards.modality]}"
    else:
        set_matlab_lic = f"SINGULARITYENV_MLM_LICENSE_FILE={config['mlm_license_file']}"
        set_java_home = f"SINGULARITYENV_JAVA_HOME={config['java_home']}"

        cmd = f"{set_matlab_lic} {set_java_home} {singularity_cmd} "\
                f"{config['matlab_bin']} -batch \"addpath(genpath('{autotop_dir}')); "\
                f"AutoTops_TransformAndRollOut('{input.nii}','{output.out_dir}','{input.seg}','{config['cnn_model'][wildcards.modality]}')\""
    return cmd   

rule run_autotop_inputseg:
    input:
        nii = get_autotop_input,
        seg = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}',from_='{modality}'),
    params:
        autotop_cmd = get_autotop_inputseg_cmd
    output:
        out_dir = directory(bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='{template}corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}')),
        subfields = bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}')
    threads: 8
    group: 'autotop'
    shell:
        'SINGULARITYENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        "{params.autotop_cmd}"




#rule to unflip a nifti
rule unflip_autotop_nii:
    input:
        nii = bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop/{filename}.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}flip',modality='{modality}')
    output:
        nii = bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop/{filename}.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi,L}',modality='{modality}')
    container: config['singularity']['prepdwi']
    group: 'autotop'
    shell: 'c3d {input} -flip x {output}'

   

rule resample_subfields_to_T1w:
    input:
        nii = bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='{template}corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='{template}corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='work/autotop',datatype='anat',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='{hemi}',modality='{modality}', **config['subj_wildcards'],template='{template}')
    container: config['singularity']['prepdwi']
    group: 'autotop'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation NearestNeighbor -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 

   
#right now this uses same labels for each, need to change this to a new lut
rule combine_lr_subfields:
    input:
        left = bids(root='work/autotop',datatype='anat',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='L',modality='{modality}', **config['subj_wildcards'],template='{template}'),
        right = bids(root='work/autotop',datatype='anat',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='R',modality='{modality}', **config['subj_wildcards'],template='{template}')
    output:
        combined = bids(root='results',datatype='anat',suffix='dseg.nii.gz', desc='subfields',space='T1w',modality='{modality}', **config['subj_wildcards'],template='{template}')
    container: config['singularity']['prepdwi']
    group: 'autotop'
    shell: 'c3d {input} -add -o {output}'
 
        
"""



def get_autotop_outputs (wildcards):

    out_dir = bids(root='work/autotop',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='{template}corobl',hemi='{hemi}',modality='{modality}')
    return { key: os.path.join(out_dir,val) for (key,val) in config['autotop_outputs']}


rule resample_to_native:
    input: unpack(get_autotop_outputs)

{directory(bids(root='work/autotop',**config['input_wildcards']['T2w'],suffix='autotop',desc='cropped',space='{template}corobl',hemi='{hemi}',modality='{modality}'))

"""
