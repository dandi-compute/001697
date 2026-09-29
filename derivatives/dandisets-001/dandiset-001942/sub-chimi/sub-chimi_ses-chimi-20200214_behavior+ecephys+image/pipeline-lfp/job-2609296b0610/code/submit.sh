#!/bin/bash
#SBATCH --job-name=DANDI-Compute-LFP
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610/logs/job-%j_slurm.log
#SBATCH --mem=16GB
#SBATCH --cpus-per-task=1
#SBATCH --partition=mit_preemptable
#SBATCH --time=48:00:00

set -euo pipefail

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-lfp_environment

cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610"

# Register the LFP runtime container from the GitHub Container Registry. This is
# idempotent, so it is a no-op once the container is known to this dataset.
if ! datalad containers-list | awk '{print $1}' | grep -qx "dandi-compute-lfp"; then
    datalad containers-add "dandi-compute-lfp" \
        --url "docker://ghcr.io/dandi-compute/dandi-compute-lfp:v0.9.8" \
        --call-fmt 'apptainer exec --cleanenv {img} {cmd}'
fi

mkdir -p "$(dirname "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610/derivatives/nwb/sub-chimi_ses-chimi-20200214_behavior+ecephys+image_desc-lfp")"

# Run the LFP pipeline inside the container on a local NWB file (the input path
# is a valid NWB file even though it has no .nwb suffix). The call is wrapped
# with duct to capture resource usage.
run_status=0
duct --output-prefix "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610/logs/duct_" \
    datalad containers-run \
        --container-name "dandi-compute-lfp" \
        --message "LFP pipeline on /orcd/data/dandi/001/s3dandiarchive/blobs/105/5fe/1055fe42-75f4-48ec-a4b5-8f503b449579" \
        --input "/orcd/data/dandi/001/s3dandiarchive/blobs/105/5fe/1055fe42-75f4-48ec-a4b5-8f503b449579" \
        --output "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610/derivatives/nwb/sub-chimi_ses-chimi-20200214_behavior+ecephys+image_desc-lfp" \
        "python -m dandi_compute_code.lfp_pipeline --input '/orcd/data/dandi/001/s3dandiarchive/blobs/105/5fe/1055fe42-75f4-48ec-a4b5-8f503b449579' --output '/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610/derivatives/nwb/sub-chimi_ses-chimi-20200214_behavior+ecephys+image_desc-lfp' --params 'default'" \
    || run_status=$?

# A failed run must not leave a partial output behind, since any file under the capsule's
# derivatives/ marks it successful. Its logs are uploaded either way, which marks it failed.
if [ "$run_status" -ne 0 ]; then
    rm -f "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610/derivatives/nwb/sub-chimi_ses-chimi-20200214_behavior+ecephys+image_desc-lfp"
fi

cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-jwcyv_gb/001697/derivatives/dandisets-001/dandiset-001942/sub-chimi/sub-chimi_ses-chimi-20200214_behavior+ecephys+image/pipeline-lfp/job-2609296b0610"
dandi upload --allow-any-path --validation skip

if [ "$run_status" -ne 0 ]; then
    exit "$run_status"
fi

echo "prepare-job-jwcyv_gb" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
