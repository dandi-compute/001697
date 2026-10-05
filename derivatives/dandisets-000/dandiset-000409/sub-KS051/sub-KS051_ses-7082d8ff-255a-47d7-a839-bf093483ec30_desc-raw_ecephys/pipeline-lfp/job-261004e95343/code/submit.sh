#!/bin/bash
#SBATCH --job-name=DANDI-Compute-LFP
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343/logs/job-%j_slurm.log
#SBATCH --mem=16GB
#SBATCH --cpus-per-task=1
#SBATCH --partition=mit_preemptable
#SBATCH --time=48:00:00

set -euo pipefail

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-lfp_environment

cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343"

# Register the LFP runtime container from the GitHub Container Registry. This is
# idempotent, so it is a no-op once the container is known to this dataset.
if ! datalad containers-list | awk '{print $1}' | grep -qx "dandi-compute-lfp"; then
    datalad containers-add "dandi-compute-lfp" \
        --url "docker://ghcr.io/dandi-compute/dandi-compute-lfp:v0.10.0" \
        --call-fmt 'apptainer exec --cleanenv {img} {cmd}'
fi

mkdir -p "$(dirname "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343/derivatives/nwb/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys_desc-lfp")"

# Run the LFP pipeline inside the container on a local NWB file (the input path
# is a valid NWB file even though it has no .nwb suffix). The call is wrapped
# with duct to capture resource usage.
run_status=0
duct --output-prefix "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343/logs/duct_" \
    datalad containers-run \
        --container-name "dandi-compute-lfp" \
        --message "LFP pipeline on /orcd/data/dandi/001/s3dandiarchive/blobs/038/89d/03889d5a-cb7b-4075-9e29-76998f7b4415" \
        --input "/orcd/data/dandi/001/s3dandiarchive/blobs/038/89d/03889d5a-cb7b-4075-9e29-76998f7b4415" \
        --output "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343/derivatives/nwb/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys_desc-lfp" \
        "python -m dandi_compute_code.lfp_pipeline --input '/orcd/data/dandi/001/s3dandiarchive/blobs/038/89d/03889d5a-cb7b-4075-9e29-76998f7b4415' --output '/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343/derivatives/nwb/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys_desc-lfp' --params 'default'" \
    || run_status=$?

# A failed run must not leave a partial output behind, since any file under the capsule's
# derivatives/ marks it successful. Its logs are uploaded either way, which marks it failed.
if [ "$run_status" -ne 0 ]; then
    rm -f "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343/derivatives/nwb/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys_desc-lfp"
fi

cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-3bw_b5cc/001697/derivatives/dandisets-000/dandiset-000409/sub-KS051/sub-KS051_ses-7082d8ff-255a-47d7-a839-bf093483ec30_desc-raw_ecephys/pipeline-lfp/job-261004e95343"
dandi upload --allow-any-path --validation skip

if [ "$run_status" -ne 0 ]; then
    exit "$run_status"
fi

echo "prepare-job-3bw_b5cc" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
