#! /bin/bash
#
#
#making a change

###############################################################################
# Built to flywheel-v0 spec.

CONTAINER=affint-feat
echo -e "$CONTAINER  Initiated"

FLYWHEEL_BASE=/flywheel/v0
OUTPUT_DIR=$FLYWHEEL_BASE/output
INPUT_DIR=$FLYWHEEL_BASE/input/
MANIFEST=$FLYWHEEL_BASE/manifest.json
CONFIG_FILE=$FLYWHEEL_BASE/config.json

mkdir ${INPUT_DIR}

#Colors
RED='\033[0;31m'
NC='\033[0m'

###############################################################################
# Configure the ENV

export FSLDIR=/usr/local/fsl
source $FSLDIR/etc/fslconf/fsl.sh
export USER=Flywheel
source ~/.bashrc


##############################################################################
# Parse configuration

function parse_config {

  CONFIG_FILE=$FLYWHEEL_BASE/config.json
  MANIFEST_FILE=$FLYWHEEL_BASE/manifest.json

#   if [[ -f $CONFIG_FILE ]]; then
#     echo "$(cat $CONFIG_FILE | jq -r '.config.'$1)"
#   else
#     CONFIG_FILE=$MANIFEST_FILE
#     echo "$(cat $MANIFEST_FILE | jq -r '.config.'$1'.default')"
#   fi
# }


###############################################################################
# Gather input files

#run script to get input files
${FLYWHEEL_BASE}/get_files.py

#echo Lets look inside $INPUT_DIR
ls $INPUT_DIR

echo "LISTING FILES IN FLYWHEEL_BASE:"
ls ${FLYWHEEL_BASE}
echo ""
echo ""

###############################################################################
# Determine Subject ID

subfolder=`find $INPUT_DIR/*affpics1_cleaned* -maxdepth 0 | head -1`
echo "Testing length of $subfolder: ${#subfolder}"
if [[ ${#subfolder} > 37 ]]
then
  echo "3digit subject number detected"
  subject=${subfolder: 0:5}
else
  echo "2digit subject number detected"
  subject=${subfolder: 0:4}
fi

echo "Subject is $subject"




####################################################################
# AFFECTIVEPICTURES ANALYSIS
####################################################################

TEMPLATE=affectivepictures_template.fsf

for RUN in {1..1}
do
	echo -e "\n\n${CONTAINER} Beginning analysis for affective pictures run ${RUN}"

	INPUT_DATA=${INPUT_DIR}/${subject}_affpics${RUN}_cleaned_standard.nii.gz
	FEAT_OUTPUT_DIR=${OUTPUT_DIR}/${subject}_affectivepictures_run${RUN}.feat 
	NEUTRAL_EV=${DATA_DIR}/logs/${subject}_affectivepictures_run${RUN}_Neutral_all.txt
	FEAR_EV=${DATA_DIR}/logs/${subject}_affectivepictures_run${RUN}_Fear_all.txt
	HAPPY_EV=${DATA_DIR}/logs/${subject}_affectivepictures_run${RUN}_Happy_all.txt
	SAD_EV=${DATA_DIR}/logs/${subject}_affectivepictures_run${RUN}_Sad_all.txt
	DISGUST_EV=${DATA_DIR}/logs/${subject}_affectivepictures_run${RUN}_Disgust_all.txt

	
	TEMPLATE=$FLYWHEEL_BASE/affectivepictures_template.fsf
	DESIGN_FILE=${OUTPUT_DIR}/affectivepictures_run${RUN}.fsf
	cp ${TEMPLATE} ${DESIGN_FILE}

  #Check number of timepoints in data
  NUMTIMEPOINTS=`fslinfo ${INPUT_DATA} | grep ^dim4 | awk {'print $2'}`
  
  #Should be 120 for these runs
  if [ $NUMTIMEPOINTS -eq 186 ]; then
    echo "Number of timepoints is correct at ${NUMTIMEPOINTS}"
  else
    echo -e "${RED}WARNING!!! Number of timepoints should be 186 but is ${NUMTIMEPOINTS} ${NC}"
  fi

  VAR_STRINGS=( INPUT_DATA FEAT_OUTPUT_DIR NEUTRAL_EV FEAR_EV HAPPY_EV SAD_EV DISGUST_EV NUMTIMEPOINTS)


	# loop through and preform substitution
	for var_name in ${VAR_STRINGS[@]}; do

	  var_val=` eval 'echo $'$var_name `

	  echo will substitute $var_val for $var_name in design file
	  #We need to replace and backslashes with "\/"
	  var_val=` echo ${var_val////"\/"} `

	  sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}
	  echo sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}

	done
	
	# RUN THE Algorithm with the .FSF FILE
	ls $INPUT_DATA

	echo Starting FEAT for Affective Pictures run ${RUN}...
	time feat ${DESIGN_FILE}
	FEAT_EXIT_STATUS=$?

	if [[ $FEAT_EXIT_STATUS == 0 ]]; then
	  echo -e "FEAT completed successfully!"
	fi

	echo What have we got now
	ls ${OUTPUT_DIR}

  #add a fake reg folder
  ${FLYWHEEL_BASE}/make_reg_folder.py ${FEAT_OUTPUT_DIR}

	# Upon success, convert index to a webpage
	if [[ $FEAT_EXIT_STATUS == 0 ]]; then
	  # Convert index to standalone index
	  echo "$CONTAINER  generating output html..."
	  output_html_files=$(find ${FEAT_OUTPUT_DIR} -type f -name "report_poststats.html")
	  for f in $output_html_files; do
	    web2htmloutput=${OUTPUT_DIR}/${subject}_affpics_run${RUN}_`basename $f`
	    python /opt/webpage2html/webpage2html.py -q -s "$f" > "$web2htmloutput"
	  done
	fi



done

####################################################################
# AFFECTIVEPICTURES PREPARE FOR MVPA
####################################################################


#RUN THE CONCATENATION SCRIPT
${FLYWHEEL_BASE}/mvpa_prepare.py ${subject}

#NOW WE CAN ZIP THE FEAT FOLDERS
# CLEANUP THE OUTPUT DIRECTORIES

for RUN in {1..3}
do
  FEAT_OUTPUT_DIR=${OUTPUT_DIR}/affectivepictures_run${RUN}.feat 
  echo feat directory is ${FEAT_OUTPUT_DIR}

  if [[ $FEAT_EXIT_STATUS == 0 ]]; then

    echo -e "${CONTAINER}  Compressing outputs..."

    # Zip and move the relevant files to the output directory
    zip -rq ${OUTPUT_DIR}/${subject}_affectivepictures_run${RUN}.zip ${FEAT_OUTPUT_DIR}
    rm -rf ${FEAT_OUTPUT_DIR}
    
  fi
done
echo Lets see what we have after zipping etc
ls ${OUTPUT_DIR}

####################################################################
#EMOREG ANALYSIS
####################################################################

TEMPLATE=emoreg_template.fsf
echo -e "\n\n${CONTAINER} Beginning analysis for emoreg task"

INPUT_DATA=${INPUT_DIR}/${subject}_emoreg_cleaned_standard.nii.gz
FEAT_OUTPUT_DIR=${OUTPUT_DIR}/${subject}_emoreg.feat 
NEUTRAL_EV=${DATA_DIR}/logs/${subject}_emotionregulation_run1_neutral_all.txt
NEGATIVE_EV=${DATA_DIR}/logs/${subject}_emotionregulation_run1_negative_all.txt
REAPPRAISE_EV=${DATA_DIR}/logs/${subject}_emotionregulation_run1_Rnegative_all.txt

#Check number of timepoints in data
NUMTIMEPOINTS=`fslinfo ${INPUT_DATA} | grep ^dim4 | awk {'print $2'}`

#Should be 120 for these runs
if [ $NUMTIMEPOINTS -eq 285 ]; then
  echo "Number of timepoints is correct at ${NUMTIMEPOINTS}"
else
  echo -e "${RED}WARNING!!! Number of timepoints should be 285 but is ${NUMTIMEPOINTS} ${NC}"
fi

VAR_STRINGS=( INPUT_DATA FEAT_OUTPUT_DIR NEUTRAL_EV NEGATIVE_EV REAPPRAISE_EV NUMTIMEPOINTS)

DESIGN_FILE=${OUTPUT_DIR}/emoreg.fsf

cp ${TEMPLATE} ${DESIGN_FILE}

# loop through and preform substitution
for var_name in ${VAR_STRINGS[@]}; do

  var_val=` eval 'echo $'$var_name `

  echo will substitute $var_val for $var_name in design file
  #We need to replace and backslashes with "\/"
  var_val=` echo ${var_val////"\/"} `

  sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}
  echo sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}

