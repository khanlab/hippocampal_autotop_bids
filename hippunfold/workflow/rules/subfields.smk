rule label_subfields_from_vol_coords_corobl:
    """ Label subfields using the volumetric coords and bigbrain labels"""
    input:  
        subfields_mat = os.path.join(config['snakemake_dir'],'hippocampal_autotop','misc','BigBrain_ManualSubfieldsUnfolded.mat'),
        nii_ap = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-AP.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        nii_pd = bids(root='work',**config['subj_wildcards'],suffix='autotop/coords-PD.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
    params:
        mat_name = 'subfields_avg' #avg bigbrain over L/R hemis
    output:
        nii_label = bids(root='work',datatype='seg_{modality}',desc='subfieldsnotissue',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards'])
    group: 'subj'
    script: '../scripts/label_subfields_from_vol_coords.py'



rule combine_tissue_subfield_labels_corobl:
    """Combine subfield labels with the DG, SRLM and Cyst tissue labels
    
        add srlm, cyst, dg from postproc labels to subfields
        input dg label 8, output 6
        input srlm label 2, output 7
        input cyst label 7, output 8

        first remap tissue labels to get three sep labels
        then, we just need to add those in, using max(old,new) to override old with new in case of conflict
    """
    input:
        tissue = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz',desc='nnunet',space='corobl',hemi='{hemi}',**config['subj_wildcards']),
        subfields = bids(root='work',datatype='seg_{modality}',desc='subfieldsnotissue',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards'])
    params:
        remap_dg = '-threshold 8 8 6 0 -popas dg',
        remap_srlm = '-threshold 2 2 7 0 -popas srlm',
        remap_cyst = '-threshold 7 7 8 0 -popas cyst',
    output:
        combined = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell: 
        'c3d {input.tissue} -dup {params.remap_dg} -dup {params.remap_srlm} {params.remap_cyst} {input.subfields} -push dg -max -push srlm -max -push cyst -max -type uchar -o {output}'




rule resample_subfields_to_T1w:
    """Resampling to T1w native space"""
    input:
        nii = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards']),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='results',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 


rule resample_postproc_to_T1w:
    """Resample post-processed tissue seg to T1w"""
    input:
        nii = bids(root='work',**config['subj_wildcards'],suffix='autotop/labelmap-postProcess.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',modality='{modality}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='postproc',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 
  
rule resample_unet_to_T1w:
    """Resample unet tissue seg to T1w"""
    input:
        nii = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='nnunet',space='corobl',hemi='{hemi}'),
        xfm = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='xfm.txt',from_='T1w',to='corobl',desc='affine',type_='itk'),
        ref = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='T1w.nii.gz')
    output:
        nii = bids(root='work',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='unet',space='T1w',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.ref}  -t [{input.xfm},1]' 


rule get_subfield_vols_subj:
    """Export segmentation volume for a subject to TSV"""
    input: 
        segs = expand(bids(root='results',**config['subj_wildcards'],datatype='seg_{modality}',hemi='{hemi}',space='cropT1w',desc='subfields',suffix='dseg.nii.gz'),
                    hemi=['L','R'], allow_missing=True),
        lookup_tsv = os.path.join(config['snakemake_dir'],'resources','desc-subfields_dseg.tsv')
    group: 'subj'
    output: 
        tsv = bids(root='results',datatype='seg_{modality}',desc='subfields',suffix='volumes.tsv',**config['subj_wildcards']),
    script: '../scripts/gen_volume_tsv.py'



rule plot_subj_subfields:
    input:
        tsv = bids(root='results',datatype='seg_{modality}',desc='subfields',suffix='volumes.tsv',**config['subj_wildcards'])
    output:
        png = report(bids(root='work',datatype='qc',desc='subfields',from_='{modality}',suffix='volumes.png',**config['subj_wildcards']),
                caption='../report/subj_volume_plot.rst',
                category='Subfield Volumes')
    group: 'subj'
    script: '../scripts/plot_subj_subfields.py'


rule qc_subfield:
    input:
        img = bids(root='results',datatype='seg_{modality}',desc='preproc',suffix='{modality}.nii.gz', space='cropT1w',hemi='{hemi}', **config['subj_wildcards']),
        seg = bids(root='results',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='cropT1w',hemi='{hemi}', **config['subj_wildcards'])
    output:
        png = report(bids(root='work',datatype='qc',suffix='dseg.png', desc='subfields',from_='{modality}',space='cropT1w',hemi='{hemi}', **config['subj_wildcards']),
                caption='../report/subfield_qc.rst',
                category='Segmentation QC',
                subcategory='Subfields from {modality}'),
    group: 'subj'
    script: '../scripts/vis_qc_dseg.py'


rule concat_subj_vols_tsv:
    """Concatenate all subject tsv files into a single tsv"""
    input: 
        tsv = lambda wildcards: expand(bids(root='results',datatype=f'seg_{wildcards.modality}',desc='subfields',suffix='volumes.tsv',**config['subj_wildcards']),
                    subject=config['input_lists'][get_modality_key(wildcards.modality)]['subject'],
                    session=config['sessions'])
    group: 'aggregate'
    output: 
        tsv = bids(root='results',prefix='group',from_='{modality}',desc='subfields',suffix='volumes.tsv'),
    run: 
        import pandas as pd
        pd.concat([pd.read_table(in_tsv) for in_tsv in input ]).to_csv(output.tsv,sep='\t',index=False)


rule resample_subfields_to_unfold:
    """Resampling to unfold space"""
    input:
        nii = bids(root='work',datatype='seg_{modality}',desc='subfields',suffix='dseg.nii.gz', space='corobl',hemi='{hemi}', **config['subj_wildcards']),
        xfm = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='xfm.nii.gz',hemi='{hemi}',from_='corobl',to='unfold',mode='image')
    output:
        nii = bids(root='results',datatype='seg_{modality}',suffix='dseg.nii.gz', desc='subfields',space='unfold',hemi='{hemi}', **config['subj_wildcards'])
    container: config['singularity']['autotop']
    group: 'subj'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation MultiLabel -i {input.nii} -o {output.nii} -r {input.xfm}  -t {input.xfm}' 


