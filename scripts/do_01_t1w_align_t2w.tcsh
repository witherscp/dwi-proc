#!/bin/tcsh

# PA Taylor, NIMH (Jan, 2016)

# for doing a solid-body alignment of a T2w volume to a T1w volume.

# Change log:
#   - BYY 08/03/20: converted in_inp and in_ref as arguments instead of
#     hard-coded variables; added a few comments

# ==============================================================

# going to assume that these have similar contrast
set in_inp = $argv[1]
set in_ref = $argv[2]

# set in_inp = "t2.nii"    # the T2, to move
# set in_ref = "t1.nii"    # the T1, to stay

# --------------------------------------------------------------

set here = $PWD
set wdir = "__WORK_T2toT1"

set my_inp = "t2w_00.nii.gz"
set my_inp_thr = "t2w_01_thr.nii.gz"
set map_base = "$my_inp_thr:gas/.nii.gz//"  # transform base name
set my_inp_out = "t2w_02_FINAL.nii"      # main OUTPUT file

set my_ref_uni = "t1w_01_uni.nii.gz"
set my_ref_uni_thr = "t1w_02_uni_thr.nii.gz"

set ref_ORIENT = `3dinfo -orient "$in_ref"`
set ref_SPACE = `3dinfo -space "$in_ref"`

# ==============================================================
# ==============================================================

# make the working directory
if ( ! -e $wdir ) then
    mkdir $wdir
endif

# ----------------------------------------------------------------------

# uniformize both white and gray matters of the T1 (done to prepare image for registration)
3dUnifize                            \
    -GM                              \
    -prefix "$wdir/$my_ref_uni"      \
    -input  "$in_ref"                \
    -overwrite 

# get the 95th percentile value of the unifized T1 (masked)
set v1 = `3dBrickStat -automask -percentile 95 1 95 "$wdir/$my_ref_uni"`
echo ${v1[2]}

# threshold values that fall above the 95th percentile (i.e. replace values higher than 95th pctl with the 95th pctl)
3dcalc -a "$wdir/$my_ref_uni"          \
       -expr "maxbelow(${v1[2]},a)"    \
       -prefix "$wdir/$my_ref_uni_thr" \
       -overwrite

# ----------------------------------------------------------------------

# copy inp here, while also making orientation match ref
3dresample                   \
    -orient "$ref_ORIENT"    \
    -prefix "$wdir/$my_inp"  \
    -inset  "$in_inp"        \
    -overwrite

# so sets can be overlayed
3drefit                      \
    -space "$ref_SPACE"      \
    "$wdir/$my_inp"

# cd to working directory
cd $wdir

# put a ceiling to avoid spikes/blips
set v1 = `3dBrickStat -automask -percentile 95 1 95 "$my_inp"`
echo ${v1[2]}
3dcalc -a "$my_inp"                        \
       -expr "maxbelow(${v1[2]},a)"        \
       -prefix "$my_inp_thr"               \
       -overwrite

# because centers may be far apart: t2w -> t1w
@Align_Centers -no_cp                  \
    -base "$my_ref_uni_thr"            \
    -1Dmat_only                        \
    -dset "$my_inp_thr"

# ----------------------------------------------------------

# send t2w -> t1w, don't resample
align_epi_anat.py                            \
    -dset1 "$my_inp_thr"                     \
    -dset2 "$my_ref_uni_thr"                 \
    -cost lpc                                \
    -dset1_strip 3dAutomask                  \
    -dset2_strip 3dSkullStrip                \
    -dset1to2                                \
    -Allineate_opts "-twopass -warp shift_rotate -nomask"  \
    -deoblique off                           \
    -resample off                            \
    -overwrite

# combine the shift of AlignCentering the dsets with the solid body
# transform
cp  ${map_base}_shft.1D                \
    ${map_base}_shft.aff12.1D 
cat_matvec -ONELINE                    \
    ${map_base}_al_mat.aff12.1D        \
    ${map_base}_shft.aff12.1D          \
    > map_T2_to_T1.aff12.1D 

# apply combined recentering+solid body transform to T2
3dAllineate                                 \
    -1Dmatrix_apply map_T2_to_T1.aff12.1D   \
    -base "$my_ref_uni_thr"                 \
    -source "$my_inp"                       \
    -prefix "$my_inp_out"                   \
    -overwrite
