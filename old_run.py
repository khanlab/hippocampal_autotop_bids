#!/usr/bin/env python3
import os
import subprocess
import nibabel
import numpy
from bids import BIDSLayout
import bids
from glob import glob
from parse import get_parser


bids.config.set_option('extension_initial_dot', True)

def run(command, env={}):
    merged_env = os.environ
    merged_env.update(env)
    process = subprocess.Popen(command, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, shell=True,
                               env=merged_env)
    while True:
        line = process.stdout.readline()
        line = str(line, 'utf-8')[:-1]
        print(line)
        if line == '' and process.poll() != None:
            break
    if process.returncode != 0:
        raise Exception("Non zero return code: %d"%process.returncode)



#start of main

parser =  get_parser()
args = parser.parse_args()

#if not args.skip_bids_validator:
#    run('bids-validator %s'%args.bids_dir)

#default search term is by suffix
search_terms = {'suffix': args.suffix}

#add optional search terms
if args.acq is not None:
    search_terms['acquisition'] = args.acq
if args.run is not None:
    search_terms['run'] = args.run



#start by getting bids layout from pybids
layout = BIDSLayout(args.bids_dir,derivatives=False,validate=False,index_metadata=False)

subjects_to_analyze = []
# only for a subset of subjects
if args.participant_label:
    subjects_to_analyze = args.participant_label
# for all subjects
else:
    subject_dirs = glob(os.path.join(args.bids_dir, "sub-*"))
    subjects_to_analyze = [subject_dir.split("-")[-1] for subject_dir in subject_dirs]

#print(subjects_to_analyze)
#subjects_to_analyze = subjects_to_analyze.sort()
#print(subjects_to_analyze)

in_imgs=[]
out_dirs=[]

# running participant level
if args.analysis_level == "participant":

    for subject in sorted(subjects_to_analyze):

        t2w_list = layout.get(subject=subject,extension='nii.gz',**search_terms)
    
        if args.search and len(t2w_list)>0:
            t2w_list = [t2w for t2w in t2w_list if args.search in t2w.filename ]

        if len(t2w_list) == 0:
            print(f'WARNING: Unable to find any matching images for sub-{subject}!')
            continue
        elif len(t2w_list) >1:
            print(f'WARNING: Found multiple matching T2w files for sub-{subject}, please use search filters to narrow down to one')
            print(t2w_list)
            continue
        elif len(t2w_list) == 1:
            in_img = t2w_list[0].path
            entities = t2w_list[0].get_entities()

            if 'session' in entities.keys():
                session = entities['session']
                out_dir = os.path.join(args.output_dir,f'sub-{subject}/ses-{session}')
            else:
                out_dir = os.path.join(args.output_dir,f'sub-{subject}')
        
            in_imgs = in_imgs + [in_img] 
            out_dirs = out_dirs + [out_dir]

        print(f'Adding to run list, input: {in_img}, output: {out_dir}')
            
    for in_img, out_dir in zip(in_imgs,out_dirs):
        run_cmd = f'/src/mcr_v97/run_singleSubject.sh /opt/mcr/v97 {in_img} {out_dir}'
        print(f'Executing: {run_cmd}')
        run(run_cmd)

# running group level
elif args.analysis_level == "group":
    print('insert report generation here!')

