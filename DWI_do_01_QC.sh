#!/bin/bash

#====================================================================================================================

# Name: 		DWI_do_01_QC.sh

# Author:   	Price Withers
# Date:     	04/26/23

# Syntax:       ./DWI_01_QC.sh [-h|--help] [-p|--postop] SUBJ

# Arguments:    SUBJ: subject ID
# Description:  QC check of T1-T2 registration

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h|--help] [-p|--postop] SUBJ ++\033[0m"
	exit 1
}

# set defaults
postop=false

# parse options
while [ -n "$1" ]; do
    case "$1" in
    	-h|--help)		display_usage ;;	# help
	    -p|--postop) 	postop=true ;; 		# post-op
	    *) 				subj=$1; break ;; 	# subject code (prevent any further shifting by breaking)
    esac
    shift 	# shift to next argument
done

# check that only one parameter was given (subj)
if [ ! $# -eq 1 ]; then
	display_usage
fi

#--------------------------------------------------------------------------------------------------------------------

# VARIABLES AND PATHS

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     neu_dir="/shares/NEU";;
    Darwin*)    neu_dir="/Volumes/Shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be either Linux or Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

if [[ $postop == 'true' ]]; then
	reg_suffix='_postop'
else
	reg_suffix=''
fi

dwi_dir=$neu_dir/Projects/DTI/$subj
dwi_reg_dir=$dwi_dir/reg${reg_suffix}
dwi_proc_dir=$(pwd)
scripts_dir=${dwi_proc_dir}/scripts

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source ${neu_dir}/Scripts_and_Parameters/scripts/all_req_check -afni -x11

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

# check that registered T2 exists in reg dir
if [[ ! -f ${dwi_reg_dir}/t2.nii ]]; then
	echo -e "\033[0;36m++ Subject ${subj} does not have registered T2 in DTI reg dir. Please run DTI_do_01.sh. Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: perform quality check
cd "$dwi_reg_dir" || exit
afni \
	-com 'SWITCH_UNDERLAY t1.nii'	\
	-com 'SWITCH_OVERLAY t2.nii'
sleep 5
echo -e "\033[0;35m++ Are registrations correct? Enter y if correct; anything else if not ++\033[0m"
read -r ynresponse
ynresponse=$(echo "$ynresponse" | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" != "y" ]; then
	echo -e "\033[0;35m++ Registration not correct. Run second registration? Enter y to run second registration; anything else if not ++\033[0m"
	read -r ynresponse2
	ynresponse2=$(echo "$ynresponse2" | tr '[:upper:]' '[:lower:]')

	if [ "$ynresponse2" == "y" ]; then
		if [ -f "${dwi_reg_dir}/fixReg.sh" ]; then
			echo -e "\033[0;35m++ Second registration script already ran. Please manually correct registration (see proc notes). Exiting... ++\033[0m"
		else
			echo -e "\033[0;35m++ Running second registration script and exiting... ++\033[0m"
			(cd "${dwi_reg_dir}" || exit; cp "${scripts_dir}"/fixReg_01.sh "${dwi_reg_dir}"/fixReg.sh; bash fixReg.sh)
		fi
		exit 1
	else
		echo -e "\033[0;35m++ Second registration cancelled. Exiting... ++\033[0m"
		exit 1
	fi
fi

#====================================================================================================================

echo -e "\033[0;32m++ Awesome possum! Please move further on the processing pipeline for ${subj} (DTI_do_02.sh) ++\033[0m"
