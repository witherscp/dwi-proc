#!/bin/bash -i

#====================================================================================================================

# Author:   	Price Withers, Kayla Togneri
# Date:     	05/10/23

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h|--help] [-p|--postop] [-no_qc|--no_qc] SUBJ ++\033[0m"
	exit 1
}

# set defaults
postop=false; no_qc=false

# parse options
while [ -n "$1" ]; do
	# check case; if valid option found, toggle its respective variable on
    case "$1" in
    	-h|--help) 			display_usage ;;	# help
	    -p|--postop) 		postop=true ;; 		# post-op
		-no_qc|--no_qc) 	no_qc=true ;; 		# don't do quality check on AFNI
	    *) 					subj=$1; break ;; 	# subject code (prevent any further shifting by breaking)
    esac
    shift 	# shift to next argument
done

# check that exactly 1 parameter was given
if [ ! $# -eq 1 ]; then
	display_usage
fi

if [[ $postop == 'true' ]]; then
	folder_prefix='postop_'
else
	folder_prefix=''
fi

#--------------------------------------------------------------------------------------------------------------------

# VARIABLES

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     neu_dir="/shares/NEU";;
    Darwin*)    neu_dir="/Volumes/Shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be either Linux or Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

subj_mri_dir=${neu_dir}/Projects/MRI/$subj
surf_dir=${subj_mri_dir}/${folder_prefix}surf
mri_surf_dir=${surf_dir}/xhemi/std141/orig

subj_dwi_dir=$neu_dir/Projects/DWI/$subj
dtparams_dir=${subj_dwi_dir}/${folder_prefix}DTparams
indt_dir=${subj_dwi_dir}/${folder_prefix}indt
indt_std141_subdir=${indt_dir}/std141

dwi_proc_dir=$(pwd)
scripts_dir=${dwi_proc_dir}/scripts

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

if [[ ${no_qc} == "false" ]]; then
	source "${scripts_dir}"/all_req_check.sh -afni -x11
fi

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

if [ -f "${surf_dir}/brain_Alnd_Exp.rs.nii" ] && [ -d "${mri_surf_dir}" ]; then
	if [ -f "${dtparams_dir}/dwi_dwi.nii.gz" ] && [ -d "${dtparams_dir}/DECmap" ]; then
		# check that Schaefer parcellations in subject's mesh are present
		if [ -f "${mri_surf_dir}/std.141.rh.Schaefer2018_100Parcels_17Networks_order.smooth3mm.cmaplbl.niml.dset" ]; then
			echo -e "\033[0;35m++ Working on subject ${subj}... ++\033[0m"
		else
			echo -e "\033[0;35m++ Subject ${subj} does not have Schaefer std141 surface parcellations in ${mri_surf_dir}. Please run MRI_do_03.sh. Exiting... ++\033[0m"
			exit 1
		fi
	else
		echo -e "\033[0;35m++ Subject ${subj} does not have ${folder_prefix}DTparams folder. Please run DWI_do_04_DTparams.sh. Exiting... ++\033[0m"
		exit 1
	fi
else
	echo -e "\033[0;35m++ Subject ${subj} does not have SUMA folder. Please run MRI_do_01.sh. Exiting... ++\033[0m"
	exit 1
fi

# check for existence of outputs (prevent double processing)
if [ -a "${indt_std141_subdir}/indt.nii.gz" ]; then
	echo -e "\033[0;36m++ Data already aligned to DTI. Please delete ${indt_std141_subdir} to rerun. ++\033[0m"
	exit 1
fi

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 1: check DEC map *****

if [[ ${no_qc} == "false" ]]; then
	afni ${dtparams_dir}/DECmap/
	sleep 5
	echo -e "\033[0;35m++ Is DEC map correct? Enter y if correct; anything else if not ++\033[0m"
	read ynresponse
	ynresponse=$(echo $ynresponse | tr '[:upper:]' '[:lower:]') 	# turn to lowercase

	if [ "$ynresponse" == "y" ]; then
		echo -e "\033[0;35m++ DEC map correct. Continuing... ++\033[0m"
	else
		echo -e "\033[0;35m++ DEC map not correct. Exiting... ++\033[0m"
		exit 1
	fi
else
	echo -e "\033[0;35m++ Warning: DEC map QC is being skipped... ++\033[0m"
fi

#====================================================================================================================

# ***** STEP 2: set up indt branch in subject DTI data directory *****

if [ ! -d ${indt_std141_subdir} ]; then
	mkdir -p ${indt_std141_subdir}
fi

#====================================================================================================================

# ***** STEP 2: map surface data (obtained from subject's MRI surf dir) -> DT space *****
# NOTE: only mapping FS aparc.* and Schaefer niml datasets

echo -e "\033[0;35m++ Aligning FS volume data and standard mesh surface data (ld = 141) to DTI space. ++\033[0m"
fat_proc_map_to_dti \
	-source ${surf_dir}/brain_Alnd_Exp.rs.nii 									\
	-followers_NN ${surf_dir}/?h.ribbon_Alnd_Exp.rs.nii							\
	-followers_NN ${surf_dir}/aparc+aseg_REN_all_Alnd_Exp.rs.nii 				\
	-followers_NN ${surf_dir}/aparc.a2009s+aseg_REN_all_Alnd_Exp.rs.nii 		\
	-followers_surf ${mri_surf_dir}/*.gii 											\
	-followers_ndset ${mri_surf_dir}/std.141.?h.aparc*.annot.niml.dset 				\
	-followers_ndset ${mri_surf_dir}/std.141.?h.Schaefer2018_*cmaplbl.niml.dset 	\
	-followers_spec ${mri_surf_dir}/*.spec 											\
	-base ${dtparams_dir}/dwi_dwi.nii.gz'[0]' 											\
	-prefix ${indt_std141_subdir}/indt

#====================================================================================================================

# ***** STEP 3: move FS ROI files from subdirectory to indt directory *****

if [ ! -f ${indt_dir}/indt_aparc+aseg_REN_all_Alnd_Exp.rs.nii.gz ]; then
	mv ${indt_std141_subdir}/indt_aparc{,.a2009s}+aseg_REN_all_Alnd_Exp.rs.nii.gz ${indt_dir}
else
	rm ${indt_std141_subdir}/indt_aparc{,.a2009s}+aseg_REN_all_Alnd_Exp.rs.nii.gz
fi

#====================================================================================================================

echo -e "\033[0;32m++ Done! Please check outputs in ${indt_std141_subdir} ++\033[0m"
