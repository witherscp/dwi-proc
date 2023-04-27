#!/bin/bash

#====================================================================================================================

# description: first alignment unsuccessful (use 'nmi' as cost function, impose max shift/rotation)
# syntax: ./fix_reg.sh 

#====================================================================================================================

cd __WORK_T2toT1
rm -r t2w_01_thr_al_mat.aff12.1D
rm -r map_T2_to_T1.aff12.1D
rm -r t2w_02_FINAL.nii

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

source activate p2.7

align_epi_anat.py 					\
	-dset1 t2w_01_thr.nii.gz 		\
	-dset2 t1w_02_uni_thr.nii.gz	\
	-cost nmi 						\
	-dset1_strip 3dAutomask 		\
	-dset2_strip 3dSkullStrip 		\
	-dset1to2 						\
	-Allineate_opts "-twopass -warp shift_rotate -nomask -maxshf 50 -maxrot 30" \
	-deoblique off 					\
	-resample off 					\
	-overwrite

cat_matvec -ONELINE 			\
    t2w_01_thr_al_mat.aff12.1D 	\
    t2w_01_thr_shft.aff12.1D 	\
    > map_T2_to_T1.aff12.1D 

3dAllineate 								\
	-1Dmatrix_apply map_T2_to_T1.aff12.1D 	\
	-base t1w_02_uni_thr.nii.gz 			\
	-source t2w_00.nii.gz 					\
	-prefix t2w_02_FINAL.nii 				\
	-overwrite

3dresample 					\
	-orient RPI 			\
	-prefix ../t2.nii 		\
	-inset t2w_02_FINAL.nii \
	-overwrite

conda deactivate

#====================================================================================================================