done

# RUN THE Algorithm with the .FSF FILE
ls $INPUT_DATA

# cat $DESIGN_FILE

echo Starting FEAT for emoreg...
time feat ${DESIGN_FILE}
FEAT_EXIT_STATUS=$?

if [[ $FEAT_EXIT_STATUS == 0 ]]; then
  echo -e "FEAT completed successfully!"
fi

echo What have we got now
ls ${OUTPUT_DIR}

#add a fake reg folder
${FLYWHEEL_BASE}/make_reg_folder.py ${FEAT_OUTPUT_DIR}

# Upon success, convert index to a webpage
if [[ $FEAT_EXIT_STATUS == 0 ]]; then
  # Convert index to standalone index
  echo "$CONTAINER  generating output html..."
  output_html_files=$(find ${FEAT_OUTPUT_DIR} -type f -name "report_poststats.html")
  for f in $output_html_files; do
    web2htmloutput=${OUTPUT_DIR}/${subject}_emoreg_`basename $f`
    python /opt/webpage2html/webpage2html.py -q -s "$f" > "$web2htmloutput"
  done
fi

# CLEANUP THE OUTPUT DIRECTORIES
echo feat directory is ${FEAT_OUTPUT_DIR}

if [[ $FEAT_EXIT_STATUS == 0 ]]; then

  echo -e "${CONTAINER}  Compressing outputs..."

  # Zip and move the relevant files to the output directory
  echo zip -rq ${OUTPUT_DIR}/${subject}_emoreg.zip ${FEAT_OUTPUT_DIR}
  zip -rq ${OUTPUT_DIR}/${subject}_emoreg.zip ${FEAT_OUTPUT_DIR}
  rm -rf ${FEAT_OUTPUT_DIR}
  
