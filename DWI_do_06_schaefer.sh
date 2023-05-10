#!/bin/bash

#====================================================================================================================

# Author:   	Price Withers
# Date:     	10/15/21
# Updated:      --

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h] [-p | --postop] [-n PARCS_NETWORKS ] SUBJ ++\033[0m"
	exit 1
}

# set defaults
parc=false; postop=false

# parse options
while [ -n "$1" ]; do
	# check case; if valid option found, toggle its respective variable on
    case "$1" in
    	-h) 	        display_usage ;;	# help
	    -p|--postop) 	postop=true ;; 		# post-op
		-n)		        parc=$2; shift ;; 	# Schaefer parcellation to make ROIs for
	    *) 		        subj=$1; break ;; 	# subject code (prevent any further shifting by breaking)
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

# VARIABLES AND PATHS

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     neu_dir="/shares/NEU";;
    Darwin*)    neu_dir="/Volumes/shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be either Linux or Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

# set parc to all parcellations if none is given
if [[ ${parc} == "false" ]]; then
	num_parc_list=( "100" "200" "300" "400" "500" "600" "800" "1000" )
	num_network_list=( "17" "7" )
# else use parcellation provided
else
	num_parc_list=("${parc%_*}")
	num_network_list=("${parc#*_}")
fi

subj_dwi_dir=$neu_dir/Projects/DWI/$subj
dtparams_dir=${subj_dwi_dir}/${folder_prefix}DTparams
dwi_indt_dir=${subj_dwi_dir}/${folder_prefix}indt
indt_std141_subdir=${dwi_indt_dir}/std141
roi_dir=${subj_dwi_dir}/${folder_prefix}roi

pwd_dir=$(pwd)
scripts_dir=${pwd_dir}/scripts

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source "${scripts_dir}"/all_req_check.sh -afni -p3

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

# check for existence of DTparams data
if [ ! -f "${dtparams_dir}"/dwi_mask.nii.gz ] || [ ! -f "${dtparams_dir}/dt_FA.nii.gz" ]; then
	echo -e "\033[0;35m++ Subject ${subj} does not have DTparams data in ${dtparams_dir}. Please run DTI_do_estimate_tensor.sh. Exiting... ++\033[0m"
	exit 1
fi

# check for existence of indt data
if [ ! -f "${indt_std141_subdir}"/indt.nii.gz ] || [ ! -f "${indt_std141_subdir}/indt_std.141.lh.smoothwm.gii" ]; then
	echo -e "\033[0;35m++ Subject ${subj} does not have indt data in ${indt_std141_subdir}. Please run DTI_do_indt.sh. Exiting... ++\033[0m"
	exit 1
fi

echo -e "\033[0;35m++ Working on subject ${subj}... ++\033[0m"

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 0: set up ROI branch in subject DTI data directory *****

if [ ! -d $roi_dir ]; then
	mkdir $roi_dir
fi

if [ ! -f $roi_dir/indt.nii.gz ]; then
	cp ${indt_std141_subdir}/indt.nii.gz $roi_dir/.
fi

#====================================================================================================================

# ***** STEP 1: map Schaefer parcellations from surface to volume *****

cd "${indt_std141_subdir}" || exit

