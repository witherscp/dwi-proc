#!/usr/bin/env python
# coding: utf-8

#====================================================================================================================

# Name:         do_save_npy_as_csv.py

# Author:       Braden Yang, Price Withers
# Date:         06/02/20

#====================================================================================================================

# IMPORT MODULES

import argparse
import glob
from os import path
import sys

import numpy as np

#====================================================================================================================

# GET ARGUMENTS

parser = argparse.ArgumentParser(description="Save a single CSV from all_data.npy")
parser.add_argument("subj",help="subject code")
parser.add_argument("stat",nargs="+",choices=['NT','fNT','PV','fNV','NV','BL','sBL','NTpTarVol','NTpTarSA','NTpTarSAFA','FA','sFA','MD','sMD','L1','sL1','RD','sRD','SC_bin'],help="name(s) of structural connectivity statistic(s)")
parser.add_argument("-m","--mode",choices=["prob","det"],default="prob",help="mode of tractography")

group = parser.add_mutually_exclusive_group()
group.add_argument("-r","--reformat",action="store_true",help="work on data in 'reformat' directory")
group.add_argument("-a","--alphabetical",action="store_true",help="work on data in 'alphabetical' directory")

args = parser.parse_args()

#====================================================================================================================

# DEFINE FUNCTIONS

def load_all_data_npy(filepath):
    """
    Reads a .npy file containing a dictionary of data matrices; returns the data as
        a dictionary

    Parameters
    ----------
    filepath: str
        String path to .npy file to load

    Returns
    ----------
    dict
        Dictionary containing data matrices
    """
    return np.load(filepath,allow_pickle=True).item()

def save_data_csv(data, stat_list, odir):
    """
    Saves matrix data into individual .csv files to output directory odir
    """
    for stat in stat_list:
        mat = data[stat]
        mat[np.diag_indices(mat.shape[0])] = 0
        if stat == "SC_bin":
            np.savetxt(fname=path.join(odir,f"{stat}.csv"), 
                       X=mat, delimiter=",", fmt="%d")
        elif (stat == "BL") or (stat == "sBL"):
            np.savetxt(path.join(odir, f"{stat}.csv"),
                        X=mat, fmt='%.2f', delimiter=",")
        else:
            np.savetxt(fname = path.join(odir,f"{stat}.csv"),
                       X=mat, delimiter = ",")

#====================================================================================================================

# DEFINE VARIABLES

# check OS
if sys.platform == "darwin":
    neu_dir = "/Volumes/Shares/NEU"
elif sys.platform == "linux":
    neu_dir = "/shares/NEU"
else:
    print(f"++ Unrecognized OS '{sys.platform}'; please run on either Linux or Mac OS ++")
    sys.exit()

# define paths
projects_dir = path.join(neu_dir, "Projects")
dti_subj_dir = path.join(projects_dir,f"DWI/{args.subj}")     # subject's DTI data dir
track_dir    = path.join(dti_subj_dir,f"track/{args.mode}") # track dir in subject's DTI dir

# get list of stats to save as individual CSVs
stat_list = args.stat

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 1: find all directories to work on *****

odir_list = glob.glob(path.join(track_dir, '[0-9][0-9]'))

#====================================================================================================================

# ***** STEP 2: iterate over all output directories and save individual CSVs from all_data.npy *****

for odir in odir_list:
    # define working directory
    if args.reformat:
        wdir = path.join(odir, "csv/reformat")
    elif args.alphabetical:
        wdir = path.join(odir, "csv/alphabetical")
    else:
        wdir = path.join(odir, "csv")

    # DATA CHECK: check for existence of all_data.npy
    all_data_path = path.join(wdir, "all_data.npy")
    if not path.exists(all_data_path):
        print(all_data_path)
        continue

    print(f"++ Working on {wdir} ++")

    # load all_data.npy
    all_data_dict = load_all_data_npy(all_data_path)

    # extract CSVs
    save_data_csv(all_data_dict, stat_list, wdir)

#====================================================================================================================

print(f"++ Done! Please check outputs in {track_dir} ++")
