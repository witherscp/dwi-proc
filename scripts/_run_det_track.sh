#!/bin/bash

# get subject code (passed in as first argument)
subj=$1
postop=$2
idx=$3

# get paths (in biowulf)
if [[ ${postop} == "postop_true" ]]; then
	subdir="postop"
else
	subdir="preop"
fi
biowulf_wdir="/data/${USER}/DTI/${wdir_name}/${subdir}/${subj}"
odir="${biowulf_wdir}/${idx}"

# run deterministic tractography
3dTrackID 												 \
	-mode 	 		DET									 \
	-logic 	 		AND 								 \
	-dti_in  		"${biowulf_wdir}/dt" 				 \
	-netrois 		"${odir}/my_roi.nii" 	 		 	 \
	-mask 			"${biowulf_wdir}/dwi_mask_e2.nii.gz" \
	-prefix  		"${odir}/o" 						 \
	-no_indipair_out 									 \
	-alg_Thresh_FA  "${my_Thresh_FA}" 					 \
	-alg_Thresh_ANG "${my_Thresh_ANG}" 					 \
	-alg_Thresh_Len "${my_Thresh_Len}"					 \
	-bundle_thr 	"${my_bundle_thr}"					 \
	-extra_tr_par
