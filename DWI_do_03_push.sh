#!/bin/bash

#====================================================================================================================

# Name: 		DWI_do_03_push.sh

# Author:   	Price Withers, Kayla Togneri, Braden Yang
# Date:     	04/27/23

# Syntax:       ./DWI_do_03_push.sh [-h|--help] [-p|--postop] [-l|--list SUBJ_LIST] [SUBJ [SUBJ ...]]

# Arguments:    SUBJ: subject ID
# Description:  

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h|--help] [-p|--postop] [-l|--list SUBJ_LIST] [SUBJ [SUBJ ...]] ++\033[0m"
	exit 1
}

# set defaults
subj_list=false; postop=false;

# parse options
while [ -n "$1" ]; do
	# check case; if valid option found, toggle its respective variable on
    case "$1" in
    	-h|--help) 	 display_usage ;;		# help
		-l|--list) 	 subj_list=$2; shift ;; # subject list
	    -p|--postop) postop=true ;; 		# post-op
	    *) 			 break ;; 				# prevent any further shifting by breaking
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

# check that length of subject list is greater than zero
if [[ ! ${#subj_arr} -gt 0 ]]; then
	echo -e "\033[0;35m++ Subject list length is zero; please specify at least one subject to perform batch processing on ++\033[0m"
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
	folder_suffix='_postop'
else
	folder_suffix=''
fi

pwd=$(pwd)
scripts_dir=$pwd/scripts

# other variables
username=${USER}
run_date=$(date +"%y%m%d-%H%M%S")
run_date_clean=$(date '+%Y-%m-%d %H:%M:%S')
job_name="TORTOISE_${run_date}"
TORTOISE_version="TORTOISE/3.1.4"

# biowulf login node paths
biowulf_dti_dir="/data/${username}/DTI"

#---------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source ${neu_dir}/Scripts_and_Parameters/scripts/all_req_check -ssh

#---------------------------------------------------------------------------------------------------------------------

# inform user of the subjects to be processed in biowulf
echo -e "\033[0;36m***** THE FOLLOWING SUBJECTS WILL BE TORTOISE PROCESSED IN BIOWULF *****\033[0m"
echo "${subj_arr[@]}"
echo -e "\033[0;36m***** DO YOU WISH TO PROCEED? ENTER 'y' TO PROCEED, ANYTHING ELSE TO CANCEL *****\033[0m"
read -r ynresponse
if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Proceeding... ++\033[0m"
else
    echo -e "\033[0;35m++ Canceled. Please make alterations to your subject list file. Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 0: add keys to ssh-agent *****

echo -e "\033[0;35m++ Adding authentication keys to ssh-agent ... ++\033[0m"
ssh-add

# DATA CHECK: check that /data/${username}/DTI and /home/${username}/DIFF_PREP_WORK/registration_settings.dmc exist in biowulf
check_dti_folder=$(ssh ${username}@biowulf.nih.gov "ls /data/${username}/DTI 2>&1")
check_diff_prep_work=$(ssh ${username}@biowulf.nih.gov "ls /home/${username}/DIFF_PREP_WORK/registration_settings.dmc 2>&1")
if echo "${check_dti_folder} ${check_diff_prep_work}" | grep -q "No such file or directory"; then
	echo -e "\033[0;36m++ Biowulf is not set up for user ${username}. Please run DTI_do_setupBiowulf.sh. Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================

# ***** STEP 1: set up biowulf working directory "__WORK_TORTOISE_??" *****

# check the number of working directories in biowulf login node and name new wdir
num_wdir=$(printf -- '%s\n' "${check_dti_folder}" | grep -c "__WORK_TORTOISE")
wdir_name=__WORK_TORTOISE_$(printf "%02d" ${num_wdir})

# biowulf working directory
if [[ $postop == true ]]; then
	biowulf_wdir="${biowulf_dti_dir}/${wdir_name}/postop"
else
	biowulf_wdir="${biowulf_dti_dir}/${wdir_name}/preop"
fi

# set up temporary working directory in local machine
temp_dir=${scripts_dir}/__WORK_TORTOISE; mkdir "${temp_dir}"

# set up swarm file in local working directory (submitted via the swarm command on biowulf)
swarm_file=${temp_dir}/my.swarm; touch "${swarm_file}"

#====================================================================================================================

# ***** STEP 2: collate all subject-specific files into "__WORK_TORTOISE_??" *****

# iterate over subject list
subj_actually_proc=()
for subj in "${subj_arr[@]}"; do

	# *********************** DEFINE PATHS ***********************

    subj_dwi_dir=$neu_dir/Projects/DTI/$subj
    dwi_reg_dir=$subj_dwi_dir/reg${folder_suffix}
    dwi_sel_dir=$subj_dwi_dir/sel${folder_suffix}

    # create temporary diffprep folder
	dwi_diffprep_dir=${subj_dwi_dir}/diffprep${folder_suffix}
	if [[ ! -d "$dwi_diffprep_dir" ]]; then
		mkdir "$dwi_diffprep_dir"
		3dcopy "$dwi_reg_dir"/t2.nii "$dwi_diffprep_dir"/t2.nii
		for dir in up down; do
			prefix=dwi_${dir}_filtered
			for file in ${prefix}_bval.dat ${prefix}_rvec.dat; do
				cp "$dwi_sel_dir"/"$file" "$dwi_diffprep_dir"
			done
			3dcopy "$dwi_sel_dir"/${prefix}.nii.gz "$dwi_diffprep_dir"/${prefix}.nii.gz
		done
	fi

	dwi_drbuddi_dir=${subj_dwi_dir}/drbuddi${folder_suffix}

	# *********************** SUBJECT SPECIFIC DATA CHECK ***********************

	echo -e "\033[0;35m++ Checking data requirements for subject ${subj} ++\033[0m"

	# check that a DTI folder is present for the current subj
	if [ ! -d "${subj_dwi_dir}" ]; then
		echo -e "\033[0;36m++ Subject ${subj} does not have ${subj_dwi_dir}. Skipping subject ${subj} ++\033[0m"
		subj_skip+=("${subj}")
		continue
	fi

	# check to see if subj is currently being/has been processed in biowulf
	if [ -f "${subj_dwi_dir}/biowulf_proc" ]; then 
		current_info=$(cat "${subj_dwi_dir}"/biowulf_proc)
		echo -e "\033[0;36m++ Subject ${subj} is currently being/has been processed in biowulf: ${current_info} ++\n++ Skipping subject ${subj} ++\033[0m"
		subj_skip+=("${subj}")
		continue
	fi

	# check for existence of drbuddi folder
	if [ -d "${dwi_drbuddi_dir}" ]; then
		echo -e "\033[0;36m++ Subject ${subj} already has a drbuddi folder. Skipping subject ${subj} ++\033[0m"
		subj_skip+=("${subj}")
		continue
	fi

	# *********************** COPY DATA TO BIOWULF ***********************

	echo -e "\033[0;35m++ Pushing data to biowulf for subject ${subj} ++\033[0m"

	# if all data checks passed, set up subject directory in biowulf
	ssh ${username}@biowulf.nih.gov "mkdir -p ${biowulf_wdir}/${subj}"

	# copy subject data (diffprep dir) to __WORK_TORTOISE_??
	echo -e "\033[0;35m++ Copying diffprep directory to biowulf for subject $subj... ++\033[0m"
	scp -r ${dwi_diffprep_dir} ${username}@helix.nih.gov:${biowulf_wdir}/${subj}

	# add line in swarm file for subject
	echo "bash ${biowulf_wdir}/_run_TORTOISE.sh ${subj} postop_${postop} ${biowulf_wdir}" >> ${swarm_file}

	# add to list of subjects that have actually been processed
	subj_actually_proc+=("${subj}")

done

#====================================================================================================================

# ***** STEP 3: copy remaining files to biowulf (if # of subj actually processed > 0) *****

if [[ ${#subj_actually_proc[@]} -eq 0 ]]; then
	echo -e "\033[0;35m++ No subjects passed data check. Removing ${wdir_name} ++\033[0m"
	ssh ${username}@biowulf.nih.gov "rm -r ${biowulf_dti_dir}/${wdir_name}"

	# delete temporary directory
	rm -r ${temp_dir}

	echo -e "\033[0;32m++ No subjects passed data check. Exiting... ++\033[0m"
	exit 1
else
	echo -e "\033[0;35m++ Copying remaining files to ${wdir_name} ++\033[0m"
	# replace some variables in _run_TORTOISE.sh and copy to temp dir
	sed -e "s/\${wdir_name}/${wdir_name}/" ${scripts_dir}/_run_TORTOISE.sh > ${temp_dir}/_run_TORTOISE.sh

	# copy files to biowulf
	scp ${temp_dir}/_run_TORTOISE.sh ${swarm_file} ${username}@helix.nih.gov:${biowulf_wdir}/.

	# delete temporary directory
	rm -r ${temp_dir}
fi

#====================================================================================================================

# ***** STEP 4: submit swarm of jobs *****

echo -e "\033[0;35m++ Submitting job... ++\033[0m"
slurm=$(ssh -XY ${username}@biowulf2.nih.gov "cd ${biowulf_wdir}; swarm -f my.swarm -g 64 -t 32 --module ${TORTOISE_version} --time 24:00:00 --job-name ${job_name}; exit")

#====================================================================================================================

# ***** STEP 5: create biowulf_proc files (indicative of which subjects have been processed in biowulf and when) *****

if [[ ${slurm} == '' ]]; then
	echo -e "\033[0;35m++ Unable to retrieve jobid. Please check to make sure script was executed on biowulf. ++\033[0m"
else
	jobout=${slurm#*-}
	jobid=${jobout%.*}
	echo -e "\033[0;35m++ Job submitted: $jobid ++\033[0m"
fi

for subj in "${subj_actually_proc[@]}"; do
	# path variables
	if [[ ${slurm} == '' ]]; then
		echo -e "$username $TORTOISE_version $run_date_clean jobid-MISSING $subj" > ${subj_dwi_dir}/biowulf_proc${folder_suffix}
	else
		echo -e "$username $TORTOISE_version $run_date_clean $jobid $subj" > ${subj_dwi_dir}/biowulf_proc${folder_suffix}
	fi
done

#====================================================================================================================

# remove key from agent
ssh-add -d ~/.ssh/id_rsa

echo -e "\033[0;32m++ Done! Please run sjobs on biowulf login node, or login to the User Dashboard on the HPC website, to check that jobs have been successfully submitted (job ID: ${jobid}) ++\033[0m"
echo -e "\033[0;32m++ The following subjects have been pushed to biowulf for TORTOISE processing: ++\033[0m"
for subj in "${subj_actually_proc[@]}"; do
	echo -e "\033[0;32m $subj \033[0m"
done
echo -e "\033[0;31m++ The following subjects have been skipped: ++\033[0m"
for subj in "${subj_skip[@]}"; do
	echo -e "\033[0;32m $subj \033[0m"
done