#!/bin/bash -i

#====================================================================================================================

# Author:   	Braden Yang
# Date:     	05/06/20

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h|--help] [-p|--postop] [-t|--track_opt TRACK_OPT_PATH] [-m|--mode {prob|det}] [-l|--list SUBJ_LIST] [SUBJ [SUBJ ...]] ++\033[0m"
	exit 1
}

# set defaults
subj_list=false; track_opt_path=false; postop=false; mode=prob

# parse options
while [ -n "$1" ]; do
    case "$1" in
    	-h|--help) 	   	display_usage ;;			# help
		-l|--list) 		subj_list=$2; shift ;; 		# subject list
	    -t|--track_opt) track_opt_path=$2; shift ;; # track options file path
	    -p|--postop) 	postop=true ;; 				# post-op
		-m|--mode) 		mode=$2; shift ;; 			# mode of tractography
	    *) 		   		break ;; 					# prevent any further shifting by breaking
    esac
    shift 	# shift to next argument
done

# check if subj_list argument was given; if not, get positional arguments
if [[ ${subj_list} != "false" ]]; then
	# check that subj_list exists
	if [ ! -f ${subj_list} ]; then
		echo -e "\033[0;35m++ ${subj_list} subject list does not exist. Please enter a valid subject list filepath. Exiting... ++\033[0m"
		exit 1
	else
		subj_arr=($(cat ${subj_list}))
	fi
else
	subj_arr=("$@")
fi

# check that mode option is either "prob" or "det"
if [[ ${mode} != "prob" ]] && [[ ${mode} != "det" ]]; then
	display_usage
fi

