
#take mean of all scans if >1, otherwise just copy the one scan
def get_avg_or_cp_scans_cmd (wildcards, input, output):
    if len(input) > 1:
        cmd = f'c3d {input} -mean -o {output}'
    else:
        cmd = f'cp {input} {output}'
    return cmd



def get_modality_key(modality):
    if modality[:3] == 'seg': 
        return 'seg'
    else:
        return modality

def get_modality_suffix (modality):
    if modality[:3] == 'seg':
        return modality[3:]
    elif modality[:4] == 'hipp':
        return modality[4:]
    else:
        return modality



def get_final_spec():
    if 'cropT1w' in  config['output_spaces']:
        return expand(
            bids(root='results',datatype='surf_{modality}',suffix='hippunfold.spec', **config['subj_wildcards']),
            allow_missing=True)
    else:
        return []

def get_final_subfields():
    return expand(
        bids(
                root='results',datatype='seg_{modality}',
                desc='subfields',suffix='dseg.nii.gz',
                space='{space}',hemi='{hemi}', **config['subj_wildcards']),
            hemi=['L','R'],
            space=config['output_spaces'],
            allow_missing=True)

def get_final_coords():
    return expand(
        bids(
            root='results',datatype='seg_{modality}',dir='{dir}',suffix='coords.nii.gz', space='{space}',hemi='{hemi}', **config['subj_wildcards']),
                dir=['AP','PD','IO'],
                hemi=['L','R'],
                space=config['output_spaces'],
                allow_missing=True)


def get_final_transforms():
    if 'cropT1w' in  config['output_spaces']: 
        output_ref = 'T1w'
    else:
        output_ref = 'corobl'

    return expand(
        bids(
                root='results',
                datatype='seg_{modality}',
                **config['subj_wildcards'],
                suffix='xfm.nii.gz',
                hemi='{hemi}',
                from_='{space}',
                to='unfold',
                mode='image'),
            space=output_ref,
            hemi=['L','R'],
            allow_missing=True)


def get_final_anat():
    return expand(
        bids(
                root='results',
                datatype='seg_{modality}',
                desc='preproc',
                suffix='{modality_suffix}.nii.gz',
                space='{space}',
                hemi='{hemi}',
                **config['subj_wildcards']),
            space=config['output_spaces'],
            hemi=['L','R'],
            allow_missing=True)


def get_final_qc():
    qc = []
    #right now can only do qc from cropT1w space 
    if 'cropT1w' in config['output_spaces']:
        qc.extend(
            expand(
                bids(
                        root='results',
                        datatype='qc',
                        suffix='regqc.png',
                        from_='subject', 
                        to=config['template'],
                        **config['subj_wildcards']),
                    allow_missing=True)
            )

        qc.extend(
            expand(
                bids(
                        root='results',
                        datatype='qc',
                        suffix='dseg.png',
                        desc='subfields',
                        from_='{modality}',
                        slice_='{slice}',
                        space='cropT1w',
                        hemi='{hemi}',
                        **config['subj_wildcards']),
                    hemi=['L','R'],
                    slice=['1','2','3'],
                    allow_missing=True)
            )
#        qc.extend(
#            expand(
#                bids(
#                        root='results',
#                        datatype='qc',
#                        suffix='midthickness.surf.png', 
#                        desc='subfields',
#                        from_='{modality}',
#                        space='cropT1w',
#                        hemi='{hemi}',
#                        **config['subj_wildcards']),
#                    hemi=['L','R'],
#                    allow_missing=True)
#            ) 
        qc.extend(
            expand(
                bids(
                        root='results',
                        datatype='qc',
                        desc='subfields',
                        from_='{modality}',
                        suffix='volumes.png',
                        **config['subj_wildcards']),
                    allow_missing=True)
            )
        qc.extend(
            expand(
                bids(
                        root='results',
                        datatype='qc',
                        desc='unetf3d',
                        suffix='dice.tsv',
                        from_='{modality}',
                        hemi='{hemi}',
                        **config['subj_wildcards']),
                    hemi=['L','R'],
                    allow_missing=True)
            )
    return qc


def get_final_subj_output():
    subj_output = []
    subj_output.extend(get_final_spec())
    subj_output.extend(get_final_subfields())
    subj_output.extend(get_final_coords())
    subj_output.extend(get_final_transforms())
    subj_output.extend(get_final_anat())
    subj_output.extend(get_final_qc())
    return subj_output

   

def get_final_output():

    if config['keep_work'] or len(config['modality']) > 1:
        subj_output = get_final_subj_output()
    else:
        subj_output = get_final_work_tar()

    final_output = []
    for modality in config['modality']:

        modality_suffix = get_modality_suffix(modality)
        modality_key = get_modality_key(modality)

        final_output.extend(
            expand(subj_output,
                    modality=modality,
                    modality_suffix=modality_suffix,
                    subject=config['input_lists'][modality_key]['subject'],
                    session=config['sessions'])
            )

    return final_output


rule copy_to_results:
    """ Generic rule for copying data from work to results"""
    input: 'work/{file}'
    output: 'results/{file}'
    group: 'subj'
    shell: 'cp {input} {output}'


def get_final_work_tar():
    return bids(root='work',bgimg='{modality_suffix}',suffix='work.tar.gz',modality='{modality}',
                include_subject_dir=False,
                include_session_dir=False,
                **config['subj_wildcards'])


def get_work_dir(wildcards):
    folder_with_file = expand(bids(root='work',**config['subj_wildcards']),**wildcards)
    folder_without_file = os.path.dirname(folder_with_file[0])
    return folder_without_file


rule archive_work_after_final:
    input: get_final_subj_output()
    params:
        work_dir = get_work_dir
    output: get_final_work_tar()
    group: 'subj'
    shell: 'tar -cvzf {output} {params.work_dir} && rm -rf {params.work_dir}'


def get_input_for_shape_inject(wildcards):
    if get_modality_key(wildcards.modality) == 'seg':
        modality_suffix = get_modality_suffix(wildcards.modality)
        seg = bids(root='work',datatype='anat',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='cropped',space='corobl',hemi='{hemi}',from_='{modality_suffix}').format(
                    **wildcards, modality_suffix=modality_suffix),
    else:
        seg = bids(root='work',datatype='seg_{modality}',**config['subj_wildcards'],suffix='dseg.nii.gz',desc='nnunet',space='corobl',hemi='{hemi}').format(**wildcards)
    return seg


