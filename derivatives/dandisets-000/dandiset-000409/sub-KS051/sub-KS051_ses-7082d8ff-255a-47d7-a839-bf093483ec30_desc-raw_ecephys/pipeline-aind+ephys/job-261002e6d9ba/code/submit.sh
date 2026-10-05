#!/bin/bash
#SBATCH --job-name=AIND-Ephys-Pipeline
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-e_ejo1ef/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-aind+ephys/job-261002e6d9ba/logs/job-%j_slurm.log
#SBATCH --mem=1GB
#SBATCH --cpus-per-task 1
#SBATCH --partition=mit_preemptable
#SBATCH --time=48:00:00
#SBATCH --signal=B:USR1@600

NWB_FILE_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/038/89d/03889d5a-cb7b-4075-9e29-76998f7b4415"
DATA_PATH="/orcd/data/dandi/001/s3dandiarchive/blobs/038/89d"

RESULTS_PATH="/orcd/data/dandi/001/dandi-compute/processing/prepare-job-e_ejo1ef/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-aind+ephys/job-261002e6d9ba/intermediate"
WORKDIR="/orcd/data/dandi/001/dandi-compute/work"
NXF_APPTAINER_CACHEDIR="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache"

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-nextflow_environment

# Ensure the correct version of AIND pipeline is used
git -C "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline" checkout 1.3.3

# Need to ensure latest DANDI-CLI version is always used, otherwise upload of logs may not be possible at the end
pip install -U dandi

# Run nextflow from a unique per-job directory so each job gets its own
# isolated .nextflow/ (history + cache) and they don't fight over file locks.
RUNDIR="/orcd/data/dandi/001/dandi-compute/processing/prepare-job-e_ejo1ef/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-aind+ephys/job-261002e6d9ba/logs"
cd "$RUNDIR"

# The steps Nextflow submits queue and run inside this job's time limit. When the limit is
# near, SLURM sends USR1 (`--signal` above). When it stops the job early (preemption,
# `scancel`), it sends TERM. Either way Nextflow is stopped, which cancels the steps it
# submitted, and the logs are uploaded so the capsule reads as failed rather than stalled.
# Nextflow gets up to five of the ten minutes of the warning to cancel its steps, leaving the
# rest for the upload, but only seconds after TERM, where the grace period may be short. A
# later run of this script, including a requeued one, resumes from the steps already finished.
stop_nextflow_and_upload_logs() {
    trap '' USR1 TERM
    echo "=== $1; stopping nextflow and uploading logs ==="
    kill -TERM "$NEXTFLOW_PID" 2>/dev/null || true
    for _ in $(seq "$2"); do
        kill -0 "$NEXTFLOW_PID" 2>/dev/null || break
        sleep 1
    done
    rm -rf "$RESULTS_PATH"  # Partial results must not be uploaded as derivatives
    cd "$(dirname "$RESULTS_PATH")"
    dandi upload --validation skip
    exit 1
}
trap 'stop_nextflow_and_upload_logs "Time limit is near" 300' USR1
trap 'stop_nextflow_and_upload_logs "Stopped by SLURM" 10' TERM

DATA_PATH="$DATA_PATH" RESULTS_PATH="$RESULTS_PATH" NXF_APPTAINER_CACHEDIR="$NXF_APPTAINER_CACHEDIR" nextflow \
    -C "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-e_ejo1ef/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-aind+ephys/job-261002e6d9ba/code/name-mit+engaging_revision-5.config" \
    -log "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-e_ejo1ef/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-aind+ephys/job-261002e6d9ba/logs/nextflow.log" \
    run "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline/pipeline/main_multi_backend.nf" \
    -resume \
    -work-dir "$WORKDIR" \
    --params_file "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-e_ejo1ef/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-aind+ephys/job-261002e6d9ba/code/name-default_version-1+3+3.json" \
    --job_dispatch_args "--nwb-files $NWB_FILE_PATH" &
NEXTFLOW_PID=$!
wait "$NEXTFLOW_PID"
trap - USR1 TERM

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
echo "prepare-job-e_ejo1ef" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
