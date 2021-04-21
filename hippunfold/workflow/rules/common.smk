#take mean of all scans if >1, otherwise just copy the one scan
def get_avg_or_cp_scans_cmd (wildcards, input, output):
    if len(input) > 1:
        cmd = f'c3d {input} -mean -o {output}'
    else:
        cmd = f'cp {input} {output}'
    return cmd


rule copy_to_results:
    """ Generic rule for copying data from work to results"""
    input: 'work/{file}'
    output: 'results/{file}'
    group: 'subj'
    shell: 'cp {input} {output}'