fi

echo Lets see what we have after zipping etc
ls ${OUTPUT_DIR}


####################################################################
# FACEEMOTION ANALYSIS
####################################################################

TEMPLATE=faces_template.fsf
echo -e "\n\n${CONTAINER} Beginning analysis for faceemotion task"

INPUT_DATA=${INPUT_DIR}/${subject}_faceemotion_cleaned_standard.nii.gz
FEAT_OUTPUT_DIR=${OUTPUT_DIR}/${subject}_faceemotion.feat

INSTRUCTIONS_EV=${DATA_DIR}/logs/${subject}-faceemotion-run1-faces-instructions.txt
NAMING_EV=${DATA_DIR}/logs/${subject}-run1-faces-naming.txt
INTENSITY_EV=${DATA_DIR}/logs/${subject}-run1-faces-intensity.txt

#Check number of timepoints in data
NUMTIMEPOINTS=`fslinfo ${INPUT_DATA} | grep ^dim4 | awk {'print $2'}`

#Should be 120 for these runs
if [ $NUMTIMEPOINTS -eq 120 ]; then
  echo "Number of timepoints is correct at ${NUMTIMEPOINTS}"
else
  echo -e "${RED} WARNING!!! Number of timepoints should be 120 but is ${NUMTIMEPOINTS} ${NC}"
fi


VAR_STRINGS=( INPUT_DATA FEAT_OUTPUT_DIR INSTRUCTIONS_EV NAMING_EV INTENSITY_EV NUMTIMEPOINTS)

DESIGN_FILE=${OUTPUT_DIR}/faceemotion.fsf

cp ${TEMPLATE} ${DESIGN_FILE}

# loop through and preform substitution
for var_name in ${VAR_STRINGS[@]}; do

  var_val=` eval 'echo $'$var_name `

  echo will substitute $var_val for $var_name in design file
  #We need to replace and backslashes with "\/"
  var_val=` echo ${var_val////"\/"} `

  sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}
  echo sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}

done

# RUN THE Algorithm with the .FSF FILE
ls $INPUT_DATA

# cat $DESIGN_FILE

echo Starting FEAT for faceemotion...
time feat ${DESIGN_FILE}
FEAT_EXIT_STATUS=$?

if [[ $FEAT_EXIT_STATUS == 0 ]]; then
  echo -e "FEAT completed successfully!"
fi

echo What have we got now
ls ${OUTPUT_DIR}

#add a fake reg folder
${FLYWHEEL_BASE}/make_reg_folder.py ${FEAT_OUTPUT_DIR}

# Upon success, convert index to a webpage
if [[ $FEAT_EXIT_STATUS == 0 ]]; then
  # Convert index to standalone index
  echo "$CONTAINER  generating output html..."
  output_html_files=$(find ${FEAT_OUTPUT_DIR} -type f -name "report_poststats.html")
  for f in $output_html_files; do
    web2htmloutput=${OUTPUT_DIR}/${subject}_faceemotion_`basename $f`
    python /opt/webpage2html/webpage2html.py -q -s "$f" > "$web2htmloutput"
  done
fi

