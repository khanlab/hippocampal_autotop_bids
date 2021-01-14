import os
    

#creates command based on mcr or matlab
def get_autotop_cmd (wildcards, input, output):
    autotop_dir = os.path.join(config['snakemake_dir'],'hippocampal_autotop')

    if config['use_mcr'] == True:
        cmd = f"AUTOTOP_DIR={autotop_dir} {autotop_dir}/mcr_v97/run_AutoTops_TransformAndRollOut.sh /opt/mcr/v97 "\
                f"{input.nii} {output.out_dir} {config['cnn_model'][wildcards.modality]}"
    else:
        singularity_cmd = f"singularity exec -B {autotop_dir}:/src -e {config['singularity']['autotop']}" 
        set_matlab_lic = f"SINGULARITYENV_MLM_LICENSE_FILE={config['mlm_license_file']}"
        set_java_home = f"SINGULARITYENV_JAVA_HOME={config['java_home']}"
        set_autotop_dir = f"SINGULARITYENV_AUTOTOP_DIR={autotop_dir}"

        cmd = f"{set_matlab_lic} {set_java_home} {set_autotop_dir} {singularity_cmd} "\
                f"{config['matlab_bin']} -batch \"addpath(genpath('{autotop_dir}')); "\
                f"AutoTops_TransformAndRollOut('{input.nii}','{output.out_dir}','{config['cnn_model'][wildcards.modality]}')\""
    return cmd   



