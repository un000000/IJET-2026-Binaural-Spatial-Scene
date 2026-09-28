#!/bin/bash
#SBATCH --job-name=audio_synthesis
#SBATCH --output=logs/batch_%a.out
#SBATCH --error=logs/batch_%a.err
#SBATCH --time=48:00:00
#SBATCH --mem=8GB
#SBATCH --cpus-per-task=2
#SBATCH --array=1-10

# 3D Audio Synthesis - SLURM Batch Job Script
# 
# This script submits an array of jobs to a SLURM cluster
# Each job processes 1/Nth of the total workload
#
# Usage:
#   sbatch run_batch_slurm.sh
#
# Configuration:
#   --array=1-10  : Run 10 parallel jobs (adjust based on total workload)
#   --time        : Maximum time per job
#   --mem         : Memory per job
#   --cpus-per-task: CPU cores per job

# Configuration
TOTAL_BATCHES=10
BATCH_ID=$SLURM_ARRAY_TASK_ID

# Create logs directory
mkdir -p logs

# Load MATLAB module (adjust for your cluster)
module load matlab/R2021b

# Print job information
echo "================================================"
echo "3D Audio Synthesis - Batch Job"
echo "================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Batch: $BATCH_ID of $TOTAL_BATCHES"
echo "Node: $HOSTNAME"
echo "Start Time: $(date)"
echo "================================================"

# Run MATLAB batch processing
matlab -nodisplay -nosplash -r "
    try
        addpath('.');
        batch_synthesize('config_rooms.json', 'config_sources.json', $BATCH_ID, $TOTAL_BATCHES);
        exit(0);
    catch ME
        fprintf('ERROR: %s\n', ME.message);
        exit(1);
    end
"

EXIT_CODE=$?

echo "================================================"
echo "Job Complete"
echo "Exit Code: $EXIT_CODE"
echo "End Time: $(date)"
echo "================================================"

exit $EXIT_CODE
