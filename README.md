DTI processing pipeline -- updated 5/18/2023

1.  **DTI_do_01a_regT2.sh** -- align (axialize) research T2 to clinical
    *niceified* T1

    a.  User may also choose to align the clinical T2 to the T1, instead
        of the research T2, in this script (use option \--clinical)

2.  **(QC) DTI_do_01b_QC.sh** -- quality check T2-T1 registration

    a.  If alignment has failed, a second registration script can be run

        i.  To check the quality of the second registration, rerun this
            script after the second registration script has completed

        ii. If the first registration is off by a huge shift/rotation,
            then the second registration usually won't help that much,
            and so probably best to move straight to manual
            correction

    b.  If second registration failed, please manually correct the
        alignment. See the *Notes* section below for instructions on
        manual correction of the alignment

3. **DTI_do_02_filterVols.sh** -- select the good volumes, remove the bad
    volumes

    a.  The first positional argument is the subject code; the second
        positional argument is the string containing the list of good
        volumes indices to be kept for further processing

    b.  List of good volume indices should be in AFNI integer range
        format

    c.  4D image viewer with all 42 slices created, any bad slices 
        need to be selected out by clicking on each bad slice and 
        indicating "bad slice" in the GUI. 

    d.  Will make a list of all bad slices once selected, confirm and
        finish selection in GUI. 
4. **(QC) Manual QC of DWI volumes for interleaved slice motion
    artifact**

    a.  Navigate to subject's DTI folder, cd to reg

    b.  run command afni blip_up_proc/blip_up.nii and afni
        blip_down_proc/blip_down.nii to open DWIs in AFNI for manual QC

    c.  Focus on the sagittal image; make note of volumes that have
        noticeable striations (indicative of subject motion)

    d.  To switch between volumes, click the up/down arrows right by
        "Index" in the AFNI main window

    e.  Make note of which bad volumes need to be removed (step 6)

        i.  Remember that volume indices start at 0!

5.  **DTI_do_03a_pushTORTOISE.sh** -- run TORTOISE
    ImportDICOM on biowulf to convert DICOM DWIs to NIfTI format and get gradient files

    a.  Make sure that gradient files are imported correctly into
        biowulf (especially for GE scans); there should be 45 rows
        containing vectors with magnitudes of roughly 0, 200, 500 and
        1100
    b.  Will then check for DWI directory presence and if subj is already
        being processed

    c.  Run TORTOISE DIFFPREP and DRBUDDI on biowulf to correct for eddy 
        current, EPI, and other distortions.

    d.  This script will create a folder called 'diffprep' in the
        subject's DTI projects directory, which contains all necessary
        files for TORTOISE processing on biowulf

    e.  Submits swarm of jobs to Biowulf

    c.  **NOTE**: to make life easier, set up SSH public key
        authentication for biowulf prior to running any biowulf scripts;
        that way, you only need to enter your passcode only once, and
        not every time there is an SSH command in the script

        i.  Please review the following webpage before setting up SSH
            public key authentication:
            <https://hpc.nih.gov/docs/sshkeys.html>

        ii. To set this up, first ensure that you have access to a
            biowulf account; then run the script DTI_do_setupBiowulf.sh
            and follow the prompts

    d.  **NOTE**: it is recommended that you run this script in Linux

6.  **DTI_do_03b_pullTORTOISE.sh** -- Pulls stdout files for storage 
    in a temporary directory, collects data and makes .e and .o files, 
    drbuddi and moves data to patient directories
    a.  
        i.  WARNING: pull scripts permanently delete their respective
            working directories in biowulf (usually named \_\_WORK\_\*);
            therefore, the user is advised to log onto biowulf and check
            that jobs have fully completed without error before running
            pull

    b.  **NOTE**: it is recommended that you run this script in Linux

7.  **DTI_do_04_DTparams.sh** -- estimate diffusion tensors

    a.  This script will run AFNI's fat_proc_dwi_to_dt to fit diffusion
        tensors to the DWI data, and output files to the folder called
        'DTparams'

8. **(QC) DTI_do_05_indt.sh** -- manual QC of DEC maps, then brings
    surface and volumetric parcellation data into diffusion tensor space

    a.  This script makes it so that certain datasets such as volumetric
        ROI datasets and surface-based parcellations can be used with
        the diffusion data to do further processing, such as streamline
        tractography

    b.  Datasets that are mapped to DT space includes FreeSurfer's
        Desikan-Killiany volumetric atlas, cortical grey matter ribbon
        NIFTI files, freesurfer standard surfaces, Brainnetome parcellations, 
        and Schaefer surface parcellations

    c.  This uses the std 141 mesh because this is the highest
        resolution mesh and must be used for research purposes

    d.  Finally, this moves the FS ROI files into the indt directory within 
        the subject directory

