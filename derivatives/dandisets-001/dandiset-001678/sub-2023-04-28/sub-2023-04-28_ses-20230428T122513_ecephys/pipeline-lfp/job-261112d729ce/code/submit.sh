#!/bin/bash
#SBATCH --job-name=DANDI-Compute-LFP
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-un0b05mc/001697/derivatives/dandisets-001/dandiset-001678/sub-2023-04-28/sub-2023-04-28_ses-20230428T122513_ecephys/pipeline-lfp/job-261112d729ce/logs/job-%j_slurm.log
#SBATCH --mem=16GB
#SBATCH --cpus-per-task=1
#SBATCH --partition=mit_preemptable
#SBATCH --time=48:00:00

# Every step runs inside the LFP image with Apptainer, the upload included. Nothing is taken from an
# environment on the cluster. Every capsule of a version runs the same image, kept in the shared cache.
IMAGE_FILE_PATH="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache/ghcr.io-dandi-compute-dandi-compute-lfp-v0.12.6.img"
# The input is a blob in the cluster's mirror of the archive, outside the capsule, so both blob
# partitions are bound into the container.
BIND_PATHS="/orcd/data/dandi/001:/orcd/data/dandi/001,/orcd/data/dandi/002:/orcd/data/dandi/002"
# --cleanenv keeps the job's environment out of the container. Apptainer still passes on the
# variables prefixed with APPTAINERENV_, which is how the upload gets its token.
if [ -n "${DANDI_API_KEY:-}" ]; then
    export APPTAINERENV_DANDI_API_KEY="$DANDI_API_KEY"
fi

run_in_image() {
    apptainer exec --cleanenv --bind "$BIND_PATHS" "$IMAGE_FILE_PATH" "$@"
}

# The capsule is uploaded however this script ends. A failure at any step, setup included, then
# leaves the capsule's logs on the archive, so it reads as failed rather than stalled. Only a capsule
# whose image could not be pulled cannot be uploaded, since the DANDI CLI is in the image. Any file
# under the capsule's derivatives/ marks it successful, so a failed run's partial output is removed
# first. The upload carries on through a second TERM, which the array task passes on as well.
upload_capsule() {
    local run_status=$?
    trap - EXIT
    trap '' TERM
    set +e
    if [ "$run_status" -ne 0 ]; then
        echo "=== The run ended with status ${run_status}; uploading its logs ==="
        rm -rf "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-un0b05mc/001697/derivatives/dandisets-001/dandiset-001678/sub-2023-04-28/sub-2023-04-28_ses-20230428T122513_ecephys/pipeline-lfp/job-261112d729ce/derivatives/nwb/sub-2023-04-28_ses-20230428T122513_ecephys_desc-lfp"
    fi
    local upload_status=1
    if [ -f "$IMAGE_FILE_PATH" ]; then
        cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-un0b05mc/001697/derivatives/dandisets-001/dandiset-001678/sub-2023-04-28/sub-2023-04-28_ses-20230428T122513_ecephys/pipeline-lfp/job-261112d729ce" && run_in_image dandi upload --allow-any-path --validation skip
        upload_status=$?
    else
        echo "=== The image is not at ${IMAGE_FILE_PATH}, so the capsule cannot be uploaded ==="
    fi
    if [ "$run_status" -ne 0 ]; then
        exit "$run_status"
    fi
    if [ "$upload_status" -ne 0 ]; then
        exit "$upload_status"
    fi
    echo "prepare-job-un0b05mc" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
}
trap upload_capsule EXIT
# SLURM stops the job with TERM (preemption, `scancel`). Without this the upload would see the
# status of the last command to finish, which can be zero.
trap 'exit 143' TERM

set -eo pipefail

source /etc/profile.d/modules.sh
module load apptainer

# Unset variables are only an error from here, since the script sourced above may read some.
set -u

# The image is pulled under a name of its own and then moved into place, so no capsule ever runs a
# partial image.
if [ ! -f "$IMAGE_FILE_PATH" ]; then
    mkdir -p "$(dirname "$IMAGE_FILE_PATH")"
    PARTIAL_IMAGE_FILE_PATH="${IMAGE_FILE_PATH}.partial-${SLURM_JOB_ID:-$$}"
    if ! apptainer pull --disable-cache "$PARTIAL_IMAGE_FILE_PATH" "docker://ghcr.io/dandi-compute/dandi-compute-lfp:v0.12.6"; then
        rm -f "$PARTIAL_IMAGE_FILE_PATH"
        exit 1
    fi
    mv -f "$PARTIAL_IMAGE_FILE_PATH" "$IMAGE_FILE_PATH"
fi

cd "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-un0b05mc/001697/derivatives/dandisets-001/dandiset-001678/sub-2023-04-28/sub-2023-04-28_ses-20230428T122513_ecephys/pipeline-lfp/job-261112d729ce"
mkdir -p "$(dirname "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-un0b05mc/001697/derivatives/dandisets-001/dandiset-001678/sub-2023-04-28/sub-2023-04-28_ses-20230428T122513_ecephys/pipeline-lfp/job-261112d729ce/derivatives/nwb/sub-2023-04-28_ses-20230428T122513_ecephys_desc-lfp")"

# The input is a valid NWB file even though it has no .nwb suffix. duct runs inside the container
# around the pipeline to record its resource usage.
run_in_image \
    duct --output-prefix "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-un0b05mc/001697/derivatives/dandisets-001/dandiset-001678/sub-2023-04-28/sub-2023-04-28_ses-20230428T122513_ecephys/pipeline-lfp/job-261112d729ce/logs/duct_" \
        python -m dandi_compute_code.lfp_pipeline \
            --input "/orcd/data/dandi/001/s3dandiarchive/blobs/184/665/184665ff-0d2a-4ac5-b50a-21210f7372c4" \
            --output "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-un0b05mc/001697/derivatives/dandisets-001/dandiset-001678/sub-2023-04-28/sub-2023-04-28_ses-20230428T122513_ecephys/pipeline-lfp/job-261112d729ce/derivatives/nwb/sub-2023-04-28_ses-20230428T122513_ecephys_desc-lfp" \
            --params "default"
