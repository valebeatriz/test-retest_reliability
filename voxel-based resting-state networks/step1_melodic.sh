#!/bin/bash
#
# step1_melodic.sh
#
# Runs FSL MELODIC group-ICA on a list of subjects/runs.
#
# Usage: ./step1_melodic.sh <PROJECT_PATH> <FOLDER> <N_SUBS>
#   PROJECT_PATH  Project root. Needs <PROJECT_PATH>/code/txt_files_reg/<FOLDER>.txt
#                 (one 4D input file path per line). Output goes to
#                 <PROJECT_PATH>/derivatives_reg/ICA/<N_SUBS>subs/.
#   FOLDER        Run name, e.g. "HCP_REST1_LR_300_10subs_1" (must match a
#                 <FOLDER>.txt file in txt_files_reg/).
#   N_SUBS        Subject count for this group (used only in the output path).
#
# Optional env vars: TR (default 0.72), N_COMPONENTS (default 50),
# BRAIN_MASK (default FSL's standard MNI152 2mm brain mask).
#
# Example: ./step1_melodic.sh /data/rsPMC HCP_REST1_LR_300_10subs_1 10

module load fsl

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <PROJECT_PATH> <FOLDER> <N_SUBS>" >&2
    exit 1
fi

PROJECT_PATH="$1"
FOLDER="$2"
N_SUBS="$3"

TR="${TR:-0.72}"
N_COMPONENTS="${N_COMPONENTS:-50}"
BRAIN_MASK="${BRAIN_MASK:-${FSLDIR:-/usr/local/fsl}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz}"

INPUT_DIR="$PROJECT_PATH/code"
OUTPUT_DIR="$PROJECT_PATH/derivatives_reg/ICA/${N_SUBS}subs"

TXT_FILE="$INPUT_DIR/txt_files_reg/${FOLDER}.txt"
OUTPUT_PATH="$OUTPUT_DIR/${FOLDER}_IC${N_COMPONENTS}"

if [[ ! -f "$TXT_FILE" ]]; then
    echo "Error: input list not found: $TXT_FILE" >&2
    exit 1
fi

mkdir -p "$OUTPUT_PATH"

melodic -i "$TXT_FILE" \
        -o "$OUTPUT_PATH" \
        --tr="$TR" \
        --nobet \
        -a concat \
        -m "$BRAIN_MASK" \
        --report \
        -d "$N_COMPONENTS" \
        --Oall

echo "Group ICA done: $TXT_FILE -> $OUTPUT_PATH"
