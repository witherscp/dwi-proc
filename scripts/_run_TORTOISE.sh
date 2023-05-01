#!/bin/bash

# set environmental variables to control multi-threading
OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$SLURM_CPUS_PER_TASK

# get subject code (passed as first argument)
subj=$1
postop=$2
biowulf_wdir=$3

# get paths (in biowulf)
if [[ ${postop} == "postop_true" ]]; then
	folder_suffix='_postop'
else
	folder_suffix=''
fi
subj_dir=${biowulf_wdir}/${subj}
diffprep_dir=${subj_dir}/diffprep${folder_suffix}
buddi_dir=${subj_dir}/drbuddi${folder_suffix}

# run diffprep on blip-up and blip-down data
for phase in 'up' 'down'; do
	phase_nii="dwi_${phase}_filtered.nii.gz"
	phase_rvec="dwi_${phase}_filtered_rvec.dat"
	phase_bval="dwi_${phase}_filtered_bval.dat"

	DIFFPREP	\
		--dwi 				"${diffprep_dir}"/${phase_nii} 	\
		--bvecs 			"${diffprep_dir}"/${phase_rvec} 	\
		--bvals 			"${diffprep_dir}"/${phase_bval} 	\
		--structural 		"${diffprep_dir}"/t2.nii 			\
		--phase 			vertical 						\
		--will_be_drbuddied 1 								\
		--reg_settings 		registration_settings.dmc 		\
		--do_QC 			0
done

# make drbuddi folder if doesn't exist
if [ ! -d "${buddi_dir}" ]; then
	mkdir -p "${buddi_dir}"
fi

# run drbuddi
DR_BUDDI_withoutGUI	\
	--up_data 	 "${diffprep_dir}"/dwi_up_filtered_proc.list 	\
	--down_data  "${diffprep_dir}"/dwi_down_filtered_proc.list 	\
	--structural "${diffprep_dir}"/t2.nii 			\
	--output 	 "${buddi_dir}"/buddi.list
