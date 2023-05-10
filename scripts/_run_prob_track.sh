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
biowulf_wdir="/data/${USER}/DWI/${wdir_name}/${subdir}/${subj}"
odir="${biowulf_wdir}/${idx}"

# run probabilistic tractography
3dTrackID 										\
	-mode 	 PROB								\
	-dti_in  "${biowulf_wdir}/dt" 				\
	-uncert  "${biowulf_wdir}/dt_UNC.nii.gz" 	\
	-netrois "${odir}/my_roi.nii" 				\
	-prefix  "${odir}/track" 					\
	-alg_Thresh_FA "${my_Thresh_FA}" 			\
	-alg_Thresh_ANG "${my_Thresh_ANG}" 			\
	-alg_Thresh_Len "${my_Thresh_Len}"			\
	-alg_Thresh_Frac "${my_Thresh_Frac}" 		\
	-alg_Nseed_Vox 5 							\
	-alg_Nmonte "${my_Nmonte}" 					\
	-targ_surf_stop								\
	-extra_tr_par								\
	-write_rois									\
	-nifti
