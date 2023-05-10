#!/usr/bin/env python
# coding: utf-8

#====================================================================================================================

# Author:       Braden Yang, Price Withers
# Date:         11/20/19

#====================================================================================================================

# IMPORT MODULES

import argparse
from io import StringIO
from os import path

import numpy as np

#====================================================================================================================

# GET ARGUMENTS

parser = argparse.ArgumentParser(description="Parse .grid file outputed by 3dTrackID and save out individual data matrices in .npy format")
parser.add_argument("grid_path",help="path to .grid file to parse")
parser.add_argument("odir",help="output directory to save files")


args = parser.parse_args()
grid_path=args.grid_path; odir=args.odir

#====================================================================================================================

# DEFINE FUNCTIONS

def get_mat_names(grid_path):
    """
    Returns the names of each data matrix in an AFNI .grid file, specified by argument
        grid_path, as a list of string
    """
    # store names in array
    with open(grid_path,'r') as f:
        mat_name = [];
        for ln in f:
            if ln.startswith("#"):
                name = ln.split("# ")[-1]
                name = name[:-1]
                mat_name.append(name)
    # trim names
    mat_name = mat_name[3:]
    
    return mat_name


def get_mat_data(grid_path):
    """
    Returns a list of numpy ndarrays containing each matrix from an AFNI .grid file
        specified by argument grid_path
    """
    # load .grid into ndarray
    my_data = np.loadtxt(
        fname=grid_path,
        dtype=str,
        comments="#"
    )

    # split ndarray into header and body
    # hdr = my_data[:2]
    bdy = my_data[2:].astype(float)

    # reshape into 2D array if bdy is a vector
    if bdy.ndim == 1:
        bdy = np.reshape(bdy,(bdy.shape[0],1))

    # split body further into subarrays
    bdy_split = np.split(bdy,range(bdy.shape[1],bdy.shape[0],bdy.shape[1]))
    
    return bdy_split

def save_data_dict(data,names,odir):
    """
    Turns a list of names and a list of ndarrays into a dictionary, where key = name
        and value = ndarray, then saves dictionary as .npy file in odir using numpy.save
    """
    data_dict = dict(zip(names,data))
    np.save(path.join(odir,"all_data"),data_dict)

def save_labels(grid_path,odir):
    """
    Saves a 1D np.array containing a list of ROI labels
    """
    with open(grid_path,'r') as fp:
        for i,line in enumerate(fp):
            if i == 3: break

    np.savetxt(
        fname = path.join(odir,"roi_labels.txt"),
        X = np.loadtxt(StringIO(line), dtype=str),
        fmt = '%s'
    )

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 1: parse .grid file *****

# get data
data = get_mat_data(grid_path)
# get names
names = get_mat_names(grid_path)

#====================================================================================================================

# ***** STEP 2: compute binary connectivity matrix *****

# get SC matrix by thresholding NT matrix
sc_mat = (data[0] > 0).astype(int)
# append SC matrix to data list
data.append(sc_mat)
# append "SC_bin" to name list
names.append("SC_bin")

#====================================================================================================================

# ***** STEP 3: save all data as a .npy formatted dictionary *****

# save data dictionary as .npy
save_data_dict(data,names,odir)

#====================================================================================================================

# ***** STEP 4: save ROI labels *****

save_labels(grid_path,path.dirname(odir))

#====================================================================================================================
