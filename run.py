#!/usr/bin/env python3
import os

from snakebids.app import SnakeBidsApp

pwd = os.path.abspath(os.path.dirname(__file__))
app = SnakeBidsApp(snakebids_config=os.path.join(pwd,'config','snakebids.yml'),
                    snakefile=os.path.join(pwd,'workflow','Snakefile'))
app.run_snakemake()

