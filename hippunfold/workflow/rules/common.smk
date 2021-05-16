
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
    if 'T1w' in config['modality']:
        qc.extend(
            expand(
                bids(
                        root='work',
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
                    root='work',
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
    qc.extend(
        expand(
            bids(
                    root='work',
                    datatype='qc',
                    suffix='midthickness.surf.png', 
                    desc='subfields',
                    from_='{modality}',
                    space='cropT1w',
                    hemi='{hemi}',
                    **config['subj_wildcards']),
                hemi=['L','R'],
                allow_missing=True)
        ) 
    qc.extend(
        expand(
            bids(
                    root='work',
                    datatype='qc',
                    desc='subfields',
                    from_='{modality}',
                    suffix='volumes.png',
                    **config['subj_wildcards']),
                allow_missing=True)
        )
    return qc


def get_final_output():

    subj_outputs = []
    subj_outputs.extend(get_final_spec())
    subj_outputs.extend(get_final_subfields())
    subj_outputs.extend(get_final_coords())
    subj_outputs.extend(get_final_transforms())
    subj_outputs.extend(get_final_anat())
    subj_outputs.extend(get_final_qc())

    final_output = []
    for modality in config['modality']:

        #need to skip if modality == hippb500 ??

        modality_suffix = get_modality_suffix(modality)
        modality_key = get_modality_key(modality)

        final_output.extend(
            expand(subj_outputs,
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
