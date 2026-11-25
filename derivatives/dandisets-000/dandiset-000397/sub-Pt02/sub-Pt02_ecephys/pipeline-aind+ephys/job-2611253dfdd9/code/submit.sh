#!/bin/bash
#SBATCH --job-name=AIND-Ephys-Pipeline
#SBATCH --output=/orcd/data/dandi/001/dandi-compute/processing/prepare-job-furwo52w/001697/derivatives/dandisets-000/dandiset-000397/sub-Pt02/sub-Pt02_ecephys/pipeline-aind+ephys/job-2611253dfdd9/logs/job-%j_slurm.log
#SBATCH --mem=1GB
#SBATCH --cpus-per-task 1
#SBATCH --partition=mit_preemptable
#SBATCH --time=48:00:00
#SBATCH --signal=B:USR1@600

NWB_FILE_PATH="/orcd/data/dandi/002/s3dandiarchive/blobs/e86/79a/e8679ad5-884e-4e4c-b5c6-9ce9249c3b78"
DATA_PATH="/orcd/data/dandi/001/dandi-compute/work/job-2611253dfdd9/input"

RESULTS_PATH="/orcd/data/dandi/001/dandi-compute/processing/prepare-job-furwo52w/001697/derivatives/dandisets-000/dandiset-000397/sub-Pt02/sub-Pt02_ecephys/pipeline-aind+ephys/job-2611253dfdd9/intermediate"
WORKDIR="/orcd/data/dandi/001/dandi-compute/work/job-2611253dfdd9"
NXF_APPTAINER_CACHEDIR="/orcd/data/dandi/001/dandi-compute/work/apptainer_cache"

source /etc/profile.d/modules.sh
module load miniforge
module load apptainer

conda activate /orcd/data/dandi/001/environments/name-nextflow_version-25+10+4_python-3+13_environment

# Ensure the correct version of AIND pipeline is used
git -C "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline" checkout 1.5.2

# Need to ensure latest DANDI-CLI version is always used, otherwise upload of logs may not be possible at the end
pip install -U dandi

# Run nextflow from a unique per-job directory so each job gets its own
# isolated .nextflow/ (history + cache) and they don't fight over file locks.
RUNDIR="/orcd/data/dandi/001/dandi-compute/processing/prepare-job-furwo52w/001697/derivatives/dandisets-000/dandiset-000397/sub-Pt02/sub-Pt02_ecephys/pipeline-aind+ephys/job-2611253dfdd9/logs"
cd "$RUNDIR"

# From release 1.5.0 the pipeline checks the job dispatch arguments against its parameters schema,
# which has no `--nwb-files`. Instead it reads the one `.nwb` file in its input folder, so the blob,
# which has no suffix, is linked into one. The containers reach the blob through the config's bind of
# its partition. The link is made once, so a requeued run resumes on an unchanged input.
if [ ! -L "$DATA_PATH/e8679ad5-884e-4e4c-b5c6-9ce9249c3b78.nwb" ]; then
    mkdir -p "$DATA_PATH"
    ln -s "$NWB_FILE_PATH" "$DATA_PATH/e8679ad5-884e-4e4c-b5c6-9ce9249c3b78.nwb"
fi

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

# The pipeline and its config are written for the first Nextflow syntax parser, which the
# releases from 26.04 replace by default with a stricter one.
DATA_PATH="$DATA_PATH" RESULTS_PATH="$RESULTS_PATH" NXF_APPTAINER_CACHEDIR="$NXF_APPTAINER_CACHEDIR" NXF_SYNTAX_PARSER=v1 nextflow \
    -C "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-furwo52w/001697/derivatives/dandisets-000/dandiset-000397/sub-Pt02/sub-Pt02_ecephys/pipeline-aind+ephys/job-2611253dfdd9/code/name-mit+engaging_revision-9.config" \
    -log "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-furwo52w/001697/derivatives/dandisets-000/dandiset-000397/sub-Pt02/sub-Pt02_ecephys/pipeline-aind+ephys/job-2611253dfdd9/logs/nextflow.log" \
    run "/orcd/data/dandi/001/dandi-compute/aind-ephys-pipeline/pipeline/main.nf" \
    -resume \
    -work-dir "$WORKDIR" \
    --params_file "/orcd/data/dandi/001/dandi-compute/processing/prepare-job-furwo52w/001697/derivatives/dandisets-000/dandiset-000397/sub-Pt02/sub-Pt02_ecephys/pipeline-aind+ephys/job-2611253dfdd9/code/name-dartsort_version-1+5+2.json" &
NEXTFLOW_PID=$!
wait "$NEXTFLOW_PID"
trap - USR1 TERM

echo "=== Directory tree of \$RESULTS_PATH after nextflow run ==="
tree "$RESULTS_PATH" || find "$RESULTS_PATH" -print
echo "=== End of directory tree ==="

# A folder a requeued run already moved is replaced, since `mv` would otherwise nest the new
# one inside it. A step that failed or was skipped leaves its folder or file out, so each is
# moved only when present.
move_output() {
    if [ -e "$1" ]; then
        mkdir -p "$2"
        rm -rf "$2/$(basename "$1")"
        mv "$1" "$2/"
    fi
}

cd $RESULTS_PATH
move_output nwb ../derivatives
move_output postprocessed ../derivatives
# The trees are kept whole, since recordings with several probes or shanks reuse file names
# in their own subfolders. `quality_control.json` refers to its plots as
# `quality_control/{recording}/{plot}`, so it sits beside that folder.
move_output visualization ../derivatives
move_output quality_control ../derivatives/visualization
move_output quality_control.json ../derivatives/visualization
move_output visualization_output.json ../derivatives/visualization
mv nextflow/* ../logs/
# From release 1.5.0: the step commits, container tag and effective parameters of this run
if [ -f provenance.json ]; then mv provenance.json ../logs/; fi
cd ..
rm -rf $RESULTS_PATH  # Clean up intermediate values

dandi upload --validation skip  # Dandiset is valid if ignoring NWBI issues from copied files (BIDS part is valid)
echo "prepare-job-furwo52w" >> /orcd/data/dandi/001/dandi-compute/processing/done.txt
