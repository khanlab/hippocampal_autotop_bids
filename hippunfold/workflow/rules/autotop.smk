import os
    

#creates command based on mcr or matlab
def get_autotop_cmd (wildcards, input, output):
    autotop_dir = os.path.join(config['snakemake_dir'],'hippocampal_autotop')

    if config['use_mcr'] == True:
        cmd = f"AUTOTOP_DIR={autotop_dir} {autotop_dir}/mcr_v97/run_AutoTops_TransformAndRollOut.sh /opt/mcr/v97 "\
                f"{input.nii} {output.out_dir} {config['cnn_model'][wildcards.modality]} {input.nnunet_seg}"
    else:
        singularity_cmd = f"singularity exec -B {autotop_dir}:/src -e {config['singularity']['autotop']}" 
        set_matlab_lic = f"SINGULARITYENV_MLM_LICENSE_FILE={config['mlm_license_file']}"
        set_java_home = f"SINGULARITYENV_JAVA_HOME={config['java_home']}"
        set_autotop_dir = f"SINGULARITYENV_AUTOTOP_DIR={autotop_dir}"

        cmd = f"{set_matlab_lic} {set_java_home} {set_autotop_dir} {singularity_cmd} "\
                f"{config['matlab_bin']} -batch \"addpath(genpath('{autotop_dir}')); "\
                f"AutoTops_TransformAndRollOut('{input.nii}','{output.out_dir}','{config['cnn_model'][wildcards.modality]}','{input.nnunet_seg}')\""
    return cmd   



def get_autotop_input (wildcards):
    if wildcards.modality == 'T2w':
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='corobl',hemi='{hemi}'),
    elif wildcards.modality == 'T1w':
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz',desc='cropped',space='corobl',hemi='{hemi}'),
    elif wildcards.modality == 'b500':
        nii = bids(root='work/preproc_dwi',suffix='b500.nii.gz',desc='cropped',datatype='dwi',**config['subj_wildcards'],space='corobl',hemi='{hemi}'),
    elif wildcards.modality == 'b1000':
        nii = bids(root='work/preproc_dwi',suffix='b1000.nii.gz',desc='cropped',datatype='dwi',**config['subj_wildcards'],space='corobl',hemi='{hemi}'),
    else:
        nii = ''

    return nii



