#!/usr/bin/env python

import sys
from subprocess import call 

#command line options
if (len(sys.argv) < 2):
	print "\n\tusage: %s <subject>\n" % sys.argv[0]
	sys.exit()
else:
	subject = sys.argv[1]	

print("Preparing affective pictures output for MVPA analysis...")

FLYWHEEL_BASE="/flywheel/v0"
OUTPUT_DIR="%s/output" % FLYWHEEL_BASE
INPUT_DIR="%s/input" % FLYWHEEL_BASE


numcopes = 5

command = "fslmerge -t %s/%s_affectivepictures_allzstats " % (OUTPUT_DIR,subject)

for run in range(1,4):
	feat_dir = "%s/affectivepictures_run%d.feat" % (OUTPUT_DIR,run)
	for cope in range(1,numcopes+1):
		newcope = "%s/stats/zstat%d " % (feat_dir,cope)
		command = command + newcope

print(command)
call(command,shell=True)
