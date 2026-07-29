#!/bin/bash
#SBATCH --job-name=AIND-Ephys-Pipeline
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-tceovwtp/001697/derivatives/dandiset-000939/sub-A3706/sub-A3706_ses-200313_behavior+ecephys/pipeline-aind+ephys/version-v1.2.4_codebase-v0.3.46_params-1cbdbee_config-7940dfd_attempt-1/logs/job-%j_slurm.log
#SBATCH --mem=1GB
#SBATCH --cpus-per-task 1
#SBATCH --partition=mit_normal
#SBATCH --time=12:00:00

NWB_FILE_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/3e6/b90/3e6b90c2-0cd4-4046-8bbb-321db95fa1ec"
DATA_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/3e6/b90"

RESULTS_PATH="/orcd/data/dandi/001/dandi-compute/processing/prepare-job-tceovwtp/001697/derivatives/dandiset-000939/sub-A3706/sub-A3706_ses-200313_behavior+ecephys/pipeline-aind+ephys/version-v1.2.4_codebase-v0.3.46_params-1cbdbee_config-7940dfd_attempt-1/intermediate"
WORKDIR="/orcd/data/dandi/001/dandi-compute/work"
NXF_APPTAINER_CACHEDIR="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache"

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-nextflow_environment

# Ensure the correct version of AIND pipeline is used
git -C "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline" checkout v1.2.4

# Need to ensure latest DANDI-CLI version is always used, otherwise upload of logs may not be possible at the end
pip install -U dandi

# Run nextflow from a unique per-job directory so each job gets its own
# isolated .nextflow/ (history + cache) and they don't fight over file locks.
RUNDIR="/orcd/data/dandi/001/dandi-compute/processing/prepare-job-tceovwtp/001697/derivatives/dandiset-000939/sub-A3706/sub-A3706_ses-200313_behavior+ecephys/pipeline-aind+ephys/version-v1.2.4_codebase-v0.3.46_params-1cbdbee_config-7940dfd_attempt-1/logs"
cd "$RUNDIR"

DATA_PATH="$DATA_PATH" RESULTS_PATH="$RESULTS_PATH" NXF_APPTAINER_CACHEDIR="$NXF_APPTAINER_CACHEDIR" nextflow \
    -C "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-tceovwtp/001697/derivatives/dandiset-000939/sub-A3706/sub-A3706_ses-200313_behavior+ecephys/pipeline-aind+ephys/version-v1.2.4_codebase-v0.3.46_params-1cbdbee_config-7940dfd_attempt-1/code/name-mit+engaging_revision-2.config" \
    -log "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-tceovwtp/001697/derivatives/dandiset-000939/sub-A3706/sub-A3706_ses-200313_behavior+ecephys/pipeline-aind+ephys/version-v1.2.4_codebase-v0.3.46_params-1cbdbee_config-7940dfd_attempt-1/logs/nextflow.log" \
    run "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline/pipeline/main_multi_backend.nf" \
    -work-dir "$WORKDIR" \
    --params_file "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-tceovwtp/001697/derivatives/dandiset-000939/sub-A3706/sub-A3706_ses-200313_behavior+ecephys/pipeline-aind+ephys/version-v1.2.4_codebase-v0.3.46_params-1cbdbee_config-7940dfd_attempt-1/code/name-original_version-1+2+2.json" \
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
echo "prepare-job-tceovwtp" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
