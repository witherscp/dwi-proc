#!/bin/bash

#====================================================================================================================

# Author:   	Price Withers
# Date:     	04/26/23

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h|--help] [-p|--postop] [-shift|--shift SHIFT_PARAM] SUBJ ++\033[0m"
	exit 1
}

# set defaults
postop=false; shift_param=false

# parse options
while [ -n "$1" ]; do
	# check case; if valid option found, toggle its respective variable on
    case "$1" in
    	-h|--help) 		display_usage ;;	# help
	    -p|--postop) 	postop=true ;; 		# post-op
		-shift|--shift)	shift_param=$2; shift ;; 	# manual shift/rotation parameters (obtained from AFNI's nudge plugin)
	    *) 				subj=$1; break ;; 	# subject code (prevent any further shifting by breaking)
    esac
    shift 	# shift to next argument
done

# check that exactly 1 parameter was given
if [ ! $# -eq 1 ]; then
	display_usage
fi

#---------------------------------------------------------------------------------------------------------------------

# VARIABLES

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     neu_dir="/shares/NEU";;
    Darwin*)    neu_dir="/Volumes/Shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be either Linux or Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

bids_root=$neu_dir/'Data'
bids_subj_dir=$bids_root/sub-${subj}

if [[ $postop == 'true' ]]; then
	ses_suffix='postop'
	folder_prefix='postop_'
else
	ses_suffix=''
	folder_prefix=''
fi

bids_clinical_dir=$bids_subj_dir/ses-clinical${ses_suffix}
bids_research_dir=$bids_subj_dir/ses-research${ses_suffix}
bids_research_anat_dir=$bids_research_dir/anat
bids_dwi_dir=$bids_research_dir/dwi

subj_dwi_dir=$neu_dir/Projects/DWI/$subj
reg_dir=$subj_dwi_dir/${folder_prefix}reg
# make_ reg dir
if [[ ! -d "${reg_dir}" ]]; then 
	mkdir -p "${reg_dir}"
fi

if [[ ${shift_param} == 'false' ]]; then
	wdir=$reg_dir/__WORK_T2toT1
else
	wdir=$reg_dir/__WORK_T2toT1_MANUAL_SHIFT
fi

dwi_proc_dir=$(pwd)
scripts_dir=${dwi_proc_dir}/scripts
#---------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source "${scripts_dir}"/all_req_check.sh -afni -conda

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

# check for existence of dwi dir
if [[ ! -d "${bids_dwi_dir}" ]]; then
	echo -e "\033[0;35m++ Subject ${subj} does not have ses-research${ses_suffix}/dwi. Please run bids_proc.sh. Exiting... ++\033[0m"
	exit 1
fi

# check for existence of clinical dir
if [[ ! -d "${bids_clinical_dir}" ]]; then
	bids_clinical_dir=$bids_subj_dir/ses-altclinical${ses_suffix}
	if [[ ! -d "${bids_clinical_dir}" ]]; then
		echo -e "\033[0;35m++ Subject ${subj} does not have ses-clinical${ses_suffix} or ses-altclinical${ses_suffix}. Please run bids_proc.sh. Exiting... ++\033[0m"
		exit 1
	else
		touch "${reg_dir}"/ALTCLINICAL_T1_USED
		ses_prefix='alt'
	fi
else
	ses_prefix=''
	touch "${reg_dir}"/CLINICAL_T1_USED
fi
bids_clinical_anat_dir=$bids_clinical_dir/anat

# check for existence of t2 file
t2_file=$bids_research_anat_dir/sub-${subj}_ses-research${ses_suffix}_acq-fatsat_rec-axialized_T2w.nii.gz
if [[ ! -f $t2_file ]]; then
	echo -e "\033[1;33m++ Subject ${subj} does not have research T2. Using clinical T2 instead. ++\033[0m"
	touch "${reg_dir}"/CLINICAL_T2_USED
	t2_file=$bids_clinical_anat_dir/sub-${subj}_ses-${ses_prefix}clinical${ses_suffix}_rec-axialized_T2w.nii.gz
else
	touch "${reg_dir}"/RESEARCH_T2_USED
fi

echo -e "\033[0;35m++ Working on subject ${subj}... ++\033[0m"

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** align (axialize) T2 to T1 *****

# move T1 to reg dir
if [[ ! -f "$reg_dir"/t1.nii ]]; then
	3dcalc 	\
		-a "$bids_clinical_anat_dir"/sub-"${subj}"_ses-${ses_prefix}clinical${ses_suffix}_rec-axialized_T1w.nii.gz 		\
		-prefix "$reg_dir"/t1.nii 	\
		-datum short 					\
		-expr 'a'
fi

# move T2 to reg dir
if [[ ! -f ${reg_dir}/t2_ORIG.nii ]]; then
	3dcopy "$t2_file" "${reg_dir}"/t2_ORIG.nii
fi

# delete working directory if it already exists (allow for rerunning of script if necessary)
if [[ -d "$wdir" ]]; then 
	rm -r "$wdir"
fi

# register T2 to T1
if [[ ${shift_param} == 'false' ]]; then
	(cd "${reg_dir}" || exit; tcsh ${scripts_dir}/do_01_t1w_align_t2w.tcsh "${reg_dir}"/{t2_ORIG,t1}.nii)
else
	# MANUAL SHIFT
	echo -e "\033[0;35m++ Applying MANUAL SHIFT to T2 ++\033[0m"
	(source activate p2.7; cd "${reg_dir}" || exit; tcsh ${scripts_dir}/do_01_t1w_align_t2w_MANUAL_SHIFT.tcsh "${reg_dir}"/{t2_ORIG,t1}.nii "${shift_param}"; conda deactivate)
fi

# ***** resample axialized T2 to RPI orientation *****

3dresample								\
	-orient RPI 						\
	-prefix "${reg_dir}"/t2.nii 		\
	-inset "${wdir}"/t2w_02_FINAL.nii 	\
	-overwrite

#====================================================================================================================

echo -e "\033[0;32m++ Done! Please check outputs in ${reg_dir} ++\033[0m"
