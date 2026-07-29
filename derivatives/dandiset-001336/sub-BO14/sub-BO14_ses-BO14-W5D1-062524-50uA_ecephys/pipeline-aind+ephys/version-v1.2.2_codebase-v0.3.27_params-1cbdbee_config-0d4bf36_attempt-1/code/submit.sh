#!/bin/bash
#SBATCH --job-name=AIND-Ephys-Pipeline
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-go_gtnr3/001697/derivatives/dandiset-001336/sub-BO14/sub-BO14_ses-BO14-W5D1-062524-50uA_ecephys/pipeline-aind+ephys/version-v1.2.2_codebase-v0.3.27_params-1cbdbee_config-0d4bf36_attempt-1/logs/job-%j_slurm.log
#SBATCH --mem=1GB
#SBATCH --cpus-per-task 1
#SBATCH --partition=mit_normal
#SBATCH --time=12:00:00

NWB_FILE_PATH="/orcd/data/dandi/002/s3dandiarchive/blobs/b66/4f0/b664f003-7b70-45a5-a3fa-6e28f510cf71"
DATA_PATH="/orcd/data/dandi/002/s3dandiarchive/blobs/b66/4f0"

RESULTS_PATH="/orcd/data/dandi/001/dandi-compute/processing/prepare-job-go_gtnr3/001697/derivatives/dandiset-001336/sub-BO14/sub-BO14_ses-BO14-W5D1-062524-50uA_ecephys/pipeline-aind+ephys/version-v1.2.2_codebase-v0.3.27_params-1cbdbee_config-0d4bf36_attempt-1/intermediate"
WORKDIR="/orcd/data/dandi/001/dandi-compute/work"
NXF_APPTAINER_CACHEDIR="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache"

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-nextflow_environment

# Ensure the correct version of AIND pipeline is used
git -C "aind-ephys-pipeline" checkout v1.2.2

# Need to ensure latest DANDI-CLI version is always used, otherwise upload of logs may not be possible at the end
pip install -U dandi

DATA_PATH="$DATA_PATH" RESULTS_PATH="$RESULTS_PATH" NXF_APPTAINER_CACHEDIR="$NXF_APPTAINER_CACHEDIR" nextflow \
    -C "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-go_gtnr3/001697/derivatives/dandiset-001336/sub-BO14/sub-BO14_ses-BO14-W5D1-062524-50uA_ecephys/pipeline-aind+ephys/version-v1.2.2_codebase-v0.3.27_params-1cbdbee_config-0d4bf36_attempt-1/code/name-mit+engaging_revision-1.config" \
    -log "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-go_gtnr3/001697/derivatives/dandiset-001336/sub-BO14/sub-BO14_ses-BO14-W5D1-062524-50uA_ecephys/pipeline-aind+ephys/version-v1.2.2_codebase-v0.3.27_params-1cbdbee_config-0d4bf36_attempt-1/logs/nextflow.log" \
    run "aind-ephys-pipeline/pipeline/main_multi_backend.nf" \
    -work-dir "$WORKDIR" \
    --params_file "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-go_gtnr3/001697/derivatives/dandiset-001336/sub-BO14/sub-BO14_ses-BO14-W5D1-062524-50uA_ecephys/pipeline-aind+ephys/version-v1.2.2_codebase-v0.3.27_params-1cbdbee_config-0d4bf36_attempt-1/code/name-original_version-1+2+2.json" \
    --job_dispatch_args "--nwb-files $NWB_FILE_PATH"

echo "=== Directory tree of \$RESULTS_PATH after nextflow run ==="
tree "$RESULTS_PATH" || find "$RESULTS_PATH" -print
echo "=== End of directory tree ==="

cd $RESULTS_PATH
mv nwb/ ../derivatives/
mv visualization_output.json visualization/
mv quality_control.json visualization/
find quality_control/ -type f -name "*.png" -exec mv -t visualization/ {} +
mv visualization/ ../derivatives/
mv postprocessed/ ../derivatives/
mv nextflow/* ../logs/
cd ..
rm -rf $RESULTS_PATH  # Clean up intermediate values

dandi upload --validation skip  # Dandiset is valid if ignoring NWBI issues from copied files (BIDS part is valid)
echo "prepare-job-go_gtnr3" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
