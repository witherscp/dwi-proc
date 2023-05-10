#!/bin/bash

#====================================================================================================================

# Author:   	Price Withers, Kayla Togneri
# Date:     	04/27/23

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
    Darwin*)    neu_dir="/Volumes/Shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

if [[ $postop == 'true' ]]; then
	folder_prefix='postop_'
	ses_suffix='postop'
else
	folder_prefix=''
	ses_suffix=''
fi

subj_dwi_dir=$neu_dir/Projects/DWI/$subj
reg_dir=$subj_dwi_dir/${folder_prefix}reg
sel_dir=$subj_dwi_dir/${folder_prefix}sel

bids_root=$neu_dir/'Data'
bids_subj_dir=$bids_root/sub-${subj}
bids_research_dir=$bids_subj_dir/ses-research${ses_suffix}
bids_dwi_dir=$bids_research_dir/dwi

dwi_proc_dir=$(pwd)
scripts_dir=${dwi_proc_dir}/scripts

#---------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source "${scripts_dir}"/all_req_check.sh -afni -x11

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

# check that registered T2 exists in reg dir
if [[ ! -f ${reg_dir}/t2.nii ]]; then
	echo -e "\033[0;36m++ Subject ${subj} does not have registered T2 in DWI reg dir. Please run DWI_do_01.sh. Exiting... ++\033[0m"
	exit 1
fi

if [[ -f ${bids_dwi_dir}/sub-${subj}_ses-research${ses_suffix}_acq-Siemens_dir-down_dwi.nii.gz ]]; then
	acq='Siemens'
elif [[ -f ${bids_dwi_dir}/sub-${subj}_ses-research${ses_suffix}_acq-GE_dir-down_dwi.nii.gz ]]; then
	acq='GE'
else
	echo -e "\033[0;36m++ Subject ${subj} does not have DWI data. Please run bids_proc.sh, then DWI_do_01.sh. Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# make sel_dir
if [[ ! -d $sel_dir ]]; then
	mkdir "$sel_dir"
fi

# iterate through phase directions
for dir in down up; do

	dwi_file=sub-${subj}_ses-research${ses_suffix}_acq-${acq}_dir-${dir}_dwi.nii.gz

	# make 4D images for QC
	if [[ ! -f "${sel_dir}"/qc_images/dwi_${dir}_qc_sepscl.sag.png ]]; then
		@djunct_4d_imager \
			-inset "${bids_dwi_dir}"/"$dwi_file" \
			-prefix "${sel_dir}"/qc_images/dwi_${dir}
	fi

	# select out bad slices
	if [[ ! -f "${sel_dir}"/dwi_goods.txt ]]; then
		if [[ $dir == 'down' ]]; then
			fat_proc_select_vols \
				-in_dwi "${bids_dwi_dir}"/"$dwi_file" \
				-in_img "${sel_dir}"/qc_images/dwi_${dir}_qc_sepscl.sag.png \
				-prefix "${sel_dir}"/dwi_${dir}	\
				-no_cmd_out

			rm -f "${sel_dir}"/dwi_${dir}_goods.txt
			rm -rf "${sel_dir}"/QC
		else
			fat_proc_select_vols \
				-in_dwi "${bids_dwi_dir}"/"$dwi_file" \
				-in_img "${sel_dir}"/qc_images/dwi_${dir}_qc_sepscl.sag.png \
				-in_bads "${sel_dir}"/dwi_down_bads.txt	\
				-prefix "${sel_dir}"/dwi	\
				-no_cmd_out

			rm -f "${sel_dir}"/dwi_down_bads.txt
			rm -rf "${sel_dir}"/QC
		fi
	fi

done


for dir in down up; do

	dwi_file=sub-${subj}_ses-research${ses_suffix}_acq-${acq}_dir-${dir}_dwi.nii.gz

	fat_proc_filter_dwis \
		-in_dwi "${bids_dwi_dir}"/"$dwi_file"	\
		-select_file "${sel_dir}"/dwi_goods.txt	\
		-prefix "${sel_dir}"/dwi_${dir}_filtered	\
		-in_bvals ${bids_root}/acq-${acq}_dwi.bval	\
		-in_row_vec ${bids_root}/acq-${acq}_dwi.bvec	\
		-unit_mag_out	\
		-no_qc_view
done