from snakebids import bids

wildcard_constraints:
    shell = "[0-9]+",

include: 'masking_bet_from-b0.smk'

rule import_dwi:
    input: 
        nii = [re.sub('.nii.gz',ext,config['input_path']['dwi']) for ext in ['.nii.gz','.bval','.bvec','.json']]
    output:
        nii = multiext(bids(root='work/preproc_dwi',suffix='dwi', datatype='dwi',**config['input_wildcards']['dwi']),'.nii.gz','.bval','.bvec','.json')
    group: 'dwi'
    run:
        for in_file,out_file in zip(input,output):
            shell('cp -v {in_file} {out_file}')

rule dwidenoise:
    input: multiext(bids(root='work/preproc_dwi',suffix='dwi',datatype='dwi',**config['input_wildcards']['dwi']),\
                    '.nii.gz','.bvec','.bval','.json')
    output: multiext(bids(root='work/preproc_dwi',suffix='dwi',desc='denoise',datatype='dwi',**config['input_wildcards']['dwi']),\
                    '.nii.gz','.bvec','.bval','.json')
    container: config['singularity']['prepdwi']
    log: bids(root='logs',suffix='denoise.log',**config['input_wildcards']['dwi'])
    group: 'dwi'
    shell: 'dwidenoise {input[0]} {output[0]} 2> {log} && ' 
            'cp {input[1]} {output[1]} && '
            'cp {input[2]} {output[2]} && '
            'cp {input[3]} {output[3]}'


def get_degibbs_inputs (wildcards):
    # if input dwi at least 30 dirs, then grab denoised as input
    # else grab without denoising 
    import numpy as np
    in_dwi_bval = re.sub('.nii.gz','.bval',config['input_path']['dwi'].format(**wildcards))
    bvals = np.loadtxt(in_dwi_bval)
    if bvals.size < 30:
        prefix = bids(root='work/preproc_dwi',suffix='dwi',datatype='dwi',**wildcards)
    else:
        prefix = bids(root='work/preproc_dwi',suffix='dwi',datatype='dwi',desc='denoise',**wildcards)
    return multiext(prefix,'.nii.gz','.bvec','.bval','.json')
 
rule mrdegibbs:
    input: get_degibbs_inputs
    output: multiext(bids(root='work/preproc_dwi',suffix='dwi',datatype='dwi',desc='degibbs',**config['input_wildcards']['dwi']),\
                    '.nii.gz','.bvec','.bval','.json')
    container: config['singularity']['prepdwi']
#    log: bids(root='logs',suffix='degibbs.log',**config['input_wildcards']['dwi'])
    group: 'dwi'
    shell: 'mrdegibbs {input[0]} {output[0]} && '#2> {log} && ' 
            'cp {input[1]} {output[1]} && '
            'cp {input[2]} {output[2]} && '
            'cp {input[3]} {output[3]}'


#now have nii with just the b0's, want to create the topup phase-encoding text files for each one:
rule get_phase_encode_txt:
    input:
        bzero_nii = bids(root='work/preproc_dwi',suffix='b0.nii.gz',datatype='dwi',desc='degibbs',**config['input_wildcards']['dwi']),
        json = bids(root='work/preproc_dwi',suffix='dwi.json',datatype='dwi',desc='degibbs',**config['input_wildcards']['dwi'])
    output:
        phenc_txt = bids(root='work/preproc_dwi',suffix='phenc.txt',datatype='dwi',desc='degibbs',**config['input_wildcards']['dwi']),
    group: 'dwi'
    script: '../scripts/preproc_dwi/get_phase_encode_txt.py'
        


rule concat_phase_encode_txt:
    input:
        phenc_txts = lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='phenc.txt',datatype='dwi',desc='degibbs',**config['input_wildcards']['dwi']),\
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output:
        phenc_concat = bids(root='work/preproc_dwi',suffix='phenc.txt',datatype='dwi',desc='degibbs',**config['subj_wildcards'])
    group: 'dwi'
    shell: 'cat {input} > {output}'

rule concat_bzeros:
    input:
        bzero_niis = lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='b0.nii.gz',datatype='dwi',desc='degibbs',**config['input_wildcards']['dwi']),\
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output:
        bzero_concat = bids(root='work/preproc_dwi',suffix='concatb0.nii.gz',datatype='dwi',desc='degibbs',**config['subj_wildcards'])
    container: config['singularity']['prepdwi']
    log: bids(root='logs',suffix='concat_bzeros.log',**config['subj_wildcards'])
    group: 'dwi'
    shell: 'mrcat {input} {output} 2> {log}'


