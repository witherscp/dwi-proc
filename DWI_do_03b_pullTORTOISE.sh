#!/bin/bash

#====================================================================================================================

# Author:   	Price Withers, Kayla Togneri, Braden Yang
# Date:     	04/27/23

#====================================================================================================================

# INPUTS

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h] ++\033[0m"
	exit 1
}

# parse options
while [ -n "$1" ]; do
	# check case; if valid option found, toggle its respective variable on
    case "$1" in
    	-h|--help) 	display_usage ;;	# help
	    *) 			break ;;
    esac
    shift 	# shift to next argument
done

# check that no positional parameter were given
if [ ! $# -eq 0 ]; then
	display_usage
fi

# warn user that jobs must be complete
echo -e "\033[0;36m++ WARNING!!! All biowulf jobs for TORTOISE must be complete before running this script ++\
		\n++ It is advised to also check that TORTOISE processing has runned as intended before pulling data ++\
		\n++ ARE JOBS COMPLETE? ENTER 'y' TO PROCEED, ANYTHING ELSE TO CANCEL ++\033[0m"

read -r ynresponse
ynresponse=$(echo "$ynresponse" | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Proceeding... ++\033[0m"
else
    echo -e "\033[0;35m++ Canceled. Please run script when jobs are complete ++\033[0m"
    exit 1
fi

#-------------------------------------------------------------------------------------------------------------------

# VARIABLES AND PATHS

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     neu_dir="/shares/NEU";;
    Darwin*)    neu_dir="/Volumes/Shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be either Linux or Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

# define paths
pwd=$(pwd)
scripts_dir=$pwd/scripts

# other variables
username=${USER}

# biowulf login node paths
biowulf_dwi_dir="/data/${username}/DWI"

dwi_proc_dir=$(pwd)
scripts_dir=${dwi_proc_dir}/scripts
#---------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source "${scripts_dir}"/all_req_check.sh -ssh

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 0: add keys to ssh-agent *****

echo -e "\033[0;35m++ Adding authentication keys to ssh-agent ... ++\033[0m"
ssh-add

#====================================================================================================================

all_wdir=($(ssh -q ${username}@biowulf.nih.gov "ls ${biowulf_dwi_dir} | xargs printf '%s\n' | grep __WORK_TORTOISE"))

if [[ ${#all_wdir[@]} -eq 0 ]]; then
	echo -e "\033[0;36m++ No working directories found in biowulf. Please run DWI_do_03a_pushTORTOISE.sh. Exiting... ++\033[0m"
	exit 1
fi

for wdir_name in "${all_wdir[@]}"; do

	ls_postop=$(ssh -q ${USER}@biowulf.nih.gov "ls ${biowulf_dwi_dir}/${wdir_name} 2>&1")

	# find if preop or postop
	if echo ${ls_postop} | grep -q "postop"; then
		biowulf_wdir="${biowulf_dwi_dir}/${wdir_name}/postop"
		folder_prefix='postop_'
	else
		biowulf_wdir="${biowulf_dwi_dir}/${wdir_name}/preop"
		folder_prefix=''
	fi

	echo -e "\033[0;35m++ Pulling data from ${wdir_name} ++\033[0m"

	# ***** STEP 1: find all subject folders *****

	all_subj=($(ssh ${username}@biowulf.nih.gov "ls ${biowulf_wdir}" | grep "\(p\|hv\)[0-9]\+"))

	#====================================================================================================================

	# ***** STEP 2: pull data *****

	# pull biowulf stdout files, store in temporary directory
	echo -e "\033[0;35m++ Pulling .o and .e files from biowulf ++\033[0m"
	temp_stdout_dir=${scripts_dir}/temp_stdout_TORTOISE; mkdir ${temp_stdout_dir}
	scp ${username}@helix.nih.gov:${biowulf_wdir}/*.o ${username}@helix.nih.gov:${biowulf_wdir}/*.e ${temp_stdout_dir}

	# pull subject specific data
	for subj in "${all_subj[@]}"; do
		echo -e "\033[0;35m++ Pulling data for subject ${subj} ++\033[0m"

		# ********************** DEFINE PATHS **********************

		subj_dwi_dir=$neu_dir/Projects/DWI/$subj
		drbuddi_dir=${subj_dwi_dir}/${folder_prefix}drbuddi

		# ********************** COPY FILES FROM BIOWULF TO SHARES **********************

		if [ -f "${drbuddi_dir}/buddi.nii" ] && [ -f "${drbuddi_dir}/buddi.bmtxt" ] && [ -f "${drbuddi_dir}/structural.nii" ]; then
			echo -e "\033[0;35m++ Data already copied from biowulf for subject $subj. Continuing... ++\033[0m"
			continue
		else
			scp -r ${username}@helix.nih.gov:${biowulf_wdir}/${subj}/${folder_prefix}drbuddi ${subj_dwi_dir}/.
			scp -r ${username}@helix.nih.gov:${biowulf_wdir}/${subj}/${folder_prefix}diffprep ${subj_dwi_dir}/${folder_prefix}diffprep_postproc
		fi

		# ********************** MOVE STDOUT FILES **********************

		# get .e and .o files from temp_stdout_dir
		all_o=$(find ${temp_stdout_dir} -mindepth 1 -maxdepth 1 -name "*.o" -type f)

		# iterate over .o files
		for o_file in "${all_o[@]}"; do
			# grep for subject code (include space to distinguish between similar subjects, ex. p1 and p12)
			subj_check=$(grep " ${subj} " "$o_file")
			if [[ $subj_check != '' ]]; then
				# get corresponding .e (stdout) file
				e_file="${o_file%.o}.e"

				# move both files to subject's own directory
				mv ${o_file} ${e_file} ${drbuddi_dir}

				break
			fi
		done

		echo -e "\033[0;32m++ Successfully pulled diffprep_postproc and drbuddi data for subject ${subj} ++\033[0m"
	done

	# append all subjects from current wdir to the global list
	all_subj_total+=("${all_subj[@]}")

	#====================================================================================================================

	# ***** STEP 3: clean biowulf (remove __WORK_TORTOISE_??) and local machine *****

	# clean up biowulf
	echo -e "\033[0;35m++ Removing ${wdir_name} from biowulf ++\033[0m"
	ssh ${username}@biowulf.nih.gov "rm -r /data/${username}/DWI/${wdir_name}"

	# remove temporary directory
	rm -r ${temp_stdout_dir}

done

#====================================================================================================================

# remove key from agent
ssh-add -d ~/.ssh/id_rsa

# get unique entries from all_subj_total
all_subj_total_u=($(printf '%s\n' "${all_subj_total[@]}" | sort -u))

echo -e "\033[0;32m++ Done! The following subjects had DRBUDDI data pulled from biowulf: ++\033[0m"
for subj in  "${all_subj_total_u[@]}"; do
	echo -e "\033[0;32m $subj \033[0m"
done
echo -e "\033[0;32m++ Please check to see that their data have been successfully pulled ++\033[0m"