# CLEANUP THE OUTPUT DIRECTORIES
echo feat directory is ${FEAT_OUTPUT_DIR}

if [[ $FEAT_EXIT_STATUS == 0 ]]; then

  echo -e "${CONTAINER}  Compressing outputs..."

  # Zip and move the relevant files to the output directory
  zip -rq ${OUTPUT_DIR}/${subject}_faceemotion.zip ${FEAT_OUTPUT_DIR}
  rm -rf ${FEAT_OUTPUT_DIR}
  
fi

echo Lets see what we have after zipping etc
ls ${OUTPUT_DIR}

####################################################################
# THEORYOFMIND ANALYSIS
####################################################################

TEMPLATE=tom_template.fsf
echo -e "\n\n${CONTAINER} Beginning analysis for tom task"

INPUT_DATA=${INPUT_DIR}/${subject}_tom_cleaned_standard.nii.gz
FEAT_OUTPUT_DIR=${OUTPUT_DIR}/${subject}_tom.feat

PHYS_EV=${DATA_DIR}/logs/${subject}_tom_run1_physical_all.txt
COG_EV=${DATA_DIR}/logs/${subject}_tom_run1_cognitive_tom_all.txt
AFFECT_EV=${DATA_DIR}/logs/${subject}_tom_run1_affective_tom_all.txt

#Check number of timepoints in data
NUMTIMEPOINTS=`fslinfo ${INPUT_DATA} | grep ^dim4 | awk {'print $2'}`

#Should be 120 for these runs
if [ $NUMTIMEPOINTS -eq 234 ]; then
  echo "Number of timepoints is correct at ${NUMTIMEPOINTS}"
else
  echo -e "${RED}WARNING!!! Number of timepoints should be 234 but is ${NUMTIMEPOINTS} ${NC}"
fi

VAR_STRINGS=( INPUT_DATA FEAT_OUTPUT_DIR PHYS_EV COG_EV AFFECT_EV NUMTIMEPOINTS)

DESIGN_FILE=${OUTPUT_DIR}/tom.fsf

cp ${TEMPLATE} ${DESIGN_FILE}

# loop through and preform substitution
for var_name in ${VAR_STRINGS[@]}; do

  var_val=` eval 'echo $'$var_name `

  echo will substitute $var_val for $var_name in design file
  #We need to replace and backslashes with "\/"
  var_val=` echo ${var_val////"\/"} `

  sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}
  echo sed -i -e "s/\^${var_name}\^/${var_val}/g" ${DESIGN_FILE}

done

# RUN THE Algorithm with the .FSF FILE
ls $INPUT_DATA

# cat $DESIGN_FILE

echo Starting FEAT for theory of mind...
time feat ${DESIGN_FILE}
FEAT_EXIT_STATUS=$?

if [[ $FEAT_EXIT_STATUS == 0 ]]; then
  echo -e "FEAT completed successfully!"
fi

echo What have we got now
ls ${OUTPUT_DIR}

#add a fake reg folder
${FLYWHEEL_BASE}/make_reg_folder.py ${FEAT_OUTPUT_DIR}

# Upon success, convert index to a webpage
if [[ $FEAT_EXIT_STATUS == 0 ]]; then
  # Convert index to standalone index
  echo "$CONTAINER  generating output html..."
  output_html_files=$(find ${FEAT_OUTPUT_DIR} -type f -name "report_poststats.html")
  for f in $output_html_files; do
    web2htmloutput=${OUTPUT_DIR}/${subject}_tom_`basename $f`
    python /opt/webpage2html/webpage2html.py -q -s "$f" > "$web2htmloutput"
  done
fi

# CLEANUP THE OUTPUT DIRECTORIES
echo feat directory is ${FEAT_OUTPUT_DIR}

if [[ $FEAT_EXIT_STATUS == 0 ]]; then

  echo -e "${CONTAINER}  Compressing outputs..."

  # Zip and move the relevant files to the output directory
  zip -rq ${OUTPUT_DIR}/${subject}_tom.zip ${FEAT_OUTPUT_DIR}
  rm -rf ${FEAT_OUTPUT_DIR}
  
fi

echo Lets see what we have after zipping etc
ls ${OUTPUT_DIR}

###############################################################################
# EXIT
###############################################################################

if [[ $FEAT_EXIT_STATUS == 0 ]]; then
  echo -e "$CONTAINER  Done!"
  exit 0
else
  echo "$CONTAINER  Error while running FEAT... Exiting($FEAT_EXIT_STATUS)"
  exit $FEAT_EXIT_STATUS
fi