rule run_topup:
    input:
        bzero_concat = bids(root='work/preproc_dwi',suffix='concatb0.nii.gz',datatype='dwi',desc='degibbs',**config['subj_wildcards']),
        phenc_concat = bids(root='work/preproc_dwi',suffix='phenc.txt',datatype='dwi',desc='degibbs',**config['subj_wildcards'])
    params:
        out_prefix = bids(root='work/preproc_dwi',suffix='topup',datatype='dwi',**config['subj_wildcards']),
        config = 'b02b0.cnf' #this config sets the multi-res schedule and other params..
    output:
        bzero_corrected = bids(root='work/preproc_dwi',suffix='concatb0.nii.gz',desc='topup',datatype='dwi',**config['subj_wildcards']),
        fieldmap = bids(root='work/preproc_dwi',suffix='fmap.nii.gz',desc='topup',datatype='dwi',**config['subj_wildcards']),
        topup_fieldcoef = bids(root='work/preproc_dwi',suffix='topup_fieldcoef.nii.gz',datatype='dwi',**config['subj_wildcards']),
        topup_movpar = bids(root='work/preproc_dwi',suffix='topup_movpar.txt',datatype='dwi',**config['subj_wildcards']),
    container: config['singularity']['prepdwi']
    log: bids(root='logs',suffix='topup.log',**config['subj_wildcards'])
    group: 'dwi'
    shell: 'topup --imain={input.bzero_concat} --datain={input.phenc_concat} --config={params.config}'
           ' --out={params.out_prefix} --iout={output.bzero_corrected} --fout={output.fieldmap} -v 2> {log}'


#this is for equal positive and negative blipped data - method=lsr
rule apply_topup_lsr:
    input:
        dwi_niis = lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='degibbs',datatype='dwi',**config['input_wildcards']['dwi']),\
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards)),
        phenc_concat = bids(root='work/preproc_dwi',suffix='phenc.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        topup_fieldcoef = bids(root='work/preproc_dwi',suffix='topup_fieldcoef.nii.gz',datatype='dwi',**config['subj_wildcards']),
        topup_movpar = bids(root='work/preproc_dwi',suffix='topup_movpar.txt',datatype='dwi',**config['subj_wildcards']),
    params:
        #create comma-seperated list of dwi nii
        imain = lambda wildcards, input: ','.join(input.dwi_niis), 
        # create comma-sep list of indices 1-N
        inindex = lambda wildcards, input: ','.join([str(i) for i in range(1,len(input.dwi_niis)+1)]), 
        topup_prefix = bids(root='work/preproc_dwi',suffix='topup',datatype='dwi',**config['subj_wildcards']),
        out_prefix = 'dwi_topup',
    output: 
        dwi_topup = bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='topup',method='lsr',datatype='dwi',**config['subj_wildcards'])
    container: config['singularity']['prepdwi']
    shadow: 'minimal'
    group: 'dwi'
    shell: 'applytopup --verbose --datain={input.phenc_concat} --imain={params.imain} --inindex={params.inindex} '
           ' -t {params.topup_prefix} -o {params.out_prefix} && '
           ' fslmaths {params.out_prefix}.nii.gz {output.dwi_topup}'



rule apply_topup_jac:
    input:
        nii = bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='degibbs',datatype='dwi',**config['input_wildcards']['dwi']), 
        phenc_scan = bids(root='work/preproc_dwi',suffix='phenc.txt',datatype='dwi',desc='degibbs',**config['input_wildcards']['dwi']),
        phenc_concat = bids(root='work/preproc_dwi',suffix='phenc.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        topup_fieldcoef = bids(root='work/preproc_dwi',suffix='topup_fieldcoef.nii.gz',datatype='dwi',**config['subj_wildcards']),
        topup_movpar = bids(root='work/preproc_dwi',suffix='topup_movpar.txt',datatype='dwi',**config['subj_wildcards']),
    params:
        topup_prefix = bids(root='work/preproc_dwi',suffix='topup',datatype='dwi',**config['subj_wildcards']),
    output: 
        nii = bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='topup',method='jac',datatype='dwi',**config['input_wildcards']['dwi']), 
    container: config['singularity']['prepdwi']
    shadow: 'minimal'
    group: 'dwi'
    shell: 
        'line=`cat {input.phenc_scan}` && inindex=`grep -n "$line" {input.phenc_concat} | cut -f1 -d:` && '
        ' applytopup --verbose --datain={input.phenc_concat} --imain={input.nii} --inindex=$inindex ' 
        ' -t {params.topup_prefix} -o dwi_topup --method=jac && mv dwi_topup.nii.gz {output.nii}'