9. **DTI_do_06_schaefer.sh** -- extends Schaefer surface
    parcellations into the volumetric space, grows ROIs up to the point
    of FA=0.2, and merges hemispheres for tractography

    a.  First calls AFNI's \@surf_to_vol_spackle to convert all Schaefer
        surface parcellations into volumetric ROIs that fill the
        cortical ribbon space

    b.  Then runs AFNI's 3dROIMaker to inflate the ROIs along the FA
        skeleton to prepare it for tractography

    c.  Outputs are stored in the directory named 'roi'

10. **DTI_do_07a_pushTrackID.sh** and **DTI_do_07b_pullTrackID.sh**-- 
    run streamline tractography on biowulf

    a.  This script requires the user to input a metadata file
        containing tractography parameters as well as a list of ROI
        files to use for tractography

        i.  Refer to track_opt_default for an example of what the
            metadata file should look like, which can be found in the
            \_\_files directory of DTI_scripts

        ii. List the names of all ROI files to use for tractography in
            the *my_roi* variable; this should be in bash array syntax

            1.  This script will look in the subject's 'roi' directory
                for the ROI files; ensure that all ROI filenames that
                you list in *my_roi* exist within the 'roi' directory

        iii. Specify tractography parameters as separate variables;
             refer to the documentation of AFNIs 3dTrackID for more
             information on what each parameter is

    b.  Both probabilistic and deterministic tractography can be
        performed using this script; use option \--mode to specify which
        type of tractography to use

    c.  Outputs are stored in a new directory named 'track'

        i.  The tractography outputs of 3dTrackID for every set of
            ROI/parameters used will be stored in a unique subdirectory,
            named with a 2-digit index

        ii. A CSV text file titled track_log contains a table that lists
            the ROI/parameters used for each output; refer to this table
            to find the tractography outputs

        iii. The most important output of 3dTrackID is the .grid file;
             this is a raw text file that contains all DTI statistics
             matrices, such as mean FA, mean MD, mean bundle length,
             etc.

    d.  The pull script will make a new directory within the subject's directory 
        called 'prob' with the tractography probability. It will also create a track
        log directory if there isn't an exisitng one and update it if there is 

    e.  The pull will create new directories with the tractography output data
        and copy all data from the Biowulf job to the shared drive

    e.  **NOTE**: it is recommended that you run this script in Linux

    f.  **NOTE**: this script cannot handle ROI datasets of more than
        600 ROI; if larger datasets are used, there is a high chance
        that the process will be killed due to memory issues

15. **DTI_do_08_convertGrid.sh** -- save the raw output of AFNI
    tractography as either a .npy object (default) or individual CSV
    files

    -   This script will run through each existing output subdirectory
        in the 'track' folder and convert the raw .grid file into a .npy
        file and binary .csv structural connectivity file

        -   The .grid file contains data matrices that contain
            tractography statistics between every pair of ROI; refer to
            the documentation of AFNIs 3dTrackID for a list of
            statistics

    -   Default behavior is to output a .npy file (named all_data.npy),
        which can be loaded into a python workspace as a dictionary
        containing all statistics matrices. A .csv file (named
        SC_bin.csv) will also be outputted, containing all of the
        structural connections between ROIs in binary format.

        -   To load the .npy file in python, use the following code:

my_dict = np.load(path_to_npy, allow_pickle=True).item()

-   To load the .csv file in python, use the following code:

my_sc_bin = np.loadtxt(path_to_csv, delimiter=",")







Useful Python scripts

-   **do_save_npy_as_csv.py** -- save a CSV file from the file
    all_data.npy

    -   Use this to convert one or more additional statistics from the
        all_data.npy file to .csv format

    -   The user must run DTI_do_convert_grid.sh (with the default
        output of all_data.npy) prior to running this script

-   **delete_track_row.py** -- delete a tractography output subdirectory
    and its corresponding row in the track_log CSV file

    -   Once an output directory and its corresponding row is deleted,
        all remaining directories are reindexed, and the track_log is
        edited to reflect this change

    -   Use this script to delete tractography outputs; do not manually
        delete any folders

Notes