rule run_autotop:
    input:
        nii = get_autotop_input,
        nnunet_seg = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='nnunet',space='corobl',hemi='{hemi}')
    params:
        autotop_cmd = get_autotop_cmd
    output:
        out_dir = directory(bids(root='work',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}')),
        #subfields = bids(root='work',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        postproc = bids(root='work',**config['subj_wildcards'],suffix='autotop/labelmap-postProcess.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_unfold2native_extrap = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2native_extrapolateNearest.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2native.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_native2unfold= bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_native2unfold.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warpitk_unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2native.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warpitk_native2unfold= bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_native2unfold.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        gii = expand(bids(root='work',suffix='autotop/{surfname}.unfoldedtemplate.surf.gii',desc='cropped', space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}', **config['subj_wildcards']),surfname=['inner','outer','midthickness'],allow_missing=True),
        coords = expand(bids(root='work',suffix='autotop/coords-{dir}.nii.gz',desc='cropped', space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}', **config['subj_wildcards']),dir=['AP','PD','IO'],allow_missing=True)
    threads: 8
    resources:
        time = 180 #3 hrs (so grouped job is set at 3hrs, since snakemake grouped resources not summed, but takes the max)
    group: 'subj'
    container: config['singularity']['autotop']
    log: bids(root='logs',**config['subj_wildcards'],space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}',suffix='autotop.txt')
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        "{params.autotop_cmd} &> {log}"

def get_autotop_inputseg_cmd (wildcards, input, output):
    autotop_dir = os.path.join(config['snakemake_dir'],'hippocampal_autotop')

    if config['use_mcr'] == True:
        cmd = f"AUTOTOP_DIR={autotop_dir} {autotop_dir}/mcr_v97/run_AutoTops_TransformAndRollOut.sh /opt/mcr/v97 "\
                f"{input.nii} {output.out_dir} '{input.seg}' {config['cnn_model'][wildcards.modality]}"
    else:
        singularity_cmd = f"singularity exec -B {autotop_dir}:/src -e {config['singularity']['autotop']}" 
        set_matlab_lic = f"SINGULARITYENV_MLM_LICENSE_FILE={config['mlm_license_file']}"
        set_java_home = f"SINGULARITYENV_JAVA_HOME={config['java_home']}"
        set_autotop_dir = f"SINGULARITYENV_AUTOTOP_DIR={autotop_dir}"

        cmd = f"{set_matlab_lic} {set_java_home} {set_autotop_dir} {singularity_cmd} "\
                f"{config['matlab_bin']} -batch \"addpath(genpath('{autotop_dir}')); "\
                f"AutoTops_TransformAndRollOut('{input.nii}','{output.out_dir}','{config['cnn_model'][wildcards.modality]},'{input.seg}'')\""
    return cmd   

rule run_autotop_inputseg:
    input:
        nii = get_autotop_input,
        seg = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',from_='{modality}'),
    params:
        autotop_cmd = get_autotop_inputseg_cmd
    output:
        out_dir = directory(bids(root='work',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}')),
        #subfields = bids(root='work',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}'),
        warp_unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2native.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_native2unfold= bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_native2unfold.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warpitk_unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2native.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warpitk_native2unfold= bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_native2unfold.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        gii = expand(bids(root='work',suffix='autotop/{surfname}.unfoldedtemplate.surf.gii',desc='cropped', space='corobl',hemi='{{hemi}}',modality='seg{{modality}}', **config['subj_wildcards']),surfname=['inner','outer','midthickness'],allow_missing=True)
    threads: 8
    resources:
        time = 180 #3 hrs (so grouped job is set at 3hrs, since snakemake grouped resources not summed, but takes the max)
    group: 'subj'
    container: config['singularity']['autotop']
    log: bids(root='logs',**config['subj_wildcards'],space='corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}',suffix='autotop.txt')
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        "{params.autotop_cmd} &> {log}"

rule copy_unfold_ref_to_autotop:
    input:
        autotop_dir = bids(root='work',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        unfold_ref = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','unfold_ref_256x128x16.nii.gz'),
    output:
        unfold_ref = bids(root='work',**config['subj_wildcards'],suffix='autotop/unfold_ref_256x128x16.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
    group: 'subj'
    shell: 'cp {input.unfold_ref} {output.unfold_ref}'

#full-grid correction of unfolded space
rule map_to_full_grid:
    input: 
        autotop_dir = bids(root='work',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        warp_unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2native.nii',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        unfold_ref = bids(root='work',**config['subj_wildcards'],suffix='autotop/unfold_ref_256x128x16.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
    params:
        script = os.path.join(config['snakemake_dir'],'workflow','scripts','mapUnfoldToFullGrid.sh')
    output:
        warp_unfoldtemplate2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfoldtemplate2unfold.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_unfold2unfoldtemplate = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2unfoldtemplate.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warpitk_unfoldtemplate2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0InverseWarp.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warpitk_unfold2unfoldtemplate = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0Warp.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
    container: config['singularity']['autotop']
    group: 'subj'
    threads: 8
    resources:
        time = 15 #15min
    log: bids(root='logs',**config['subj_wildcards'],space='corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}',suffix='mapUnfoldToFullGrid.txt')
    shell:
        'SINGULARITYENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        '{params.script} {input.autotop_dir} {input.autotop_dir} &> {log}'


#rule to unflip a nifti
rule unflip_autotop_nii:
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/{filename}.nii.gz',desc='cropped',space='corobl',hemi='{hemi}flip',modality='{modality}')
    output:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/{filename}.nii.gz',desc='cropped',space='corobl',hemi='{hemi,L}',modality='{modality}')
    container: config['singularity']['autotop']
    group: 'subj'
    shell: 'c3d {input} -flip x {output}'


rule compose_warps_corobl2unfold_rhemi:
    """ Compose corobl to unfold (unfold-template), for right hemi (ie no flip)"""
    input:
        native2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_native2unfold.nii',desc='cropped',space='corobl',hemi='R',modality='{modality}'),
        unfold2unfoldtemplate = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0Warp.nii.gz',desc='cropped',space='corobl',hemi='R',modality='{modality}'),
        ref = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','unfold_ref_256x128x16.nii.gz'),
    output:
        corobl2unfold = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='R',from_='corobl',to='unfold',mode='image')
    container: config['singularity']['ants']
    group: 'subj'
    shell: 'ComposeMultiTransform 3 {output.corobl2unfold} -R {input.ref} {input.unfold2unfoldtemplate} {input.native2unfold}'


rule compose_warps_corobl2unfold_lhemi:
    """ Compose corobl to unfold (unfold-template), for left hemi (ie with flip)"""
    input:
        native2unfold = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_native2unfold.nii',desc='cropped',space='corobl',hemi='Lflip',modality='{modality}'),
        unfold2unfoldtemplate = bids(root='work',**config['subj_wildcards'],suffix='autotop/WarpITK_unfold2unfoldtemplate_0Warp.nii.gz',desc='cropped',space='corobl',hemi='Lflip',modality='{modality}'),
        ref = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','unfold_ref_256x128x16.nii.gz'),
        flipLR_xfm = os.path.join(config['snakemake_dir'],'resources','desc-flipLR_type-itk_xfm.txt')
    output:
        corobl2unfold = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='L',from_='corobl',to='unfold',mode='image')
    container: config['singularity']['ants']
    group: 'subj'
    shell: 'ComposeMultiTransform 3 {output.corobl2unfold} -R {input.ref} {input.unfold2unfoldtemplate} {input.native2unfold} {input.flipLR_xfm}'


 
rule compose_warps_t1_to_unfold:
    """ Compose warps from T1w to unfold """
    input:
        corobl2unfold = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='{hemi}',from_='corobl',to='unfold',mode='image'),
        ref = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','unfold_ref_256x128x16.nii.gz'),
        t1w2corobl = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
    output: 
        bids(root='results',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='{hemi}',from_='T1w',to='unfold',mode='image')
    container: config['singularity']['ants']
    group: 'subj'
    shell: 'ComposeMultiTransform 3 {output} -R {input.ref} {input.corobl2unfold} {input.t1w2corobl}'


   