#topup-corrected data is only used for brainmasking.. 
# here, use the jac method by default (later can decide if lsr approach can be used based on headers)
# with jac approach, the jac images need to be concatenated, then avgshell extracted

"""
rule cp_sidecars_topup_lsr:
    #TODO: BEST WAY TO TO EXEMPLAR DWI? 
    input: multiext(bids(root='work/preproc_dwi',suffix='dwi',desc='degibbs',datatype='dwi',**config['subj_wildcards'],**dwi_exemplar_dict),\
                '.bvec','.bval','.json')
    output: multiext(bids(root='work/preproc_dwi',suffix='dwi',desc='topup',method='lsr',datatype='dwi',**config['subj_wildcards']),\
                '.bvec','.bval','.json')
    run:
        for in_file,out_file in zip(input,output):
            shell('cp -v {in_file} {out_file}')
"""

rule cp_sidecars_topup_jac:
    input: multiext(bids(root='work/preproc_dwi',suffix='dwi',desc='degibbs',datatype='dwi',**config['subj_wildcards']),\
                '.bvec','.bval','.json')
    output: multiext(bids(root='work/preproc_dwi',suffix='dwi',desc='topup',method='jac',datatype='dwi',**config['subj_wildcards']),\
                '.bvec','.bval','.json')
    group: 'dwi'
    run:
        for in_file,out_file in zip(input,output):
            shell('cp -v {in_file} {out_file}')

rule concat_dwi_topup_jac:
    input:
        dwi_niis = lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='topup',method='jac',datatype='dwi',**config['input_wildcards']['dwi']),\
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output:
        dwi_concat = bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='topup',method='jac',datatype='dwi',**config['subj_wildcards'])
    container: config['singularity']['prepdwi']
    group: 'dwi'
    shell: 'mrcat {input} {output}' 


rule get_eddy_index_txt:
    input:
        dwi_niis = lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='degibbs',datatype='dwi',**config['input_wildcards']['dwi']),\
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output:
        eddy_index_txt = bids(root='work/preproc_dwi',suffix='dwi.eddy_index.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
    group: 'dwi'
    script: '../scripts/preproc_dwi/get_eddy_index_txt.py'
 
rule concat_degibbs_dwi:
    input:
        dwi_niis = lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='degibbs',datatype='dwi',**config['input_wildcards']['dwi']),\
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output:
        dwi_concat = bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='degibbs',datatype='dwi',**config['subj_wildcards'])
    container: config['singularity']['prepdwi']
    log: bids(root='logs',suffix='concat_degibbs_dwi.log',**config['subj_wildcards'])
    group: 'dwi'
    shell: 'mrcat {input} {output} 2> {log}' 

rule concat_runs_bvec:
    input:
        lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.bvec',desc='{{desc}}',datatype='dwi',**config['input_wildcards']['dwi']),
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output: bids(root='work/preproc_dwi',suffix='dwi.bvec',desc='{desc}',datatype='dwi',**config['subj_wildcards'])
    group: 'dwi'
    script: '../scripts/preproc_dwi/concat_bv.py' 

rule concat_runs_bval:
    input:
        lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.bval',desc='{{desc}}',datatype='dwi',**config['input_wildcards']['dwi']),
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output: bids(root='work/preproc_dwi',suffix='dwi.bval',desc='{desc}',datatype='dwi',**config['subj_wildcards'])
    group: 'dwi'
    script: '../scripts/preproc_dwi/concat_bv.py' 

#combines json files from multiple scans -- for now as a hack just copying first json over..
rule concat_runs_json:
    input:
        lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.json',desc='{{desc}}',datatype='dwi',**config['input_wildcards']['dwi']),
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output: bids(root='work/preproc_dwi',suffix='dwi.json',desc='{desc}',datatype='dwi',**config['subj_wildcards'])
    group: 'dwi'
    shell: 'cp {input[0]} {output}'