# iterate over number of parcels
for num_parc in "${num_parc_list[@]}"; do
	# iterate over number of networks
	for num_network in "${num_network_list[@]}"; do

		# check if output already exists (prevent double processing)
		if [ -f "${roi_dir}/indt_std.141.both.Schaefer2018_${num_parc}Parcels_${num_network}Networks_FINAL.nii.gz" ]; then
			echo -e "\033[0;36m++ ${roi_dir}/indt_std.141.both.Schaefer2018_${num_parc}Parcels_${num_network}Networks_FINAL.nii.gz already exists ++\033[0m"
			continue
		fi

		# echo statement
		echo -e "\033[0;35m++ Working on ${num_parc} parcels ${num_network} networks ++\033[0m"

		# iterate over both hemispheres
		for hemi in 'rh' 'lh'; do

			# base name for Schaefer parcellation
			bn="indt_std.141.${hemi}.Schaefer2018_${num_parc}Parcels_${num_network}Networks"

			@surf_to_vol_spackle 									  				   \
				-maskset 	indt_${hemi}.ribbon_Alnd_Exp.rs.nii.gz    				   \
				-spec 		indt_std.141.${hemi}.spec			      				   \
      			-surfA 		indt_std.141.${hemi}.smoothwm.gii 		  				   \
				-surfB 		indt_std.141.${hemi}.pial.gii 			  				   \
				-surfset 	"${bn}"_order.smooth3mm.cmaplbl.niml.dset 				   \
				-mode																   \
      			-prefix 	"${bn}"

			# grow ROI using 3dROIMaker (prepares ROI for tractography)
			gm_parc="${bn}.nii.gz"
			3dROIMaker	\
				-inset 				$gm_parc 						\
				-refset 			$gm_parc 						\
				-prefix 			${roi_dir}/$bn 					\
				-inflate 			3								\
				-mask 				${dtparams_dir}/dwi_mask_e2.nii.gz \
				-wm_skel 			${dtparams_dir}/dt_FA.nii.gz 		\
				-skel_thr 			0.2 							\
				-skel_stop_strict 									\
				-nifti

			# remove temp file
			rm -f ${gm_parc}

			# get correct hemi cerebral WM parcel from aparc.a2009s+aseg parcellation
			if [ $hemi == 'lh' ]; then
				wm_parcel=1
			else
				wm_parcel=21
			fi

			# only allow voxels to be present within GM ribbon or WM space (from aparc.a2009s* parcellation)
			3dcalc	\
				-a ../indt_aparc.a2009s+aseg_REN_all_Alnd_Exp.rs.nii.gz   \
				-b indt_${hemi}.ribbon_Alnd_Exp.rs.nii.gz 	  			  \
				-c "${roi_dir}"/"${bn}"_GMI.nii.gz		      			  \
				-expr "c*bool(equals(a,$wm_parcel)+b)" 		  			  	  \
				-prefix "${roi_dir}"/"${bn}"_GMI_masked.nii.gz

		done

		# file paths
		gmi_rh="${roi_dir}/indt_std.141.rh.Schaefer2018_${num_parc}Parcels_${num_network}Networks_GMI_masked.nii.gz"
		gmi_lh="${roi_dir}/indt_std.141.lh.Schaefer2018_${num_parc}Parcels_${num_network}Networks_GMI_masked.nii.gz"
		gmi_both="${roi_dir}/indt_std.141.both.Schaefer2018_${num_parc}Parcels_${num_network}Networks_FINAL.nii.gz"

		# get n_parcs in a hemi
		n_hemi_parcs=$((num_parc/2))

		# merge ROI from both hemispheres (if there is overlap, then set ROI = 0)
		3dcalc \
			-a "$gmi_lh" -b "$gmi_rh"								\
			-expr "(a+ifelse(b,$n_hemi_parcs+b,0))*not(and(a,b))"	\
			-prefix "$gmi_both"
		
		# generate niml.lbl file
		lbl_file=${roi_dir}/indt_std.141.both.Schaefer2018_${num_parc}Parcels_${num_network}Networks_FINAL.niml.lt
		3dinfo -labeltable indt_std.141.lh.Schaefer2018_${num_parc}Parcels_${num_network}Networks_order.smooth3mm.cmaplbl.niml.dset >> $lbl_file

		# attach labeltable to final nii.gz file
		3drefit -labeltable "$lbl_file" "$gmi_both"
		
		# generate 1D label file
		label_dir=${roi_dir}/label
		if [ ! -d ${label_dir} ]; then 
			mkdir -p ${label_dir}
		fi
		my_1D=${label_dir}/indt_std.141.both.Schaefer2018_${num_parc}Parcels_${num_network}Networks_FINAL.1D.dset
		python3 ${scripts_dir}/_get_labels_1D.py	\
			"$(3dinfo -labeltable ${roi_dir}/indt_std.141.both.Schaefer2018_${num_parc}Parcels_${num_network}Networks_FINAL.nii.gz)" 	 \
			${my_1D}

		# remove temporary files
		rm ${roi_dir}/*Schaefer*GM*
	done
done

#====================================================================================================================

echo -e "\033[0;32m++ Done! Please check outputs in ${roi_dir} ++\033[0m"
