#!/bin/bash
#
# step5_dice_subject.sh
#
# For each subject's dual-regression maps (from step4_dualregression.sh),
# splits into individual components, binarizes, and computes Dice overlap
# against each of the 7 Yeo RSN templates — the subject-level counterpart
# of step2_dice_group.sh.
#
# Usage: ./step5_dice_subject.sh <PROJECT_PATH> <FOLDER> <N_SUBS>
#   PROJECT_PATH  Project root. Expects dual-regression output at
#                 <PROJECT_PATH>/derivatives_reg/ICA/<N_SUBS>subs/<FOLDER>_IC50_dual_regression.dr/
#                 dr_stage2_subject<NNNNN>_Z.nii.gz
#   FOLDER        Name of the group-ICA run (same as step5_dualregression.sh's
#                 FOLDER argument).
#   N_SUBS        Subsample size (10, 20, 50, or 80).
#
# Output: one Dice table per subject at
#   <PROJECT_PATH>/derivatives_reg/ICA/dice_<N_SUBS>subs/DR/<subject>_<FOLDER>_IC50.txt
#
# Optional env vars: TEMPLATES_DIR (default: ./templates next to this
# script), N_COMPONENTS (default 50), BIN_THRESHOLD (default 3).

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
KEEP_DR_OUTPUT="${KEEP_DR_OUTPUT:-0}"
IC_OPTIONS="IC50"

# Yeo 7-network RSN templates, in canonical order (see step2_dice_group.sh).
VN="$TEMPLATES_DIR/Yeo_rsn0000.nii.gz"
SMN="$TEMPLATES_DIR/Yeo_rsn0001.nii.gz"
DAN="$TEMPLATES_DIR/Yeo_rsn0002.nii.gz"
VAN="$TEMPLATES_DIR/Yeo_rsn0003.nii.gz"
LN="$TEMPLATES_DIR/Yeo_rsn0004.nii.gz"
FPN="$TEMPLATES_DIR/Yeo_rsn0005.nii.gz"
DMN="$TEMPLATES_DIR/Yeo_rsn0006.nii.gz"
rsn_list=("$VN" "$SMN" "$DAN" "$VAN" "$LN" "$FPN" "$DMN")
rsn_names=("VN" "SMN" "DAN" "VAN" "LN" "FPN" "DMN")

for rsn in "${rsn_list[@]}"; do
    if [[ ! -f "$rsn" ]]; then
        echo "Error: RSN template not found: $rsn" >&2
        echo "Set TEMPLATES_DIR to the folder containing the Yeo RSN templates." >&2
        exit 1
    fi
done

IC_list=()
for i in $(seq -w 0000 $(printf "%04d" $((N_COMPONENTS - 1)))); do
    IC_list+=("IC$i")
done

ICS_DIR="$PROJECT_PATH/derivatives_reg/ICA/${N_SUBS}subs"
OUTPUT_DIR="$PROJECT_PATH/derivatives_reg/ICA/dice_${N_SUBS}subs/DR"
mkdir -p "$OUTPUT_DIR"

folder_name="${FOLDER}_${IC_OPTIONS}_dual_regression.dr"
folder_path="$ICS_DIR/$folder_name"

if [[ ! -d "$folder_path" ]]; then
    echo "Error: dual regression output not found: $folder_path" >&2
    exit 1
fi

for subject_file in "$folder_path"/dr_stage2_subject*_Z.nii.gz; do
    subject_num=$(basename "$subject_file" | sed -E 's/dr_stage2_subject(.*)_Z\.nii\.gz/\1/')
    subject_split_dir="$folder_path/split_ICs/$subject_num"
    mkdir -p "$subject_split_dir"

    echo "Processing subject: $subject_num in $FOLDER"

    fslsplit "$subject_file" "$subject_split_dir/IC" -t
    for IC in "$subject_split_dir"/*.nii.gz; do
        fslmaths "$IC" -thr "$BIN_THRESHOLD" -bin "${IC%.nii.gz}_bin.nii.gz"
    done

    dice_output_tmp=$(mktemp)
    for k in "${IC_list[@]}"; do
        aux_dice_list=()
        for i in "${!rsn_list[@]}"; do
            rsn_name="${rsn_names[$i]}"
            mkdir -p "$subject_split_dir/temporary"
            intersection_path="$subject_split_dir/temporary/intersection_${rsn_name}_${k}.nii.gz"
            fslmaths "${rsn_list[$i]}" -mul "$subject_split_dir/${k}_bin.nii.gz" "$intersection_path"

            RSN_vox=$(fslstats "${rsn_list[$i]}" -V | awk '{ print $1 }')
            IC_vox=$(fslstats "$subject_split_dir/${k}_bin.nii.gz" -V | awk '{ print $1 }')
            intersection_vox=$(fslstats "$intersection_path" -V | awk '{ print $1 }')

            dice=$(echo "scale=4; (2 * $intersection_vox) / ($RSN_vox + $IC_vox)" | bc -l)
            aux_dice_list+=("$dice")

            rm "$intersection_path"
        done
        echo "${aux_dice_list[*]}" >> "$dice_output_tmp"
    done

    paste "$dice_output_tmp" | column -s $'\t' -t > "$OUTPUT_DIR/${subject_num}_${FOLDER}_${IC_OPTIONS}.txt"
    rm "$dice_output_tmp"
    rm -rf "$subject_split_dir/temporary"

    echo "Finished Dice for subject: $subject_num"
done