def get_autotop_input (wildcards):
    if wildcards.modality == 'T2w':
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T2w.nii.gz',desc='cropped',space='corobl',hemi='{hemi}'),
    elif wildcards.modality == 'T1w':
        nii = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz',desc='cropped',space='corobl',hemi='{hemi}'),
    elif wildcards.modality == '1mmT1w':
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
        nii = get_autotop_input
    params:
        autotop_cmd = get_autotop_cmd
    output:
        out_dir = directory(bids(root='work',**config['subj_wildcards'],suffix='autotop',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}')),
        subfields = bids(root='work',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        postproc = bids(root='work',**config['subj_wildcards'],suffix='autotop/labelmap-postProcess.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_unfold2native_extrap = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2native_extrapolateNearest.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2native.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        warp_native2unfold= bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_native2unfold.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}'),
        gii = expand(bids(root='work',suffix='autotop/{surfname}.unfoldedtemplate.surf.gii',desc='cropped', space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}', **config['subj_wildcards']),surfname=['inner','outer','midthickness'],allow_missing=True),
        coords = expand(bids(root='work',suffix='autotop/coords-{dir}.nii.gz',desc='cropped', space='corobl',hemi='{hemi,Lflip|R}',modality='{modality}', **config['subj_wildcards']),dir=['AP','PD','IO'],allow_missing=True)
    threads: 8
    resources:
        time = 60 #1 hr
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
        subfields = bids(root='work',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}'),
        warp_unfold2native = bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_unfold2native.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}'),
        warp_native2unfold= bids(root='work',**config['subj_wildcards'],suffix='autotop/Warp_native2unfold.nii',desc='cropped',space='corobl',hemi='{hemi,Lflip|R}',modality='seg{modality}'),
        gii = expand(bids(root='work',suffix='autotop/{surfname}.unfoldedtemplate.surf.gii',desc='cropped', space='corobl',hemi='{{hemi}}',modality='seg{{modality}}', **config['subj_wildcards']),surfname=['inner','outer','midthickness'],allow_missing=True)
    threads: 8
    resources:
        time = 60 #1 hr
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


   

rule resample_subfields_to_T1w:
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 

#create ref space for hires crop in native space
# TODO:  expose the resampling factor and size as cmd line args
rule create_native_crop_ref:
    input:
        seg = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    params:
        resample = '400%',
        pad_to = '192x256x256vox'
    output:
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'c3d {input} -binarize -interpolation NearestNeighbor -trim 0vox -resample {params.resample} -pad-to {params.pad_to} 0 {output}'
  
#this can be deprecated:
rule resample_matlab_subfields_native_crop:
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/subfields-BigBrain.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfieldsfrommatlab',space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 

 
rule resample_subfields_native_crop:
    input:
        nii = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='corobl',from_='volume',hemi='{hemi}', **config['subj_wildcards']),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    output:
        nii = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='cropT1w',from_='volume',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 

       

rule resample_niftynet_native_crop:
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/niftynet_lbl.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='niftynet',space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 


rule resample_labelpostproc_native_crop:
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/labelmap-postProcess.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='niftynetpostproc',space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 




rule resample_coords_native_crop:
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-{dir}.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    output:
        nii = bids(root='work',datatype='seg_{modality}',dir='{dir}',suffix='coords.nii.gz', space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation NearestNeighbor -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 

#get subfield labels using volumetric coords:
"""
rule label_subfields_from_vol_coords:
    input:  
        subfields_mat = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','BigBrain_ManualSubfieldsUnfolded.mat'),
        nii_ap = bids(root='work',datatype='seg_{modality}',dir='AP',suffix='coords.nii.gz', space='cropT1w',hemi='{hemi}', **config['subj_wildcards']),
        nii_pd = bids(root='work',datatype='seg_{modality}',dir='PD',suffix='coords.nii.gz', space='cropT1w',hemi='{hemi}', **config['subj_wildcards']),
    params:
        mat_name = 'subfields_avg' #avg bigbrain over L/R hemis
    output:
        nii_label = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='cropT1w',from_='volume',hemi='{hemi}', **config['subj_wildcards'])
    group: 'subj'
    script: '../scripts/label_subfields_from_vol_coords.py'
"""

#get subfield labels using volumetric coords:
rule label_subfields_from_vol_coords_corobl:
    input:  
        subfields_mat = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','BigBrain_ManualSubfieldsUnfolded.mat'),
        nii_ap = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-AP.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        nii_pd = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-PD.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
    params:
        mat_name = 'subfields_avg' #avg bigbrain over L/R hemis
    output:
        nii_label = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='corobl',from_='volume',hemi='{hemi}', **config['subj_wildcards'])
    group: 'subj'
    script: '../scripts/label_subfields_from_vol_coords.py'



#add srlm, cyst, dg from postproc labels to subfields
#input dg label 8, output 6
#input srlm label 2, output 7
#input cyst label 7, output 8

#first remap tissue labels to get three sep labels
# then, we just need to add those in, using max(old,new) to override old with new in case of conflict
rule combine_tissue_subfield_labels:
    input:
        tissue = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='niftynetpostproc',space='cropT1w',hemi='{hemi}', **config['subj_wildcards']),
        subfields = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='cropT1w',from_='volume',hemi='{hemi}', **config['subj_wildcards'])
    params:
        remap_dg = '-threshold 8 8 6 0 -popas dg',
        remap_srlm = '-threshold 2 2 7 0 -popas srlm',
        remap_cyst = '-threshold 7 7 8 0 -popas cyst',
    output:
        combined = bids(root='work',datatype='seg_{modality}',desc='subfieldswithtissue',suffix='dseg.nii.gz', space='cropT1w',from_='volume',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell: 
        'c3d {input.tissue} -dup {params.remap_dg} -dup {params.remap_srlm} {params.remap_cyst} {input.subfields} -push dg -max -push srlm -max -push cyst -max -o {output}'
        

#create gm ribbon from coords-IO:
# not actually used
rule create_gm_ribbon:
    input:
        io_coords = bids(root='work',datatype='seg_{modality}',dir='IO',suffix='coords.nii.gz', space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    output:
        ribbon = bids(root='work',datatype='seg_{modality}',desc='ribbon',suffix='mask.nii.gz', space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'c3d {input} {params.remap_dg} {params.remap_srlm} {params.remap_cyst} -threshold {params.in_dg} {params.in_dg} {params.out_dg} 0   {output}'

rule import_subfield_labels:
    input: os.path.join(config['snakemake_dir'],'resources','bigbrain','sub-bigbrain_hemi-{hemi}_subfields.label.gii')
    output: bids(root='work',datatype='surf_{modality}',desc='bigbrain',suffix='subfields.labels.gii', hemi='{hemi}', **config['subj_wildcards']),
    group: 'subj'
    shell: 'cp {input} {output}'
    
#map bigbrain subfields to volume
rule subfields_to_volume:
    input:
        label = bids(root='work',datatype='surf_{modality}',desc='bigbrain',suffix='subfields.labels.gii', hemi='{hemi}', **config['subj_wildcards']),
        midthickness = bids(root='work',datatype='surf_{modality}',suffix='midthickness.native.surf.gii', space='T1w',hemi='{hemi}', **config['subj_wildcards']),
        ref = bids(root='work',datatype='seg_{modality}',suffix='cropref.nii.gz', space='T1w',hemi='{hemi}', **config['subj_wildcards']),
        inner = bids(root='work',datatype='surf_{modality}',suffix='inner.native.surf.gii', space='T1w',hemi='{hemi}', **config['subj_wildcards']),
        outer = bids(root='work',datatype='surf_{modality}',suffix='outer.native.surf.gii', space='T1w',hemi='{hemi}', **config['subj_wildcards']),
    output:
        vol = bids(root='work',datatype='seg_{modality}',desc='subfields',from_='surface',suffix='dseg.nii.gz', space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'wb_command -label-to-volume-mapping {input.label} {input.midthickness} {input.ref} {output.vol} -ribbon-constrained {input.inner} {input.outer}'


#right now this uses same labels for each, need to change this to a new lut
rule combine_lr_subfields:
    input:
        left = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='L', **config['subj_wildcards']),
        right = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='R', **config['subj_wildcards'])
    output:
        combined = bids(root='results',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='T1w', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell: 'c3d {input} -add -o {output}'
 



