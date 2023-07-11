#!/opt/conda/bin/python

import os,sys
import flywheel
import re
import json
import subprocess as sp

# Grab Config
CONFIG_FILE_PATH = '/flywheel/v0/config.json'
with open(CONFIG_FILE_PATH) as config_file:
    config = json.load(config_file)

api_key = config['inputs']['api-key']['key']
analysis_id = config['destination']['id']

fw = flywheel.Client(api_key)
anal = fw.get_analysis(analysis_id)
session_id = anal.parent.id
session = fw.get_session(session_id)

# fmriprepfound = False

# xfm_files = []
for analysis in session.analyses:
    if 'fsl-preprocessing' in analysis.gear_info.name:
        print("Found FSL Preprocessing Analysis")
        for resultfile in analysis.files:
            if ("affpics" and ".nii.gz") in resultfile.name:
                print("Downloading affpics files")
                resultfile.download("input/%s" % resultfile)
            