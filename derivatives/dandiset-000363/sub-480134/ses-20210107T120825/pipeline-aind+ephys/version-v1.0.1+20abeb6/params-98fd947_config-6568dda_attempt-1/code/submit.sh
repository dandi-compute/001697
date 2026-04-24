#!/bin/bash
#SBATCH --job-name=AIND-Ephys-Pipeline
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/tmpy9plm_04/001697/derivatives/dandiset-000363/sub-480134/ses-20210107T120825/pipeline-aind+ephys/version-v1.0.1+20abeb6/params-98fd947_config-6568dda_attempt-1/logs/job-%j_slurm.log
#SBATCH --mem=1GB
#SBATCH --cpus-per-task 1
#SBATCH --partition=mit_normal
#SBATCH --time=12:00:00

NWB_FILE_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/003/4e7/0034e7b5-684c-4876-bd6c-7744040fe5e9"
DATA_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/003/4e7"

RESULTS_PATH="/orcd/data/dandi/001/dandi-compute/processing/tmpy9plm_04/001697/derivatives/dandiset-000363/sub-480134/ses-20210107T120825/pipeline-aind+ephys/version-v1.0.1+20abeb6/params-98fd947_config-6568dda_attempt-1/intermediate"
WORKDIR="/orcd/data/dandi/001/dandi-compute/work"
NXF_APPTAINER_CACHEDIR="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache"

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-nextflow_environment

# Ensure the correct version of AIND pipeline is used
git -C "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline.cody" checkout v1.0.1

# Need to ensure latest DANDI-CLI version is always used, otherwise upload of logs may not be possible at the end
pip install -U dandi

DATA_PATH="$DATA_PATH" RESULTS_PATH="$RESULTS_PATH" NXF_APPTAINER_CACHEDIR="$NXF_APPTAINER_CACHEDIR" nextflow \
    -C "/orcd/data/dandi/001/dandi-compute/processing/tmpy9plm_04/001697/derivatives/dandiset-000363/sub-480134/ses-20210107T120825/pipeline-aind+ephys/version-v1.0.1+20abeb6/params-98fd947_config-6568dda_attempt-1/code/mit_engaging.config" \
    -log "/orcd/data/dandi/001/dandi-compute/processing/tmpy9plm_04/001697/derivatives/dandiset-000363/sub-480134/ses-20210107T120825/pipeline-aind+ephys/version-v1.0.1+20abeb6/params-98fd947_config-6568dda_attempt-1/logs/nextflow.log" \
    run "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline.cody/pipeline/main_multi_backend.nf" \
    -work-dir "$WORKDIR" \
    --params_file "/orcd/data/dandi/001/dandi-compute/processing/tmpy9plm_04/001697/derivatives/dandiset-000363/sub-480134/ses-20210107T120825/pipeline-aind+ephys/version-v1.0.1+20abeb6/params-98fd947_config-6568dda_attempt-1/code/default.json" \
    --job_dispatch_args "--nwb-files $NWB_FILE_PATH"

cd $RESULTS_PATH
mv nwb/ ../derivatives/
mv visualization_output.json visualization/
mv visualization/ ..
mv nextflow/* ../logs/
cd ..
rm -rf $RESULTS_PATH  # Clean up intermediate values

dandi upload --validation skip  # Dandiset is valid if ignoring NWBI issues from copied files (BIDS part is valid)
echo "tmpy9plm_04" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
