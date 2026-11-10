#!/bin/bash
#SBATCH --job-name=DANDI-Compute-LFP
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-iiu2ukqx/001697/derivatives/dandisets-001/dandiset-001435/sub-Offenbach/sub-Offenbach_ses-20230214_ecephys/pipeline-lfp/job-261110b70105/logs/job-%j_slurm.log
#SBATCH --mem=16GB
#SBATCH --cpus-per-task=1
#SBATCH --partition=mit_preemptable
#SBATCH --time=48:00:00

# The capsule is uploaded however this script ends. A failure at any step, setup included, then
# leaves the capsule's logs on the archive, so it reads as failed rather than stalled. Any file
# under the capsule's derivatives/ marks it successful, so a failed run's partial output is removed
# first. The upload carries on through a second TERM, which the array task passes on as well.
upload_capsule() {
    local run_status=$?
    trap - EXIT
    trap '' TERM
    set +e
    if [ "$run_status" -ne 0 ]; then
        echo "=== The run ended with status ${run_status}; uploading its logs ==="
        rm -rf "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-iiu2ukqx/001697/derivatives/dandisets-001/dandiset-001435/sub-Offenbach/sub-Offenbach_ses-20230214_ecephys/pipeline-lfp/job-261110b70105/derivatives/nwb/sub-Offenbach_ses-20230214_ecephys_desc-lfp"
    fi
    cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-iiu2ukqx/001697/derivatives/dandisets-001/dandiset-001435/sub-Offenbach/sub-Offenbach_ses-20230214_ecephys/pipeline-lfp/job-261110b70105" && dandi upload --allow-any-path --validation skip
    local upload_status=$?
    if [ "$run_status" -ne 0 ]; then
        exit "$run_status"
    fi
    if [ "$upload_status" -ne 0 ]; then
        exit "$upload_status"
    fi
    echo "prepare-job-iiu2ukqx" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
}
trap upload_capsule EXIT
# SLURM stops the job with TERM (preemption, `scancel`). Without this the upload would see the
# status of the last command to finish, which can be zero.
trap 'exit 143' TERM

set -eo pipefail

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-lfp_environment

# Unset variables are only an error from here, since the scripts sourced above may read some.
set -u

# Every capsule of a version runs the same image, so it is pulled once into the shared cache. It is
# pulled under a name of its own and then moved into place, so no capsule ever runs a partial image.
IMAGE_FILE_PATH="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache/ghcr.io-dandi-compute-dandi-compute-lfp-v0.12.4.img"
if [ ! -f "$IMAGE_FILE_PATH" ]; then
    mkdir -p "$(dirname "$IMAGE_FILE_PATH")"
    PARTIAL_IMAGE_FILE_PATH="${IMAGE_FILE_PATH}.partial-${SLURM_JOB_ID:-$$}"
    if ! apptainer pull --disable-cache "$PARTIAL_IMAGE_FILE_PATH" "docker://ghcr.io/dandi-compute/dandi-compute-lfp:v0.12.4"; then
        rm -f "$PARTIAL_IMAGE_FILE_PATH"
        exit 1
    fi
    mv -f "$PARTIAL_IMAGE_FILE_PATH" "$IMAGE_FILE_PATH"
fi

cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-iiu2ukqx/001697/derivatives/dandisets-001/dandiset-001435/sub-Offenbach/sub-Offenbach_ses-20230214_ecephys/pipeline-lfp/job-261110b70105"
mkdir -p "$(dirname "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-iiu2ukqx/001697/derivatives/dandisets-001/dandiset-001435/sub-Offenbach/sub-Offenbach_ses-20230214_ecephys/pipeline-lfp/job-261110b70105/derivatives/nwb/sub-Offenbach_ses-20230214_ecephys_desc-lfp")"

# The input is a blob in the cluster's mirror of the archive, outside the capsule, so both blob
# partitions are bound into the container. It is a valid NWB file even though it has no .nwb suffix.
# The call is wrapped with duct to record resource usage.
duct --output-prefix "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-iiu2ukqx/001697/derivatives/dandisets-001/dandiset-001435/sub-Offenbach/sub-Offenbach_ses-20230214_ecephys/pipeline-lfp/job-261110b70105/logs/duct_" \
    apptainer exec --cleanenv \
        --bind /orcd/data/dandi/001:/orcd/data/dandi/001,/orcd/data/dandi/002:/orcd/data/dandi/002 \
        "$IMAGE_FILE_PATH" \
        python -m dandi_compute_code.lfp_pipeline \
            --input "/orcd/data/dandi/002/s3dandiarchive/blobs/ab2/7f4/ab27f4bf-1da9-493f-9c89-7e753ba68a41" \
            --output "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-iiu2ukqx/001697/derivatives/dandisets-001/dandiset-001435/sub-Offenbach/sub-Offenbach_ses-20230214_ecephys/pipeline-lfp/job-261110b70105/derivatives/nwb/sub-Offenbach_ses-20230214_ecephys_desc-lfp" \
            --params "default"
