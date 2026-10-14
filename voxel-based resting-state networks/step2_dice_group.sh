#!/bin/bash
#
# step2_dice_group.sh
#
# Splits a group-ICA run's melodic_IC.nii.gz into individual components,
# binarizes each, and computes Dice overlap against each of the 7 Yeo RSN
# templates. Writes a table (rows = ICs, columns = RSNs) to:
#   <PROJECT_PATH>/derivatives_reg/ICA/dice_<N_SUBS>subs/group_dice_<FOLDER>.txt
#
# Usage: ./step2_dice_group.sh <PROJECT_PATH> <FOLDER> <N_SUBS>
#   PROJECT_PATH  Project root. Expects group-ICA output at
#                 <PROJECT_PATH>/derivatives_reg/ICA/<N_SUBS>subs/<FOLDER>/melodic_IC.nii.gz
#   FOLDER        Name of the group-ICA run (the step1 output folder name,
#                 without the _IC<N> suffix).
#   N_SUBS        Subsample size (10, 20, 50, or 80).
#
# Optional env vars: TEMPLATES_DIR (default: ./templates next to this
# script), N_COMPONENTS (default 50), BIN_THRESHOLD (default 3).
#
# RSNs follow the Yeo et al. (2011) 7-network order: VN, SMN, DAN, VAN, LN,
# FPN, DMN.

module load fsl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <PROJECT_PATH> <FOLDER> <N_SUBS>" >&2
    exit 1
fi

PROJECT_PATH="$1"
FOLDER="$2"
N_SUBS="$3"

TEMPLATES_DIR="${TEMPLATES_DIR:-$SCRIPT_DIR/templates}"
N_COMPONENTS="${N_COMPONENTS:-50}"
BIN_THRESHOLD="${BIN_THRESHOLD:-3}"

ICS_DIR="$PROJECT_PATH/derivatives_reg/ICA/${N_SUBS}subs"
OUTPUT_DIR="$PROJECT_PATH/derivatives_reg/ICA/dice_${N_SUBS}subs"
mkdir -p "$OUTPUT_DIR"

# Yeo 7-network RSN templates
rsn_list=(
  "$TEMPLATES_DIR/Yeo_rsn0000.nii.gz"
  "$TEMPLATES_DIR/Yeo_rsn0001.nii.gz"
  "$TEMPLATES_DIR/Yeo_rsn0002.nii.gz"
  "$TEMPLATES_DIR/Yeo_rsn0003.nii.gz"
  "$TEMPLATES_DIR/Yeo_rsn0004.nii.gz"
  "$TEMPLATES_DIR/Yeo_rsn0005.nii.gz"
  "$TEMPLATES_DIR/Yeo_rsn0006.nii.gz"
)
rsn_names=("VN" "SMN" "DAN" "VAN" "LN" "FPN" "DMN")

for rsn in "${rsn_list[@]}"; do
    if [[ ! -f "$rsn" ]]; then
        echo "Error: RSN template not found: $rsn" >&2
        echo "Set TEMPLATES_DIR to the folder containing the Yeo RSN templates." >&2
        exit 1
    fi
done

IC_FILE="$ICS_DIR/$FOLDER/melodic_IC.nii.gz"
ICS_OUTPUT_DIR="$ICS_DIR/$FOLDER/all_ICs"

if [[ ! -f "$IC_FILE" ]]; then
    echo "Error: melodic_IC.nii.gz not found: $IC_FILE" >&2
    exit 1
fi

mkdir -p "$ICS_OUTPUT_DIR"

# Split the 4D component map into individual 3D IC maps and binarize each.
fslsplit "$IC_FILE" "$ICS_OUTPUT_DIR/IC" -t

for IC in "$ICS_OUTPUT_DIR"/*.nii.gz; do
    fslmaths "$IC" -thr "$BIN_THRESHOLD" -bin "${IC%.nii.gz}_bin.nii.gz"
done

IC_list=()
for i in $(seq -w 0000 $(printf "%04d" $((N_COMPONENTS - 1)))); do
    IC_list+=("IC$i")
done

folder_dice_tmp="$OUTPUT_DIR/tmp_dice_${FOLDER}.txt"
: > "$folder_dice_tmp"

# For each IC, compute Dice overlap against each RSN template.
for k in "${IC_list[@]}"; do
    aux_dice_list=()
    for i in "${!rsn_list[@]}"; do
        rsn="${rsn_list[$i]}"
        rsn_name="${rsn_names[$i]}"

        mkdir -p "$ICS_OUTPUT_DIR/temporary"
        intersection="$ICS_OUTPUT_DIR/temporary/intersection_${rsn_name}_${k}.nii.gz"

        fslmaths "$rsn" -mul "$ICS_OUTPUT_DIR/${k}_bin.nii.gz" "$intersection"
        RSN_vox=$(fslstats "$rsn" -V | awk '{ print $1 }')
        IC_vox=$(fslstats "$ICS_OUTPUT_DIR/${k}_bin.nii.gz" -V | awk '{ print $1 }')
        intersection_vox=$(fslstats "$intersection" -V | awk '{ print $1 }')
        dice=$(echo "scale=4; (2 * $intersection_vox) / ($RSN_vox + $IC_vox)" | bc -l)
        aux_dice_list+=("$dice")
    done
    echo "${aux_dice_list[*]}" >> "$folder_dice_tmp"
done

paste "$folder_dice_tmp" | column -s $'\t' -t > "$OUTPUT_DIR/group_dice_${FOLDER}.txt"
rm "$folder_dice_tmp"

echo "Done: $FOLDER -> $OUTPUT_DIR/group_dice_${FOLDER}.txt"