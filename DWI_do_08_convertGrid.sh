#!/bin/bash

#====================================================================================================================

# Author:   	Braden Yang, Price Withers
# Date:     	11/20/19

#====================================================================================================================

# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h] [-p] [-m {prob|det}] SUBJ ++\033[0m"
	exit 1
}

# set defaults
postop=false; mode=prob

# parse options
while [ -n "$1" ]; do
	# check case; if valid option found, toggle its respective variable on
    case "$1" in
    	-h|--help) 		display_usage ;;	# help
	    -p|--postop) 	postop=true ;; 		# post-op
		-m|--mode) 		mode=$2; shift ;; 	# mode of tractography
	    *) 				subj=$1; break ;; 	# subject code (prevent any further shifting by breaking)
    esac
    shift 	# shift to next argument
done

# check that only one parameter was given (subj)
if [ ! $# -eq 1 ]; then
	display_usage
fi

# check that mode option is either "prob" or "det"
if [[ ${mode} != "prob" ]] && [[ ${mode} != "det" ]]; then
	display_usage
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

pwd_dir=$(pwd)
scripts_dir=${pwd_dir}/scripts

if [[ $postop == 'true' ]]; then
	folder_prefix='postop_'
else
	folder_prefix=''
fi
#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

source "${scripts_dir}"/all_req_check.sh -p3

#--------------------------------------------------------------------------------------------------------------------

# DATA CHECK

subj_dwi_dir=$neu_dir/Projects/DWI/$subj
track_mode_dir=${subj_dwi_dir}/${folder_prefix}track/${mode}

# track dir
if [ ! -d "${track_mode_dir}" ]; then
	echo -e "\033[0;36m++ Subject ${subj} does not have ${folder_prefix}track/${mode} directory. Please run DWI_do_07[a-b].sh. Exiting... ++\033[0m"
	exit 1
fi

echo -e "\033[0;35m++ Working on subject ${subj}... ++\033[0m"

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 1: Search for all .grid file paths in the subject's track directory *****

grid_list=( $(find "${track_mode_dir}" -mindepth 2 -maxdepth 2 -type f -name "*.grid") )

#====================================================================================================================

# ***** STEP 2: Iterate through all .grid files and save individual data matrices as CSV files *****

# iterate through all elements in grid_list
for grid_path in "${grid_list[@]}"; do
	# get upper directory name
	grid_dir=$(dirname ${grid_path})

	# make dir to store CSVs
	csv_dir=${grid_dir}/csv
	if [ ! -d $csv_dir ]; then
		mkdir $csv_dir
	fi

	# check for existence of files; if not, then call do_save_grid.py
	if [ ! -f "${csv_dir}"/all_data.npy ]; then
		echo -e "\033[0;35m++ Working on ${grid_path} ++\033[0m"
		python3 "${scripts_dir}"/do_save_grid_as_npy.py "${grid_path}" "${csv_dir}"
	fi

	if [ ! -f "${csv_dir}"/SC_bin.csv ]; then
		python3 "${scripts_dir}"/do_save_npy_as_csv.py "$subj" 'SC_bin'
	fi

	if [ ! -f "${csv_dir}"/BL.csv ]; then
		python3 "${scripts_dir}"/do_save_npy_as_csv.py "$subj" 'BL'
	fi

	if [ ! -f "${csv_dir}"/sBL.csv ]; then
		python3 "${scripts_dir}"/do_save_npy_as_csv.py "$subj" 'sBL'
	fi

done

#====================================================================================================================

echo -e "\033[0;32m++ Done! Please check outputs in ${track_mode_dir}/??/csv ++\033[0m"
