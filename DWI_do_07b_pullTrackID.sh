#!/bin/bash -i

#====================================================================================================================

# Author:   	Braden Yang
# Date:     	05/06/20

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h] [-m {prob|det}] ++\033[0m"
	exit 1
}

# set defaults
mode=prob

# parse options
while [ -n "$1" ]; do
    case "$1" in
    	-h|--help) display_usage ;;		# help
		-m|--mode) mode=$2; shift ;; 	# mode of tractography
	    *) 	break ;;
    esac
    shift 	# shift to next argument
done

# check that no positional parameter were given
if [ ! $# -eq 0 ]; then
	display_usage
fi

# check that mode option is either "prob" or "det"
if [[ ${mode} != "prob" ]] && [[ ${mode} != "det" ]]; then
	display_usage
fi

# warn user that jobs must be complete
echo -e "\033[0;36m++ WARNING!!! ALL biowulf jobs for ALL tractography jobs must be complete before running this script ++\
		\n++ It is advised to also check that tractography has runned as intended before pulling data ++\
		\n++ ARE ALL JOBS COMPLETE? ENTER 'y' TO PROCEED, ANYTHING ELSE TO CANCEL ++\033[0m"

read -r ynresponse
ynresponse=$(echo "$ynresponse" | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Proceeding... ++\033[0m"
else
    echo -e "\033[0;35m++ Canceled. Please run script when jobs are complete ++\033[0m"
    exit 1
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

dwi_proc_dir=$(pwd)
scripts_dir=${dwi_proc_dir}/scripts
projects_dir="${neu_dir}/Projects"

# handle -m option
if [[ ${mode} == "prob" ]]; then
	wdir_base="__WORK_PROB_TRACK"
else
	wdir_base="__WORK_DET_TRACK"
fi

# biowulf login node paths
biowulf_dwi_dir="/data/${USER}/DWI"

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source "${scripts_dir}"/all_req_check.sh -ssh

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 0: add keys to ssh-agent *****

echo -e "\033[0;35m++ Adding authentication keys to ssh-agent ... ++\033[0m"
ssh-add

#====================================================================================================================

# ***** STEP 1: find all working directories and iterate over them *****

all_wdir=($(ssh -q ${USER}@biowulf.nih.gov "ls ${biowulf_dwi_dir} | xargs printf '%s\n' | grep ${wdir_base}"))

if [[ ${#all_wdir[@]} -eq 0 ]]; then
	echo -e "\033[0;36m++ No working directories found in biowulf. Please run DTI_do_track_biowulf_push.sh. Exiting... ++\033[0m"
	exit 1
fi

for wdir_name in "${all_wdir[@]}"; do

	ls_postop=$(ssh -q ${USER}@biowulf.nih.gov "ls ${biowulf_dwi_dir}/${wdir_name} 2>&1")

	# find if preop or postop
	if echo ${ls_postop} | grep -q "postop"; then
		biowulf_wdir="${biowulf_dwi_dir}/${wdir_name}/postop"
		postop="true"
	else
		biowulf_wdir="${biowulf_dwi_dir}/${wdir_name}/preop"
		postop="false"
	fi

	echo -e "\033[0;35m++ Pulling data from ${wdir_name} ++\033[0m"

	#====================================================================================================================

	# ***** STEP 2: find all subject folders *****

	all_subj=($(ssh -q ${USER}@biowulf.nih.gov "ls ${biowulf_wdir}" | grep "\(p\|hv\)[0-9]\+"))

	#====================================================================================================================

	# ***** STEP 3: pull data *****

	# pull biowulf stdout files, store in temporary directory
	echo -e "\033[0;35m++ Pulling .o and .e files from biowulf ++\033[0m"
	temp_stdout_dir=${pwd_dir}/temp_stdout_track; mkdir ${temp_stdout_dir}
	scp -q ${USER}@helix.nih.gov:${biowulf_wdir}/*.o ${USER}@helix.nih.gov:${biowulf_wdir}/*.e ${temp_stdout_dir}

	# pull subject specific data
	for subj in "${all_subj[@]}"; do
		echo -e "\033[0;35m++ Pulling data for subject ${subj} ++\033[0m"

		# ********************** DEFINE PATHS **********************

        subj_dwi_dir=${projects_dir}/DWI/${subj}

		if [[ $postop == true ]]; then
			folder_prefix='postop_'
		else
			folder_prefix=''
		fi

		if [[ ${mode} == "prob" ]]; then
			track_mode_dir=${subj_dwi_dir}/${folder_prefix}track/prob
		else
			track_mode_dir=${subj_dwi_dir}/${folder_prefix}track/det
		fi
		temp_subj_dir=${track_mode_dir}/temp_subj; mkdir -p ${temp_subj_dir} 	# make temp_subj dir (and parent dir if necessary)

		# ********************** COPY FILES FROM BIOWULF TO SHARES **********************

		# copy track_log_temp from biowulf
		scp -q ${USER}@helix.nih.gov:${biowulf_wdir}/${subj}/track_log_temp ${temp_subj_dir}/.

		# ********************** UPDATE TRACK_LOG **********************

		# get number of ROI networks tracked (=number of lines in track_log_temp, minus header line)
		num_roi=$(tail -n +2 ${temp_subj_dir}/track_log_temp | wc -l)

		# if no track_log, set up one
		if [ ! -f ${track_mode_dir}/track_log ]; then
			if [[ ${mode} == "prob" ]]; then
				echo "track_idx run_date roi_path output_dir num_parc num_network alg_Thresh_FA alg_Thresh_ANG alg_Thresh_Len alg_Thresh_Frac alg_Nmonte ld note" >> ${track_mode_dir}/track_log
			else
				echo "track_idx run_date roi_path output_dir num_parc num_network alg_Thresh_FA alg_Thresh_ANG alg_Thresh_Len bundle_thr ld note" >> ${track_mode_dir}/track_log
			fi
		fi

		new_out=()	# initialize array to store names of newly created tractography output folders (only for echoing purposes)
		for ((i=0;i<${num_roi};i++)); do
			# count number of lines in track_log; this will determine what index will be assigned to the current ROI network
			num_line=$(cat ${track_mode_dir}/track_log | wc -l)

			# initialize idx and idx_biowulf
			let "idx=num_line-1"
			idx_biowulf=${i}

			# format idx and idx_biowulf with leading zeros
			idx_format=$(printf "%02d" "${idx}")
			idx_biowulf_format=$(printf "%02d" "${idx_biowulf}")

			# make new directory to store outputs
			wdir=${track_mode_dir}/${idx_format}; mkdir $wdir

			################## TODO: used to be track_000.* instead of * #####################
			# copy outputs from biowulf to new directory
			scp -q ${USER}@helix.nih.gov:${biowulf_wdir}/${subj}/${idx_biowulf_format}/* ${wdir}/.

			# add line in track_log_temp
			head -n $((i+2)) ${temp_subj_dir}/track_log_temp | tail -n 1 | sed -e "s:\${odir}:${wdir}:" -e "s:\${idx}:${idx}:" >> ${track_mode_dir}/track_log

			# append to new_out array
			new_out+=("${idx_format}")

			# get all (remaining) *.o (biowulf command) files from temp_stdout_dir
			all_o=$(find ${temp_stdout_dir} -mindepth 1 -maxdepth 1 -name "*.o" -type f)

			# find .o and .e file that corresponds with the current subject and ROI
			for o_file in "${all_o[@]}"; do
				# grep for subject code (include space to distinguish between similar subjects, ex. p1 and p12)
				if cat ${o_file} | grep -q -E "${subj} .*${idx_biowulf_format}"; then
					# get corresponding .e (stdout) file
					e_file="${o_file%.o}.e"

					# move both files to subject's own directory
					mv ${o_file} ${e_file} ${wdir}

					# break from current loop
					break
				fi
			done
		done

		# remove temporary (subject) directory
		rm -rf ${temp_subj_dir}

		echo -e "\033[0;32m++ Newly added tractography output directories for subject ${subj}: ++\033[0m"
		for out in "${new_out[@]}"; do
			echo -e "\033[0;32m $out \033[0m"
		done
	done

	# append all subjects from current wdir to the global list
	all_subj_total+=("${all_subj[@]}")

	#====================================================================================================================

	# ***** STEP 4: clean biowulf (remove __WORK_{mode}_TRACK) and local machine *****

	# clean up biowulf
	echo -e "\033[0;35m++ Removing ${wdir_name} from biowulf ++\033[0m"
	ssh -q ${USER}@biowulf.nih.gov "rm -r /data/${USER}/DWI/${wdir_name}"

	# remove temporary directory
	rm -r ${temp_stdout_dir}

done

#====================================================================================================================

# remove key from agent
ssh-add -d ~/.ssh/id_rsa

# get unique entries from all_subj_total
all_subj_total_u=($(printf '%s\n' "${all_subj_total[@]}" | sort -u))

echo -e "\033[0;32m++ Done! The following subjects had tractography data pulled from biowulf: ++\033[0m"
for subj in "${all_subj_total_u[@]}"; do
	echo -e "\033[0;32m $subj \033[0m"
done
echo -e "\033[0;32m++ Please check to see that their data have been successfully pulled ++\033[0m"