#    script: '../scripts/preproc_dwi/concat_json.py' 


rule get_shells_from_bvals:
    input: '{dwi_prefix}.bval'
    output: '{dwi_prefix}.shells.json'
    group: 'dwi'
    script:
        '../scripts/preproc_dwi/get_shells_from_bvals.py'
 
#writes 4d file
rule get_shell_avgs:
    input: 
        dwi = '{dwi_prefix}.nii.gz',
        shells = '{dwi_prefix}.shells.json'
    output: 
        avgshells = '{dwi_prefix}.avgshells.nii.gz'
    group: 'dwi'
    script:
        '../scripts/preproc_dwi/get_shell_avgs.py'

#this gets a particular shell (can use to get b0)
rule get_shell_avg:
    input:
        dwi = '{dwi_prefix}_dwi.nii.gz',
        shells = '{dwi_prefix}_dwi.shells.json'
    params:
        bval = '{shell}'
    output:
        avgshell = '{dwi_prefix}_b{shell}.nii.gz'
    group: 'dwi'
    script:
        '../scripts/preproc_dwi/get_shell_avg.py'

#have multiple brainmasking workflows -- this rule picks the method chosen in the config file
def get_mask_for_eddy(wildcards):

    #first get name of method
    if wildcards.subject in config['masking']['custom']:
        method = config['masking']['custom'][wildcards.subject]
    else:
        method = config['masking']['default_method']

    #then get bids name of file 
    return bids(root='work/preproc_dwi',suffix='mask.nii.gz',desc='brain',method=method,datatype='dwi',**config['subj_wildcards'])


#generate qc snapshot for brain  mask 
rule qc_brainmask_for_eddy:
    input:
        img = bids(root='work/preproc_dwi',suffix='b0.nii.gz',desc='topup',method='jac',datatype='dwi',**config['subj_wildcards']),
        seg = get_mask_for_eddy
    output:
#        png = bids(root='qc',subject='{subject}',suffix='mask.png',desc='brain'),
        png = report(bids(root='qc',suffix='mask.png',desc='brain',**config['subj_wildcards']),
                caption='../report/brainmask_dwi.rst',
                category='Brainmask'),

        html = bids(root='qc',suffix='mask.html',desc='brain',**config['subj_wildcards']),
#        html = report(bids(root='qc',subject='{subject}',suffix='dseg.html',atlas='{atlas}', from_='{template}'),
#                caption='../reports/segqc.rst',
#                category='Segmentation QC',
#                subcategory='{atlas} Atlas from {template}'),
    group: 'dwi'
    script: '../scripts/preproc_dwi/vis_qc_dseg.py'

    