# check that length of subject list is greater than zero
if [[ ! ${#subj_arr} -gt 0 ]]; then
	echo -e "\033[0;35m++ Subject list length is zero; please specify at least one subject to perform batch processing on ++\033[0m"
	display_usage
fi

#--------------------------------------------------------------------------------------------------------------------

# DEFINE FUNCTIONS

function clean_up {
	rm -rf "${temp_dir}"		# remove temporary working directory
	ssh-add -d ~/.ssh/id_rsa 	# remove key from agent
}

#--------------------------------------------------------------------------------------------------------------------

# VARIABLES AND PATHS

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     neu_dir="/shares/NEU";;
    Darwin*)    neu_dir="/Volumes/Shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be either Linux or Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

# NEU paths
pwd_dir=$(pwd)
scripts_dir="${neu_dir}/Scripts_and_Parameters/scripts"
proj_dir="${neu_dir}/Projects"

dwi_proc_dir=$(pwd)
scripts_dir=${dwi_proc_dir}/scripts
files_dir=${dwi_proc_dir}/files

# other variables
username=${USER}
run_date=$(date +"%y%m%d-%H%M%S")
run_date_clean=$(date +"%D-%T")
job_name="track_${mode}_${run_date}"

# if no -t option given, use track_opt_default
if [[ $track_opt_path == "false" ]]; then
	track_opt_path="${files_dir}/track_opt_default"
fi

# handle -m option
if [[ ${mode} == "prob" ]]; then
	mode_str="PROBABILISTIC TRACTOGRAPHY"
	wdir_base="__WORK_PROB_TRACK"
else
	mode_str="DETERMINISTIC TRACTOGRAPHY"
	wdir_base="__WORK_DET_TRACK"
fi

# get biowulf login node paths
biowulf_dwi_dir="/data/${username}/DWI"

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source "${scripts_dir}"/all_req_check.sh -afni -ssh

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

# check that track_opt file exists
if [ ! -f $track_opt_path ]; then
	echo -e "\033[0;35m++ ${track_opt_path} does not exist. Please enter a valid track_opt filepath. Exiting... ++\033[0m"
	exit 1
fi

# bring variables in track_opt file to current scope
source $track_opt_path

# check that track_opt file contains correct variables
if [ -z ${my_roi+x} ]; then
	echo -e "\033[0;35m++ track_opt file does not contain the right variables. Please input a track_opt file that contains paths to ROI files and 3dTrackId parameters. Exiting... ++\033[0m"
	exit 1
fi

# check that all the ROI files exist
network_list=""	 	# list of ROI networks (to be displayed in user interaction)
for roi in "${my_roi[@]}"; do
	# check for absolute paths; if so, prevent script from running
	if [[ ${roi} == /* ]]; then
		echo -e "\033[0;35m++ No absolute paths to ROI files are allowed in track_opt. Please input only file names; they will automatically be picked out from subject's roi directory ++\033[0m"
		exit 1
	fi

	# add to list of ROI networks
	network_list="${network_list}${roi}\n"
done

# clean up user-inputted note by replacing space with underscore
note_clean=$(echo ${note} | tr ' ' '_'); note="${note_clean}"

#--------------------------------------------------------------------------------------------------------------------

# USER INTERACTION

# inform user of the subjects to be processed in biowulf
echo -e "\033[0;36m***** THE FOLLOWING SUBJECTS WILL BE TRACKED IN BIOWULF USING ${mode_str} *****\033[0m"
echo "${subj_arr[@]}"
echo -e "\033[0;36m***** DO YOU WISH TO PROCEED? ENTER 'y' TO PROCEED, ANYTHING ELSE TO CANCEL *****\033[0m"
read -r ynresponse
if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Proceeding... ++\033[0m"
else
    echo -e "\033[0;35m++ Canceled. Please make alterations to your subject list file. Exiting... ++\033[0m"
	exit 1
fi

# inform user of tractography options
echo -e "\033[0;35m***** THE FOLLOWING NETWORKS WILL BE TRACKED USING ${mode_str} *****\033[0m"
echo -e "\033[0;33m${network_list}\033[0m"
echo -e "\033[0;35m***** WITH THE FOLLOWING TRACKING PARAMETERS *****\033[0m"
echo -e "\033[0;33malg_Thresh_FA   = ${my_Thresh_FA}\033[0m"
echo -e "\033[0;33malg_Thresh_ANG  = ${my_Thresh_ANG}\033[0m"
echo -e "\033[0;33malg_Thresh_Len  = ${my_Thresh_Len}\033[0m"
if [[ ${mode} == "prob" ]]; then
	echo -e "\033[0;33malg_Thresh_Frac = ${my_Thresh_Frac}\033[0m"
	echo -e "\033[0;33malg_Nmonte      = ${my_Nmonte}\033[0m"
else
	echo -e "\033[0;33mbundle_thr      = ${my_bundle_thr}\033[0m"
fi
if [[ ${note} != "" ]]; then 
	echo -e "\033[0;35m***** THE FOLLOWING NOTE WILL BE APPENDED TO TRACK_LOG *****\033[0m"
	echo "${note}"
fi
echo -e "\033[0;35m\n***** ENTER 'y' TO PROCEED, ANYTHING ELSE TO CANCEL *****\033[0m"
read -r ynresponse
ynresponse=$(echo "$ynresponse" | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Proceeding... ++\033[0m"
else
    echo -e "\033[0;35m++ Canceled. Please make alterations to your track_opt file. Exiting... ++\033[0m"
    exit 1
fi

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 0: add keys to ssh-agent *****

echo -e "\033[0;35m++ Adding authentication keys to ssh-agent ... ++\033[0m"
ssh-add

# DATA CHECK: check that /data/${username}/DTI exists in biowulf
check_dti_folder=$(ssh -q ${username}@biowulf.nih.gov "ls /data/${username}/DWI 2>&1")
if echo "${check_dti_folder}" | grep -q "No such file or directory"; then
	echo -e "\033[0;36m++ Biowulf is not set up for user ${username}. Please run DWI_do_setupBiowulf.sh. Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================

# ***** STEP 1: set up biowulf working directory "__WORK_{mode}_TRACK_??" *****

# check the number of working directories in biowulf login node and name new wdir
ls_stdout=$(ssh -q ${username}@biowulf.nih.gov "cd ${biowulf_dwi_dir}; ls")
num_wdir=$(printf -- '%s\n' ${ls_stdout} | grep -c "${wdir_base}")
wdir_name=${wdir_base}_$(printf "%02d" ${num_wdir})

# make preop/postop subdirectory in wdir (depending on -p option)
if [[ $postop == true ]]; then
	biowulf_wdir="${biowulf_dwi_dir}/${wdir_name}/postop"
    folder_prefix='postop_'
else
	biowulf_wdir="${biowulf_dwi_dir}/${wdir_name}/preop"
    folder_prefix=''
fi

# make new working directory in biowulf
echo -e "\033[0;35m++ Making ${wdir_name} directory in biowulf login node ++\033[0m"
ssh -q ${username}@biowulf.nih.gov "mkdir -p ${biowulf_wdir}"

# set up temporary working directory in local machine
temp_dir=${pwd_dir}/temp_track; mkdir ${temp_dir}

# set up swarm file in local working directory (submitted via the swarm command on biowulf)
swarm_file=${temp_dir}/my.swarm

# set up _run_track.sh script (rename from _run_{mode}_track.sh to _run_track.sh)
if [[ ${mode} == "prob" ]]; then
	sed 												\
		-e "s/\${my_Thresh_FA}/${my_Thresh_FA}/" 		\
		-e "s/\${my_Thresh_ANG}/${my_Thresh_ANG}/" 		\
		-e "s/\${my_Thresh_Len}/${my_Thresh_Len}/" 		\
		-e "s/\${my_Thresh_Frac}/${my_Thresh_Frac}/" 	\
		-e "s/\${my_Nmonte}/${my_Nmonte}/" 				\
		-e "s/\${wdir_name}/${wdir_name}/" 				\
		${scripts_dir}/_run_prob_track.sh > ${temp_dir}/_run_track.sh
else
	sed 											\
		-e "s/\${my_Thresh_FA}/${my_Thresh_FA}/" 	\
		-e "s/\${my_Thresh_ANG}/${my_Thresh_ANG}/" 	\
		-e "s/\${my_Thresh_Len}/${my_Thresh_Len}/" 	\
		-e "s/\${my_bundle_thr}/${my_bundle_thr}/" 	\
		-e "s/\${wdir_name}/${wdir_name}/" 			\
		${scripts_dir}/_run_det_track.sh > ${temp_dir}/_run_track.sh
fi

#====================================================================================================================

# ***** STEP 2: collate all subject-specific files into "__WORK_{mode}_TRACK" *****

# iterate over subjects in subj_arr
subj_actually_proc=(); subj_skip=()
for subj in "${subj_arr[@]}"; do

	# *********************** SUBJECT SPECIFIC DATA CHECK ***********************

	# define subject data paths
	param_dir=${proj_dir}/DWI/${subj}/${folder_prefix}DTparams
	roi_dir=${proj_dir}/DWI/${subj}/${folder_prefix}roi

	echo -e "\033[0;35m++ Checking data requirements for subject ${subj} ++\033[0m"

	# check for required DTI data in DTparams directory
	if [[ ${mode} == "prob" ]]; then
		if [ ! -f "${param_dir}/dt_DT.nii.gz" ] || [ ! -f "${param_dir}/dt_UNC.nii.gz" ]; then
			echo -e "\033[0;36m++ Subject ${subj} does not have necessary DT parameters in ${param_dir}. Please run DWI_do_04_DTparams. Skipping subject ${subj}... ++\033[0m"
			subj_skip+=("${subj}")
			continue
		fi
	else
		if [ ! -f "${param_dir}/dt_DT.nii.gz" ] || [ ! -f "${param_dir}/dwi_mask_e2.nii.gz" ]; then
			echo -e "\033[0;36m++ Subject ${subj} does not have necessary DT parameters in ${param_dir}. Please run DWI_do_04_DTparams. Skipping subject ${subj}... ++\033[0m"
			subj_skip+=("${subj}")
			continue
		fi
	fi

	# DATA CHECK: check existence and viability of ROI files
	roi_abs_arr=(); no_data=false
	for roi in "${my_roi[@]}"; do
		# get absolute path to ROI file (should be in subject's "roi" dir)
		roi_abs=${roi_dir}/${roi}

		# check if ROI files exist; if so, store them as absolute paths
		if [ ! -f ${roi_abs} ]; then
			no_data=true
			echo -e "\033[0;36m++ Subject ${subj} does not have ${roi_abs}. Skipping subject ${subj}... ++\033[0m"
			subj_skip+=("${subj}")
			break
		fi

		# check that ROI file is a .nii file
		if 3dinfo ${roi_abs} 2>&1 | grep -q "FATAL ERROR"; then
			no_data=true
			echo -e "\033[0;36m++ ${roi_abs} is not a valid .nii file. Skipping subject ${subj}... ++\033[0m"
			subj_skip+=("${subj}")
			break
		fi

		# if checks passed, append absolute path to array roi_abs_arr
		roi_abs_arr+=("${roi_abs}")
	done
	if [[ ${no_data} == "true" ]]; then continue; fi

	# if all data checks passed, set up subject directory
	temp_subj_dir=${temp_dir}/${subj}; mkdir -p ${temp_subj_dir}

	# *********************** SET UP TEMPORARY TRACK_LOG FILE ***********************

	echo -e "\033[0;35m++ Setting up track_opt file for subject ${subj} ++\033[0m"

	# column headers for track_log
	if [[ ${mode} == "prob" ]]; then
		echo "track_idx run_date roi_path output_dir num_parc num_network alg_Thresh_FA alg_Thresh_ANG alg_Thresh_Len alg_Thresh_Frac alg_Nmonte ld note" >> ${temp_subj_dir}/track_log_temp
	else
		echo "track_idx run_date roi_path output_dir num_parc num_network alg_Thresh_FA alg_Thresh_ANG alg_Thresh_Len bundle_thr ld note" >> ${temp_subj_dir}/track_log_temp
	fi

	# *********************** COPY ROI FILES INTO __WORK_{mode}_TRACK_??/${SUBJ} ***********************

	# iterate over ROI files
	for ((i=0;i<${#roi_abs_arr[@]};i++)); do

		# get current ROI path
		roi_cur=${roi_abs_arr[i]}
		roi_name=$(basename ${roi_abs_arr[i]})

		# set up ROI-specific subdir in subject directory
		idx_format=$(printf '%02d' ${i})
		idx_dir=${temp_subj_dir}/${idx_format}; mkdir -p ${idx_dir}

		# copy ROI to ROI-specific subdir
		3dcopy ${roi_cur} ${idx_dir}/my_roi.nii

		# *********************** ADD LINE TO SWARM FILE ***********************

		echo "bash ${biowulf_wdir}/_run_track.sh ${subj} postop_${postop} ${idx_format}" >> "${swarm_file}"

		# *********************** ADD LINE TO TRACK_LOG FILE ***********************

		# count number of lines in track_log_temp; this will determine what index will be assigned to the current ROI network
		num_line=$(cat ${temp_subj_dir}/track_log_temp | wc -l)
		let "idx=num_line-1"

		# get number of parcels in ROI network (trim white space with tr)
		num_parc=$(3dBrickStat -max ${roi_cur} | tr -d '[:space:]')

		# if Schaefer ROI was used, get number of networks ; else, leave blank
		if [[ ${roi_name} = *Schaefer* ]]; then
			x=${roi_name%Networks*} 	# removes everything right of the expression "Networks"
			num_network=${x##*_} 		# removes everything left of the last "_"
		else
			num_network=""
		fi

		# get standard mesh density
		ld_full=$(echo $(basename ${roi_cur}) | grep -o 'std.[0-9]\+')
		ld=${ld_full#*.}

		# add new line to track_log_temp (leave odir blank for now; will be filled in when data is pulled with DTI_do_track_biowulf_pull.sh)
		if [[ ${mode} == "prob" ]]; then
			echo "\${idx} ${run_date_clean} ${roi_cur} \${odir} ${num_parc} ${num_network} ${my_Thresh_FA} ${my_Thresh_ANG} ${my_Thresh_Len} ${my_Thresh_Frac} ${my_Nmonte} ${ld} ${note}" >> ${temp_subj_dir}/track_log_temp
		else
			echo "\${idx} ${run_date_clean} ${roi_cur} \${odir} ${num_parc} ${num_network} ${my_Thresh_FA} ${my_Thresh_ANG} ${my_Thresh_Len} ${my_bundle_thr} ${ld} ${note}" >> ${temp_subj_dir}/track_log_temp
		fi
	done

	# copy to biowulf
	echo -e "\033[0;35m++ Making subject directory in ${wdir_name} for subject ${subj} ++\033[0m"
	scp -q -r ${temp_subj_dir} ${username}@helix.nih.gov:${biowulf_wdir}/.

	# *********************** COPY DT PARAM FILES INTO __WORK_{mode}_TRACK_??/${SUBJ} ***********************

	echo -e "\033[0;35m++ Copying DTparams data to ${wdir_name} for subject ${subj} ++\033[0m"
	scp -q ${param_dir}/dt_* ${username}@helix.nih.gov:${biowulf_wdir}/${subj}/.

	# *********************** COPY ERODED BRAIN MASK INTO __WORK_{mode}_TRACK_??/${SUBJ} IF DET MODE ***********************

	if [[ ${mode} == "det" ]]; then
		echo -e "\033[0;35m++ Copying eroded brain mask to ${wdir_name} for subject ${subj} ++\033[0m"
		scp -q ${param_dir}/dwi_mask_e2.nii.gz ${username}@helix.nih.gov:${biowulf_wdir}/${subj}/.
	fi

	# *********************** CLEAN UP ***********************

	# delete temp_subj_dir directory from local machine
	rm -rf ${temp_subj_dir}

	# add to list of subjects that have actually been processed
	subj_actually_proc+=("${subj}")

done

#====================================================================================================================

# ***** STEP 3: copy remaining files to biowulf (if # of subj actually processed > 0) *****

if [[ ${#subj_actually_proc[@]} -eq 0 ]]; then
	echo -e "\033[0;35m++ No subjects passed data check. Removing ${wdir_name} ++\033[0m"
	ssh -q ${username}@biowulf.nih.gov "rm -r ${biowulf_dwi_dir}/${wdir_name}"
	clean_up # clean up

	echo -e "\033[0;32m++ No subjects passed data check. Exiting... ++\033[0m"
	exit 1
else
	echo -e "\033[0;35m++ Copying remaining files to ${wdir_name} ++\033[0m"
	scp -q ${temp_dir}/* ${username}@helix.nih.gov:${biowulf_wdir}/.
fi

#====================================================================================================================

# ***** STEP 4: submit job in biowulf *****

echo -e "\033[0;35m++ Submitting job ++\033[0m"
if [[ ${mode} == "prob" ]]; then
	if [ ${track_opt_path##*/} == track_opt_diffParcs ]; then
		slurm=$(ssh -q ${username}@biowulf.nih.gov "cd ${biowulf_wdir}; swarm -f ${biowulf_wdir}/my.swarm -p 1 -g 500 --partition largemem --module afni/current-openmp --job-name ${job_name} --time 08:00:00")
	else
		slurm=$(ssh -q ${username}@biowulf.nih.gov "cd ${biowulf_wdir}; swarm -f ${biowulf_wdir}/my.swarm -p 2 -g 100 --module afni/current-openmp --job-name ${job_name} --time 06:00:00")
	fi
else
	slurm=$(ssh -q ${username}@biowulf.nih.gov "cd ${biowulf_wdir}; swarm -f ${biowulf_wdir}/my.swarm -p 2 -g 100 --module afni/current-openmp --job-name ${job_name} --time 00:30:00")
fi

if [[ ${slurm} == '' ]]; then
	echo -e "\033[0;35m++ Unable to retrieve jobid. Please check to make sure script was executed on biowulf. ++\033[0m"
else
	jobout=${slurm#*-}
	jobid=${jobout%.*}
	echo -e "\033[0;35m++ Job submitted: ${jobid} ++\033[0m"
fi

#====================================================================================================================

# clean up
clean_up

echo -e "\033[0;32m++ Done! Please run sjobs on biowulf login node, or login to the User Dashboard on the HPC website, to check that jobs have been successfully submitted (job ID: ${jobid}) ++\033[0m"
echo -e "\033[0;32m++ The following subjects have been pushed to biowulf for tractography: ++\033[0m"
for subj in "${subj_actually_proc[@]}"; do
	echo -e "\033[0;32m $subj \033[0m"
done
echo -e "\033[0;31m++ The following subjects have been skipped: ++\033[0m"
for subj in "${subj_skip[@]}"; do
	echo -e "\033[0;32m $subj \033[0m"
done