-   Steps for manual correction of the T2-to-T1 alignment

    -   cd to the subject's DTI reg directory

    -   Open an AFNI interactive session by typing afni in the terminal

    -   Set t1.nii as the underlay, t2_ORIG.nii as the overlay

    -   Click on "Define Datamode -\>", then click on "Plugins" on the
        lower right corner

    -   Select the "Nudge Dataset" plugin

    -   In the AFNI Nudger window, select t2_ORIG.nii as the dataset to
        nudge

    -   To manually shift/rotate the T2 into rough alignment with the
        T1, enter values (in mm for shift and degrees for rotation) in
        the text boxes for how much you want to shift/rotate, then click
        "Nudge" to apply the shift/rotation to the dataset

        -   Ex. to shift the dset inferiorly by 10mm, enter "-10" in the
            Shifts(S) box; to rotate the dset counterclockwise by 10
            degrees along the inferior-superior axis (i.e. axial slice),
            enter "10" in the Angles(I) box

        -   One may decrease the opacity of the overlay by clicking the
            downwards arrow right next to the number "8" on the
            righthand side of the image viewer window

        -   The alignment does not have to be perfect; only good enough
            (3dAllineate will take care of the fine alignment)

    -   Once you are happy with the manual alignment, click on "Print",
        then return to the terminal

    -   From the printed command call of 3drotate, copy the portion of
        the line that contains the options --rotate and --ashift

        -   It should look something like this: "-rotate 0.00I 0.00R
            0.00A -ashift 0.00S 0.00L 0.00P"

    -   Run DTI_do_reg_anat.sh again with the ---shift option

        -   Paste the above string (in double quotes) after the ---shift
            option

    -   Run DTI_do_reg_anat_QC.sh to quality check the alignment

-   All biowulf push/pull scripts have batch processing functionalities
    to process multiple subjects in succession

    -   In the *push* script, user may specify a list of subject codes
        either as positional arguments or in a text file (with each
        subject code on a separate line) with the -l option

    -   To run, first run the *push* script to push data to biowulf and
        run processing, then run the *pull* script to pull processed
        data from biowulf back to NEU Shares

    -   WARNING: pull scripts permanently delete their respective
        working directories in biowulf (usually named \_\_WORK\_\*);
        therefore, the user is advised to log onto biowulf and check
        that jobs have fully completed without error before running pull

-   All scripts, except for the QC scripts, can be run on the Linux
    machine (most are recommended to be run on Linux)

    -   To run biowulf push/pull scripts on Linux, a separate SSH public
        key authentication needs to be set up on the Linux (unless you
        want to enter your NIH password a million times); simply run
        DTI_do_setupBiowulf.sh while in the Linux

**do_batch.sh** -- run a script on multiple subjects

-   Path: /Volumes/Shares/NEU/Scripts_and_Parameters/scripts/do_batch.sh

-   Usage: ./do_batch.sh \[-i\|\--in_dir IN_DIR\] \[-o\|\--out_dir
    OUT_DIR\] \[-s\|\--subj_list SUBJ_LIST\] EXPR \[SUBJ \[SUBJ \...\]\]

-   Inputs

    -   EXPR: the **full** command to run, including the keyword "bash"
        or "./"at the beginning of the command

        -   to specify the subject argument in the command, use
            "\--subj" instead; this script will automatically replace
            this with the subject code that it is currently working on

    -   SUBJ (*optional*): subject code(s); can specify a variable
        number of them

    -   -i IN_DIR: absolute or relative path to the directory that
        contains the script to run in batch (default =
        /Volumes/Shares/NEU/

Scripts_and_Parameters/scripts/DTI_scripts)

-   -o OUT_DIR: absolute or relative path to a directory to store
    standard output log files (**not** the actual output of the script
    that you want to run in batch) (default =
    /Volumes/Shares/NEU/Scripts_and_Parameters/

scripts/\_\_files/\_\_batch)

-   -s SUBJ_LIST (*optional*): file containing a list of subject codes
    to perform batch processing on; each subject code must be specified
    on a new line; make sure to include a blank new line at the end of
    the document

```{=html}
<!-- -->
```
-   Outputs

    -   \${OUT_DIR}/\${run_date}\_\${name_of_script}/\*

    -   Outputs are stored in a subdirectory named
        \${run_date}\_\${name_of_script}, and will contain text files
        named the subject code that the stdout pertains to

    -   Check these files to ensure that processes have completed
        without errors

-   Notes

    -   This script pipes the shell command "yes" to the EXPR being run
        for all subjects in SUBJ_LIST; this will ensure that no user
        input for yes/no questions is needed

    -   If both SUBJ_LIST and SUBJ positional arguments are provided,
        SUBJ_LIST will take precedence

    -   WARNING: this script is NOT intended to run manual QC scripts in
        batch

-   Examples:

    -   Run probabilistic tractography on a list of subjects stored in
        file "subj_list", and store standard output logs in an
        alternative location that's one directory up the tree (relative
        to the path of do_batch.sh):

\>\>\> ./do_batch.sh -i /Volumes/Shares/NEU/Scripts_and_Parameters/

scripts/DTI_scripts -o ../alt_dir -s subj_list "bash
DTI_do_prob_track.sh \--subj\"
