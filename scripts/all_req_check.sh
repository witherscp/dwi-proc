#!/bin/bash

#====================================================================================================================

# Author:   	Braden Yang
# Date:     	03/17/20

#====================================================================================================================

# PARSE OPTIONS

afni=false; x11=false; conda=false; p3=false; ssh=false; # set defaults
while [ -n "$1" ]; do
	# check case; if valid option found, toggle its respective variable on
    case "$1" in
	    -afni) 	afni=true ;; 	# AFNI
	    -x11) 	x11=true ;; 	# X11
		-conda)	conda=true ;; 	# Anaconda and python2.7 environment
		-p3) 	p3=true ;;		# Python 3
		-ssh) 	ssh=true ;;		# ssh key-pair authentication
	    *) 		break ;; 		# break
    esac
    shift 	# shift to next argument
done

#--------------------------------------------------------------------------------------------------------------------

# CHECK FOR SOFTWARES AND CONFIGURATIONS

# AFNI
if [[ $afni == "true" ]]; then
	afni_path=`which afni`
	if [ "${afni_path}" == '' ]; then
		echo -e "\033[0;36m++ AFNI not installed. Please run this script on a different computer or install AFNI. Exiting... ++\033[0m"
		exit 1
	fi
fi

# X11 - AFNI GUI SOFTWARE
if [[ $x11 == "true" ]]; then
	x11_dir=`which Xvfb`
	if [ "${x11_dir}" == '' ]; then
		echo -e "\033[0;36m++ Xvfb not found. Please run this script on a different computer or install X11. Exiting... ++\033[0m"
		exit 1
	fi
fi

# ANACONDA AND PYTHON 2.7 ENV(var conda)
if [[ $conda == "true" ]]; then
	conda_dir=`conda info --base`
	if [ ! -d "${conda_dir}/envs/p2.7" ] && [ ! -d "$HOME/.conda/envs/p2.7" ]; then
		echo -e "\033[0;36m++ Conda environment p2.7 does not exist. Please run 'conda create -n p2.7 python=2.7'. Exiting... ++\033[0m"
		exit 1
	fi
fi

# PYTHON 3
if [[ $p3 == "true" ]]; then
	if [[ ! $(python -V) =~ Python[[:blank:]]3.* ]]; then
		echo -e "\033[0;36m++ Python 3 not found. Please run this script on a different computer or install Python 3. Exiting... ++\033[0m"
		exit 1
	fi
fi

# SSH KEY-PAIR AUTHENTICATION
if [[ $ssh == "true" ]]; then
	if [ ! -f ~/.ssh/id_rsa ]; then
		echo -e "\033[0;36m++ An ssh public/private key was not generated. See https://hpc.nih.gov/docs/sshkeys.html on how to set up key-pair authentication for biowulf. Exiting... ++\033[0m"
		exit 1
	fi
fi
