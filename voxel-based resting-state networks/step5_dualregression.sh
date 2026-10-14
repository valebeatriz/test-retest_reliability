#!/bin/bash
#
# step4_dualregression.sh
#
# Runs FSL dual_regression to project each subject's data onto the
# group-ICA spatial maps from step1_melodic.sh, giving subject-level maps
# for the same components.
#
# Usage: ./step4_dualregression.sh <PROJECT_PATH> <FOLDER> <N_SUBS>
#   PROJECT_PATH  Project root. Expects
#                 <PROJECT_PATH>/derivatives_reg/ICA/<N_SUBS>subs/<FOLDER>_IC50/melodic_IC.nii.gz
#                 and <PROJECT_PATH>/code/txt_files_reg/<FOLDER>.txt (same
#                 subject list used by step1_melodic.sh).
#   FOLDER        Name of the group-ICA run (same as step1_melodic.sh's
#                 FOLDER argument).
#   N_SUBS        Subsample size (10, 20, 50, or 80).
#
# Output: <PROJECT_PATH>/derivatives_reg/ICA/<N_SUBS>subs/<FOLDER>_IC50_dual_regression.dr/
# (per-subject dr_stage2_subject*_Z.nii.gz maps, plus a log file).

module load fsl

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <PROJECT_PATH> <FOLDER> <N_SUBS>" >&2
    exit 1
fi

PROJECT_PATH="$1"
FOLDER="$2"
N_SUBS="$3"

IC_OPTIONS="IC50"
FOLDER_PATH="$PROJECT_PATH/derivatives_reg/ICA/${N_SUBS}subs"

ICA_DIR="${FOLDER}_${IC_OPTIONS}"
INPUT_FILE="$PROJECT_PATH/code/txt_files_reg/${FOLDER}.txt"

MELODIC_IC_PATH="${FOLDER_PATH}/${ICA_DIR}/melodic_IC.nii.gz"
OUTPUT_DIR="${FOLDER_PATH}/${ICA_DIR}_dual_regression.dr"

if [[ ! -f "$MELODIC_IC_PATH" ]]; then
    echo "Error: group-ICA map not found: $MELODIC_IC_PATH" >&2
    exit 1
fi
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: subject list not found: $INPUT_FILE" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

log_file="${OUTPUT_DIR}/dual_regression.log"
echo "Running dual regression for ${ICA_DIR}..."

# Args: <group_IC_maps> <des_norm> <threshold> <n_perm> <output_dir> <subject_4D_files...>
# des_norm=1: variance-normalise timecourses; threshold=-1: no thresholding;
# n_perm=0: skip randomise-based group stats (done separately if needed).
if dual_regression "$MELODIC_IC_PATH" 1 -1 0 "$OUTPUT_DIR" $(cat "$INPUT_FILE") > "$log_file" 2>&1; then
    echo "Dual regression completed successfully for ${ICA_DIR}"
else
    echo "Error: Dual regression failed for ${ICA_DIR}! Check log file: $log_file" >&2
    exit 1
fi