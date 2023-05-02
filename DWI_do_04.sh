#!/bin/bash

#===================================================================================================================

# Name: 		DTI_do_04.sh

# Author:   	Katie Snyder
# Date:     	05/01/19

# Syntax:       ./DTI_do_04.sh [-h|--help] [-p|--postop] [-m|--mask MASK] SUBJ

# Arguments:    SUBJ: 		subject ID
# 				-p:   		work on post-op data
# 				-m MASK: 	path to brain mask to use in tensor estimation
# Description:  Estimates DT parameters and calculates DEC map
# Requirements: 1) AFNI
# 				2) python 2.7 conda environment
# Notes:		- DTI_do_TORTOISE_biowulf_{push|pull}.sh must be run prior to running this script

#===================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h|--help] [-p|--postop] [-m|--mask MASK] SUBJ ++\033[0m"
	exit 1
}

# set defaults
postop=false; mask=false

# parse options
while [ -n "$1" ]; do
    case "$1" in
    	-h|--help)		display_usage ;;	# help
	    -p|--postop) 	postop=true ;; 		# post-op
		-m|--mask)		mask=$2; shift ;;	# user-specified brain mask
	    *) 	subj=$1; break ;; 	# subject code (prevent any further shifting by breaking)
    esac
    shift 	# shift to next argument
done

if [[ $postop == 'true' ]]; then
	folder_suffix='_postop'
else
	folder_suffix=''
fi

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

subj_dwi_dir=$neu_dir/Projects/DWI/$subj
dwi_drbuddi_dir=${subj_dwi_dir}/drbuddi${folder_suffix}
dwi_reg_dir=${subj_dwi_dir}/reg${folder_suffix}
dwi_dtparam_dir=${subj_dwi_dir}/DTparams${folder_suffix}

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source ${neu_dir}/Scripts_and_Parameters/scripts/all_req_check -afni -conda

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

# check for existence of DRBUDDI outputs in buddi dir
if [ ! -f "${dwi_drbuddi_dir}/buddi.nii" ]; then
	echo -e "\033[0;35m++ TORTOISE has not been run on subject ${subj}. Please run DWI_do_03_{push|pull}.sh. Exiting... ++\033[0m"
	exit 1
fi

# check that brain mask is viable .nii mask file
if [[ ${mask} != "false" ]]; then
	if [[ ! $(3dBrickStat ${mask}) -eq "1" ]]; then
		echo -e "\033[0;35m++ ${mask} is not a valid NIfTI binary mask. Exiting... ++\033[0m"
		exit 1
	fi
fi

echo -e "\033[0;35m++ Working on subject ${subj}... ++\033[0m"
source activate p2.7

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 0: set up DTparams and DECmap directories

decmap_dir=${dwi_dtparam_dir}/DECmap
if [ ! -d "${decmap_dir}" ]; then
	mkdir -p "${decmap_dir}"
fi

#====================================================================================================================

# STEP 1: run Gradient Flip Test

if [ -f "${dwi_drbuddi_dir}/GradFlipTest_rec.txt" ]; then
	echo -e "\033[0;36m++ Gradient flip already determined for subject ${subj}. Continuing... ++\033[0m"
else
	echo -e "\033[0;35m++ Applying the gradient flip test for subject ${subj} ++\033[0m"

	@GradFlipTest 										\
		-in_dwi 	 "${dwi_drbuddi_dir}"/buddi.nii 			\
		-in_col_matT "${dwi_drbuddi_dir}"/buddi.bmtxt 			\
		-prefix 	 "${dwi_drbuddi_dir}"/GradFlipTest_rec.txt
fi

#====================================================================================================================

# STEP 2: estimate DT parameters

if [ -f "${dwi_dtparam_dir}/dwi_mask.nii.gz" ]; then
	echo -e "\033[0;36m++ DT parameters already estimated for subject ${subj}. Continuing... ++\033[0m"
else
	echo -e "\033[0;35m++ Estimating diffusion tensors for subject ${subj} ++\033[0m"
	my_flip=$(cat ${dwi_drbuddi_dir}/GradFlipTest_rec.txt)

	if [[ ${mask} == "false" ]]; then
		fat_proc_dwi_to_dt 									\
			-in_dwi 		${dwi_drbuddi_dir}/buddi.nii			\
			-in_col_matT 	${dwi_drbuddi_dir}/buddi.bmtxt 		\
			-in_struc_res 	${dwi_drbuddi_dir}/structural.nii 	\
			-in_ref_orig 	${dwi_reg_dir}/t2.nii 			\
			-prefix 		${dwi_dtparam_dir}/dwi 				\
			-mask_from_struc 								\
			-no_qc_view 									\
			${my_flip}
	else
		# resample grid of user's brain mask to match that of buddi.nii
		3dresample 									\
			-master ${dwi_drbuddi_dir}/buddi.nii 			\
			-input 	${mask}							\
			-prefix ${dwi_dtparam_dir}/dwi_mask_NEW.nii 	\

		fat_proc_dwi_to_dt 									\
			-in_dwi 		${dwi_drbuddi_dir}/buddi.nii			\
			-in_col_matT 	${dwi_drbuddi_dir}/buddi.bmtxt 		\
			-in_struc_res 	${dwi_drbuddi_dir}/structural.nii 	\
			-in_ref_orig 	${dwi_reg_dir}/t2.nii 			\
			-prefix 		${dwi_dtparam_dir}/dwi 				\
			-mask 			${dwi_dtparam_dir}/dwi_mask_NEW.nii 	\
			-no_qc_view 									\
			${my_flip}
	fi
fi

#====================================================================================================================

# STEP 3: generate DEC map

if [ -f "${decmap_dir}/DEC_dec.nii.gz" ]; then 
	echo -e "\033[0;36m++ DEC map already exists for subject ${subj}. Continuing... ++\033[0m"
else
	echo -e "\033[0;35m++ Generating DEC map for subject ${subj} ++\033[0m"
	fat_proc_decmap 								\
		-in_fa 		${dwi_dtparam_dir}/dt_FA.nii.gz 		\
		-in_v1 		${dwi_dtparam_dir}/dt_V1.nii.gz 		\
		-mask 		${dwi_dtparam_dir}/dwi_mask.nii.gz 	\
		-no_qc_view 								\
		-prefix 	${decmap_dir}/DEC
fi

#====================================================================================================================

# ***** STEP 4: erode whole brain mask *****

if [ -a "${dwi_dtparam_dir}/dwi_mask_e2.nii.gz" ]; then
	echo -e "\033[0;36m++ DWI mask already eroded. ++\033[0m"
else
	echo -e "\033[0;35m++ Generating eroded DWI mask for subject ${subj} ++\033[0m"

	3dmask_tool \
		-dilate_inputs -2 \
		-inputs ${dwi_dtparam_dir}/dwi_mask.nii.gz \
		-prefix ${dwi_dtparam_dir}/dwi_mask_e2.nii.gz
fi

#====================================================================================================================

conda deactivate

echo -e "\033[0;32m++ Done! Please check outputs in ${dwi_dtparam_dir} ++\033[0m"