rule get_slspec_txt:
    input:
        dwi_jsons = lambda wildcards: expand(bids(root='work/preproc_dwi',suffix='dwi.json',desc='degibbs',datatype='dwi',**config['input_wildcards']['dwi']),
                            zip,**snakebids.filter_list(config['input_zip_lists']['dwi'], wildcards))
    output:
        eddy_slspec_txt = bids(root='work/preproc_dwi',suffix='dwi.eddy_slspec.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
    group: 'dwi'
    script: '../scripts/preproc_dwi/get_slspec_txt.py'
         
 
rule run_eddy:
    input:        
        dwi_concat = bids(root='work/preproc_dwi',suffix='dwi.nii.gz',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        phenc_concat = bids(root='work/preproc_dwi',suffix='phenc.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        eddy_index_txt = bids(root='work/preproc_dwi',suffix='dwi.eddy_index.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        eddy_slspec_txt = bids(root='work/preproc_dwi',suffix='dwi.eddy_slspec.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        brainmask = get_mask_for_eddy,
        bvals = bids(root='work/preproc_dwi',suffix='dwi.bval',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        bvecs = bids(root='work/preproc_dwi',suffix='dwi.bvec',desc='degibbs',datatype='dwi',**config['subj_wildcards'])
    params:
        #set eddy output prefix to 'dwi' inside the output folder
        out_prefix = lambda wildcards, output: os.path.join(output.out_folder,'dwi'),
        topup_prefix = bids(root='work/preproc_dwi',suffix='topup',datatype='dwi',**config['subj_wildcards']),
        flags = ' '.join([f'--{key}' for (key,value) in config['eddy']['flags'].items() if value == True ] ),
        options = ' '.join([f'--{key}={value}' for (key,value) in config['eddy']['opts'].items() if value is not None ] ),
        container = config['singularity']['fsl']
    output:
        #eddy creates many files, so write them to a eddy subfolder instead
        out_folder = directory(bids(root='work/preproc_dwi',suffix='eddy',datatype='dwi',**config['subj_wildcards'])),
        dwi = os.path.join(bids(root='work/preproc_dwi',suffix='eddy',datatype='dwi',**config['subj_wildcards']),'dwi.nii.gz'),
        bvec = os.path.join(bids(root='work/preproc_dwi',suffix='eddy',datatype='dwi',**config['subj_wildcards']),'dwi.eddy_rotated_bvecs')
#    container: config['singularity']['fsl']
    threads: 1
    resources:
        gpus = 1,
        time = 240, #6 hours (this is a conservative estimate, may be shorter)
        mem_mb = 32000,
    log: bids(root='logs',suffix='run_eddy.log',**config['subj_wildcards'])
    group: 'dwi'
    shell: 'singularity exec --nv -e {params.container} eddy_cuda9.1 --imain={input.dwi_concat} --mask={input.brainmask} '
            ' --acqp={input.phenc_concat} --index={input.eddy_index_txt} '
            ' --bvecs={input.bvecs} --bvals={input.bvals} --topup={params.topup_prefix} '
            ' --slspec={input.eddy_slspec_txt} ' 
            ' --out={params.out_prefix} '
            ' {params.flags} {params.options}  &> {log}'


rule cp_eddy_outputs:
    input:
        #get nii.gz, bvec, and bval from eddy output
        dwi = os.path.join(bids(root='work/preproc_dwi',suffix='eddy',datatype='dwi',**config['subj_wildcards']),'dwi.nii.gz'),
        bvec = os.path.join(bids(root='work/preproc_dwi',suffix='eddy',datatype='dwi',**config['subj_wildcards']),'dwi.eddy_rotated_bvecs'),
        bval = bids(root='work/preproc_dwi',suffix='dwi.bval',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
    output:
        multiext(bids(root='work/preproc_dwi',suffix='dwi',desc='eddy',datatype='dwi',**config['subj_wildcards']),'.nii.gz','.bvec','.bval')
    group: 'dwi'
    run:
        for in_file,out_file in zip(input,output):
            shell('cp -v {in_file} {out_file}')

rule eddy_quad:
    input:
        phenc_concat = bids(root='work/preproc_dwi',suffix='phenc.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        eddy_index_txt = bids(root='work/preproc_dwi',suffix='dwi.eddy_index.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        eddy_slspec_txt = bids(root='work/preproc_dwi',suffix='dwi.eddy_slspec.txt',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        brainmask = get_mask_for_eddy,
        bvals = bids(root='work/preproc_dwi',suffix='dwi.bval',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        bvecs = bids(root='work/preproc_dwi',suffix='dwi.bvec',desc='degibbs',datatype='dwi',**config['subj_wildcards']),
        fieldmap = bids(root='work/preproc_dwi',suffix='fmap.nii.gz',desc='topup',datatype='dwi',**config['subj_wildcards']),
        eddy_dir = bids(root='work/preproc_dwi',suffix='eddy',datatype='dwi',**config['subj_wildcards'])
    params: 
        eddy_prefix = lambda wildcards, input: os.path.join(input.eddy_dir,'dwi'),
    output:
        out_dir = directory(bids(root='work/preproc_dwi',suffix='eddy.qc',datatype='dwi',**config['subj_wildcards'])),
        eddy_qc_pdf = bids(root='work/preproc_dwi',suffix='eddy.qc/qc.pdf',datatype='dwi',**config['subj_wildcards'])
    
    container: config['singularity']['prepdwi']
    group: 'dwi'
    shell: 
        'rmdir {output.out_dir} && '
        'eddy_quad {params.eddy_prefix} --eddyIdx={input.eddy_index_txt} --eddyParams={input.phenc_concat} '
        ' --mask={input.brainmask} --bvals={input.bvals} --bvecs={input.bvecs} --output-dir={output.out_dir} '
        '--slspec={input.eddy_slspec_txt} --verbose'
        #' --field={input.fieldmap} ' #this seems to break it..

rule split_eddy_qc_report:
    input:
        eddy_qc_pdf = bids(root='work/preproc_dwi',suffix='eddy.qc/qc.pdf',datatype='dwi',**config['subj_wildcards'])
    output:
        report(directory(bids(root='work/preproc_dwi',suffix='eddy.qc_pages',datatype='dwi',**config['subj_wildcards'])),patterns=['{pagenum}.png'],caption="../report/eddy_qc.rst", category="eddy_qc",subcategory=bids(**config['subj_wildcards'],include_subject_dir=False,include_session_dir=False))
    group: 'dwi'
    shell:
        'mkdir -p {output} && convert {input} {output}/%02d.png'
        


#with hippocampal FOV dwi, registration is more robust when dealing with subvolume
#so we register to cropped T1w here.. 
ruleorder: rigid_reg_with_init > get_shell_avg

rule rigid_reg_with_init:
    input:
        ref = bids(root='work/preproc_t1',**config['subj_wildcards'],desc='cropped', suffix='T1w.nii.gz',space='{template}corobl',hemi='{hemi}'),
        flo = bids(root='work/preproc_dwi',suffix='b0.nii.gz',desc='eddy',datatype='dwi',**config['subj_wildcards']),
        init_xfm = bids(root='work/preproc_t1',**config['subj_wildcards'],suffix='xfm.txt',from_='subject',to='{template}corobl',desc='affine',type_='itk'),
    params:
        out_prefix = bids(root='work/preproc_dwi',**config['subj_wildcards'],from_='dwi',to='{template}corobl',desc='affine',type_='itk',suffix='',hemi='{hemi}'),
        multires = '--convergence [40x20x10,1e-6,10]  --shrink-factors 8x4x2  --smoothing-sigmas 8x4x2vox'
    output:
        warped = bids(root='work/preproc_dwi',**config['subj_wildcards'],hemi='{hemi}',space='{template}corobl',suffix='b0.nii.gz',desc='cropped'),
        xfm = bids(root='work/preproc_dwi',**config['subj_wildcards'],from_='dwi',to='{template}corobl',desc='affine',type_='itk',suffix='0GenericAffine.mat',hemi='{hemi}'),
    container: config['singularity']['ants']
    threads: 8
    group: 'reg_dwi'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsRegistration -d 3 --interpolation Linear {params.multires} --metric CC[{input.ref},{input.flo},1,3] --transform Rigid[0.1] '
        ' --output [{params.out_prefix},{output.warped}] --initial-moving-transform [{input.init_xfm}]  -v '


rule warp_mean_dwi_corobl:
    input:
        nii = bids(root='work/preproc_dwi',suffix='{meandwi}.nii.gz',desc='eddy',datatype='dwi',**config['subj_wildcards']),
        xfm = bids(root='work/preproc_dwi',**config['subj_wildcards'],from_='dwi',to='{template}corobl',desc='affine',type_='itk',suffix='0GenericAffine.mat',hemi='{hemi}'),
        ref = lambda wildcards: config['template_files'][wildcards.template]['crop_ref']
    output: 
        nii = bids(root='work/preproc_dwi',suffix='{meandwi,b[0-9]+}.nii.gz',desc='cropped',datatype='dwi',**config['subj_wildcards'],space='{template}corobl',hemi='{hemi,L|R}'),
    container: config['singularity']['prepdwi']
    group: 'reg_dwi'
    shell:
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation Linear -i {input.nii} -o {output.nii} -r {input.ref}  -t {input.xfm}' 



rule lr_flip_dwi:
    input:
        nii = bids(root='work/preproc_dwi',suffix='{meandwi}.nii.gz',desc='cropped',datatype='dwi',**config['subj_wildcards'],space='{template}corobl',hemi='{hemi}'),
    output:
        nii = bids(root='work/preproc_dwi',suffix='{meandwi,b[0-9]+}.nii.gz',desc='cropped',datatype='dwi',**config['subj_wildcards'],space='{template}corobl',hemi='{hemi,L}flip'),
    container: config['singularity']['prepdwi']
    group: 'reg_dwi'
    shell:
        'c3d {input} -flip x -o  {output}'


