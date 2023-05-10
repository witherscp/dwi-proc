#!/usr/bin/env python

#====================================================================================================================

# Name:         _get_labels_1D.py

# Author:       Braden Yang
# Date:         05/12/20
# Updated:      05/18/20

# usage: _get_labels_1D.py [-h] [-a APPEND_LABTAB_STR]
#                          orig_labtab_str outfile
#                          [append_roi_idx [append_roi_idx ...]]

# Get a 1D file of the original ROI labels, plus an added set of ROIs appended
# to the end of the original

# positional arguments:
#   orig_labtab_str       string of the original ROI network's labeltable
#                         (outputted by '3dinfo -labeltable ${roi}')
#   outfile               path to write 1D file
#   append_roi_idx        list of ROI indices in the append ROI network to
#                         select for to be included in the 1D file; must appear
#                         in the order that they will be renumbered

# optional arguments:
#   -h, --help            show this help message and exit
#   -a APPEND_LABTAB_STR, --append_labtab_str APPEND_LABTAB_STR
#                         string of the ROI network to append's labeltable
#                         (outputted by '3dinfo -labeltable ${roi}')

# Main outputs: outfile
# Requirements: Python 3
# Notes:        - Called in DTI_do_cat_subctx.sh, DTI_do_surf2vol.sh, and DTI_do_FS_roi.sh

# Change log:
# 	- BYY 05/18/20: made appending additional rows to 1D optional

#====================================================================================================================

# IMPORT MODULES

import argparse
from io import StringIO
import re

import numpy as np
import pandas as pd

#====================================================================================================================

# GET ARGUMENTS

parser = argparse.ArgumentParser(description="Get a 1D file of the original ROI labels, plus an added set of ROIs appended to the end of the original")
parser.add_argument("orig_labtab_str",help="string of the original ROI network's labeltable (outputted by '3dinfo -labeltable ${roi}')")
parser.add_argument("outfile",help="path to write 1D file")
parser.add_argument("append_roi_idx",nargs='*',help="list of ROI indices in the append ROI network to select for to be included in the 1D file; must appear in the order that they will be renumbered")
parser.add_argument("-a", "--append_labtab_str",help="string of the ROI network to append's labeltable (outputted by '3dinfo -labeltable ${roi}')")

args = parser.parse_args()

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# ***** STEP 1: load labeltables as pandas DataFrames and sort *****

# initialize regular expression (removes HTML-style tags)
re_expr 	 = re.compile(r'<[^>]*>')

# load original labeltable as DataFrame
orig_clean   = re.sub(re_expr, '', args.orig_labtab_str)
orig_df = pd.read_csv(StringIO(orig_clean), header=None, delim_whitespace=True)
orig_df.sort_values(by=0, inplace=True, ignore_index=True)

if (len(args.append_roi_idx) != 0) and (args.append_labtab_str != None):
	# load labeltable to append as DataFrame
	append_clean = re.sub(re_expr, '', args.append_labtab_str)
	append_df = pd.read_csv(StringIO(append_clean), header=None, delim_whitespace=True)
	append_df.sort_values(by=0, inplace=True, ignore_index=True)

#====================================================================================================================

# ***** STEP 2: select rows in append_df and append to end of orig_df *****

if (len(args.append_roi_idx) != 0) and (args.append_labtab_str != None):
	# get rows to append from append_df
	my_list 	   = [*map(int,args.append_roi_idx)] 						 # convert list of ROI indices to integers
	roi_idx_col    = append_df[0].values 									 # get ROI indices column as np array
	rows_to_select = [np.where(roi_idx_col == i)[0][0] for i in my_list] 	 # get list of row indices
	rows_to_append = append_df.iloc[rows_to_select,:].reset_index(drop=True) # get rows to append

	# renumber rows
	max_idx 	   	  = orig_df[0].max() 							# get max index of original
	rows_to_append[0] = rows_to_append.index.values + max_idx + 1 	# start at max_idx+1, increment by 1

	# append rows to orig_df
	orig_df = orig_df.append(rows_to_append, ignore_index=True)

#====================================================================================================================

# ***** STEP 3: Save new_df as 1D *****

orig_df.to_csv(args.outfile, sep=" ", header=False, index=False)

#====================================================================================================================
