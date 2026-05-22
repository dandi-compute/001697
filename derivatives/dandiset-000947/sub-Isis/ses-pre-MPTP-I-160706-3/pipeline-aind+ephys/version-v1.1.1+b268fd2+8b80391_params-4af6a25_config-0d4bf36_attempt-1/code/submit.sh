#!/bin/bash
#SBATCH --job-name=AIND-Ephys-Pipeline
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/tmpthjxjxjm/001697/derivatives/dandiset-000947/sub-Isis/ses-pre-MPTP-I-160706-3/pipeline-aind+ephys/version-v1.1.1+b268fd2+8b80391_params-4af6a25_config-0d4bf36_attempt-1/logs/job-%j_slurm.log
#SBATCH --mem=1GB
#SBATCH --cpus-per-task 1
#SBATCH --partition=mit_normal
#SBATCH --time=12:00:00

NWB_FILE_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/019/de2/019de24d-338e-4354-80af-ff42ccddf2c3"
DATA_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/019/de2"

RESULTS_PATH="/orcd/data/dandi/001/dandi-compute/processing/tmpthjxjxjm/001697/derivatives/dandiset-000947/sub-Isis/ses-pre-MPTP-I-160706-3/pipeline-aind+ephys/version-v1.1.1+b268fd2+8b80391_params-4af6a25_config-0d4bf36_attempt-1/intermediate"
WORKDIR="/orcd/data/dandi/001/dandi-compute/work"
NXF_APPTAINER_CACHEDIR="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache"

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-nextflow_environment

# Ensure the correct version of AIND pipeline is used
git -C "aind-ephys-pipeline.cody" checkout v1.1.1

# Need to ensure latest DANDI-CLI version is always used, otherwise upload of logs may not be possible at the end
pip install -U dandi

DATA_PATH="$DATA_PATH" RESULTS_PATH="$RESULTS_PATH" NXF_APPTAINER_CACHEDIR="$NXF_APPTAINER_CACHEDIR" nextflow \
    -C "/orcd/data/dandi/001/dandi-compute/processing/tmpthjxjxjm/001697/derivatives/dandiset-000947/sub-Isis/ses-pre-MPTP-I-160706-3/pipeline-aind+ephys/version-v1.1.1+b268fd2+8b80391_params-4af6a25_config-0d4bf36_attempt-1/code/name-mit+engaging_revision-1.config" \
    -log "/orcd/data/dandi/001/dandi-compute/processing/tmpthjxjxjm/001697/derivatives/dandiset-000947/sub-Isis/ses-pre-MPTP-I-160706-3/pipeline-aind+ephys/version-v1.1.1+b268fd2+8b80391_params-4af6a25_config-0d4bf36_attempt-1/logs/nextflow.log" \
    run "aind-ephys-pipeline.cody/pipeline/main_multi_backend.nf" \
    -work-dir "$WORKDIR" \
    --params_file "/orcd/data/dandi/001/dandi-compute/processing/tmpthjxjxjm/001697/derivatives/dandiset-000947/sub-Isis/ses-pre-MPTP-I-160706-3/pipeline-aind+ephys/version-v1.1.1+b268fd2+8b80391_params-4af6a25_config-0d4bf36_attempt-1/code/name-deterministic.json" \
    --job_dispatch_args "--nwb-files $NWB_FILE_PATH"

cd $RESULTS_PATH
mv nwb/ ../derivatives/
mv visualization_output.json visualization/
mv visualization/ ../derivatives/
mv postprocessed/ ../derivatives/
mv nextflow/* ../logs/
cd ..
rm -rf $RESULTS_PATH  # Clean up intermediate values

dandi upload --validation skip  # Dandiset is valid if ignoring NWBI issues from copied files (BIDS part is valid)
echo "tmpthjxjxjm" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
