#!/bin/bash

#===================================================================================================================

# Name: 		DTI_do_setupBiowulf.sh

# Author:   	Katie Snyder
# Date:     	05/01/19
# Updated:      07/15/20

# Syntax:       ./DTI_do_setupBiowulf.sh
# Arguments:    --
# Description:  Sets up biowulf account for user so that it can run biowulf DTI scripts.
# Requirements: 1) Biowulf account
# Notes:		- This script requires you to enter your biowulf password mutliple times
# 				- One may also choose to set up SSH public key authentication for biowulf. This is required in order
# 				  to run biowulf push/pull scripts (such as DTI_do_TORTOISE_biowulf_{push,pull}.sh)
# 					- Save the key files at the default filepath (~/.ssh/id_rsa)
# 					- Choose a passphrase that is long but easy to remember
# 					- DO NOT USE YOUR NIH PASSWORD AS YOUR PASSPHRASE
# 					- For more information, refer to the following biowulf webpage: https://hpc.nih.gov/docs/sshkeys.html

# Change log:
# 	- BYY 07/15/20: added SSH public key authentication setup

#===================================================================================================================

# VARIABLES

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     neu_dir="/shares/NEU";;
    Darwin*)    neu_dir="/Volumes/Shares/NEU";;
    *)          echo -e "\033[0;35m++ Unrecognized OS. Must be either Linux or Mac OS in order to run script. \
						 Exiting... ++\033[0m"; exit 1
esac

username=$( basename $HOME )

top_biowulf_scripts=${neu_dir}/Scripts_and_Parameters/biowulf
biowulf_scripts=${top_biowulf_scripts}/DTI_files

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: setup biowulf account

echo -e "\033[0;36m++ Would you like to copy .bash_profile and .bashrc files? Enter 'y' to copy ++\033[0m"
read -r ynresponse
ynresponse=$(echo "$ynresponse" | tr '[:upper:]' '[:lower:]')
if [ "$ynresponse" == "y" ]; then
	echo -e "\033[0;35m++ Copying profile files... ++\033[0m"
	scp ${top_biowulf_scripts}/biowulf_bash_profile ${username}@biowulf2.nih.gov:/home/${username}/.bash_profile
	scp ${top_biowulf_scripts}/biowulf_bashrc ${username}@biowulf2.nih.gov:/home/${username}/.bashrc
fi

#--------------------------------------

echo -e "\033[0;35m++ Linking data directories and creating DTI directories... ++\033[0m"
ssh -XY ${username}@biowulf2.nih.gov "mkdir -p /data/${username}/DTI; mkdir -p /data/${username}/Scripts/__completeJobs; exit"

#--------------------------------------

echo -e "\033[0;35m++ Copying scripts and files to biowulf... ++\033[0m"
scp ${biowulf_scripts}/TORTOISE_biowulf.sh ${biowulf_scripts}/TORTOISE_biowulf_swarm.sh ${biowulf_scripts}/TORTOISE.swarm ${username}@biowulf2.nih.gov:/data/$username/Scripts/.
scp -r ${biowulf_scripts}/DIFF_PREP_WORK ${username}@biowulf2.nih.gov:/home/${username}/.

#====================================================================================================================

# STEP 2: set up key-pair authentication

# check if key doesn't exist
echo -e "\033[0;36m++ Would you like to set up SSH public key authentication for biowulf? (required in order to run biowulf push/pull scripts) ++\033[0m"
echo -e "\033[0;36m++ This requires creating a passphrase to access the private key (IMPORTANT: must be different from your NIH password) ++\033[0m"
echo -e "\033[0;36m++ For more information, refer to the following biowulf webpage: https://hpc.nih.gov/docs/sshkeys.html *****\033[0m"
echo -e "\033[0;36m++ Enter 'y' to proceed, anything else to cancel *****\033[0m"
read -r ynresponse
ynresponse=$(echo "$ynresponse" | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Generating SSH keys ++\033[0m"
    echo -e "\033[0;35m++ Save the key file at the default filepath (~/.ssh/id_rsa) ++\033[0m"
    echo -e "\033[0;35m++ Choose a passphrase that is long but easy to remember ++\033[0m"
    echo -e "\033[0;35m++ DO NOT USE YOUR NIH PASSWORD AS YOUR PASSPHRASE ++\033[0m"
    ssh-keygen -t rsa -b 4096
    sleep 1

    echo -e "\033[0;35m++ Copying public key to biowulf; please enter your biowulf password (not passphrase) ++\033[0m"
    scp ~/.ssh/id_rsa.pub ${USER}@helix.nih.gov:~/tmp

    echo -e "\033[0;35m++ Finalizing key generation; please enter your biowulf password (not passphrase) ++\033[0m"
    ssh "${USER}@helix.nih.gov" "cat ~/tmp >> ~/.ssh/authorized_keys; rm ~/tmp; chmod 0600 ~/.ssh/authorized_keys"
fi

#====================================================================================================================

echo -e "\033[0;32m++ Biowulf setup complete, have a nice day! ++\033[0m"
