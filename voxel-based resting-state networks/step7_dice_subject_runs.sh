#!/bin/bash
#
# step6_dice_subject_runs.sh
#
# Subject-level counterpart of step3_dice_group_runs.sh: computes
# intra-/inter-session Dice for each RSN, for ONE (n_subs, n_volumes,
# iteration) combination, across all subjects. Meant to be called once per
# combination (e.g. from a job array), unlike step3 which sweeps everything
# in one process.
#
# Usage: ./step6_dice_subject_runs.sh <N_SUBS> <N_VOLUMES> <N_ITERATION>
#   N_SUBS        Subsample size (10, 20, 50, or 80).
#   N_VOLUMES     Volume count for this subsample (e.g. 300, 600).
#   N_ITERATION   Iteration index (1-10).
#
# Optional env vars: BASE_DIR, INPUT_FILE, RSNS — same meaning and defaults
# as in step4_dice_group_runs.sh (uses the same IC-mapping CSV).
#
# Output: <BASE_DIR>/dice_<n_subs>subs_runs/DR/dice_dr_<n_volumes>_<n_subs>subs[_<iter>].txt
#   (columns: RSN, Comparison, Subject, Dice)
#
# Expects split ICs at (produced by step5_dice_subject.sh):
#   <BASE_DIR>/<n_subs>subs/HCP_<session>_<n_volumes>_<n_subs>subs[_<iter>]_IC50_dual_regression.dr/split_ICs/<subject>/IC<index>_bin.nii.gz

module load fsl

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <N_SUBS> <N_VOLUMES> <N_ITERATION>" >&2
    exit 1
fi

n_subs=$1
n_volumes=$2
n_iteration=$3

BASE_DIR="${BASE_DIR:-./derivatives_reg/ICA}"
INPUT_FILE="${INPUT_FILE:-$BASE_DIR/dice_GROUP_manual.csv}"
read -ra rsns <<< "${RSNS:-DAN DMN FPN LN SMN VAN VN}"
IC_OPTIONS="IC50"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: IC mapping CSV not found: $INPUT_FILE" >&2
    exit 1
fi

echo "========================================"
echo "Processing: ${n_subs} subjects, ${n_volumes} volumes, iteration ${n_iteration}"
echo "Started at: $(date)"
echo "========================================"

output_dir="$BASE_DIR/dice_${n_subs}subs_runs/DR"
mkdir -p "$output_dir"

# Unique temp dir per job so concurrent jobs (e.g. array jobs) don't collide.
temp_dir="$output_dir/tmp_${n_subs}s_${n_volumes}v_i${n_iteration}_$$"
mkdir -p "$temp_dir"
trap 'rm -rf "$temp_dir"' EXIT

iter_suffix="_${n_iteration}"
output_file="$output_dir/dice_dr_${n_volumes}_${n_subs}subs_${n_iteration}.txt"

# Build IC mapping for this specific combination only.
declare -A IC_mapping
while IFS=',' read -r rsn session csv_n_volumes csv_n_subs iteration ic; do
    rsn=$(echo "$rsn" | xargs)
    session=$(echo "$session" | xargs)
    csv_n_volumes=$(echo "$csv_n_volumes" | xargs)
    csv_n_subs=$(echo "$csv_n_subs" | xargs)
    iteration=$(echo "$iteration" | xargs)
    ic=$(echo "$ic" | xargs)

    if [[ "$ic" =~ ^[0-9]+$ ]] && [[ "$csv_n_volumes" == "$n_volumes" && "$csv_n_subs" == "$n_subs" && "$iteration" == "$n_iteration" ]]; then
        IC_corrected=$((ic - 1))
        key="${rsn}_${session}"
        IC_mapping["$key"]=$(printf "%04d" "$IC_corrected")
    fi
done < "$INPUT_FILE"

echo -e "RSN\tComparison\tSubject\tDice" > "$output_file"

for rsn in "${rsns[@]}"; do
    echo " RSN: $rsn"

    IC_LR1=${IC_mapping["${rsn}_REST1_LR"]:-}
    IC_RL1=${IC_mapping["${rsn}_REST1_RL"]:-}
    IC_LR2=${IC_mapping["${rsn}_REST2_LR"]:-}
    IC_RL2=${IC_mapping["${rsn}_REST2_RL"]:-}

    if [[ -z "$IC_LR1" || -z "$IC_RL1" || -z "$IC_LR2" || -z "$IC_RL2" ]]; then
        echo "  Missing IC mapping for: $rsn (${n_subs}subs, ${n_volumes}vols, iter $n_iteration)"
        continue
    fi

    ICs_dir="$BASE_DIR/${n_subs}subs"

    for i in $(seq 0 $((n_subs - 1))); do
        subject=$(printf "%05d" "$i")

        path_LR1="$ICs_dir/HCP_REST1_LR_${n_volumes}_${n_subs}subs${iter_suffix}_${IC_OPTIONS}_dual_regression.dr/split_ICs/$subject/IC${IC_LR1}_bin.nii.gz"
        path_RL1="$ICs_dir/HCP_REST1_RL_${n_volumes}_${n_subs}subs${iter_suffix}_${IC_OPTIONS}_dual_regression.dr/split_ICs/$subject/IC${IC_RL1}_bin.nii.gz"
        path_LR2="$ICs_dir/HCP_REST2_LR_${n_volumes}_${n_subs}subs${iter_suffix}_${IC_OPTIONS}_dual_regression.dr/split_ICs/$subject/IC${IC_LR2}_bin.nii.gz"
        path_RL2="$ICs_dir/HCP_REST2_RL_${n_volumes}_${n_subs}subs${iter_suffix}_${IC_OPTIONS}_dual_regression.dr/split_ICs/$subject/IC${IC_RL2}_bin.nii.gz"

        # Intra-session Dice (REST1: LR vs RL)
        if [[ -f "$path_LR1" && -f "$path_RL1" ]]; then
            temp_intra="$temp_dir/tmp_intra_${rsn}_${subject}.nii.gz"
            fslmaths "$path_LR1" -mul "$path_RL1" "$temp_intra"

            vox1=$(fslstats "$path_LR1" -V | awk '{print $1}')
            vox2=$(fslstats "$path_RL1" -V | awk '{print $1}')
            inter=$(fslstats "$temp_intra" -V | awk '{print $1}')
            dice_intra=$(echo "scale=4; (2 * $inter) / ($vox1 + $vox2)" | bc -l)

            echo -e "$rsn\tREST1_LR_RL\t$subject\t$dice_intra" >> "$output_file"
            rm -f "$temp_intra"
        fi

        # Inter-session Dice (REST1_LR vs REST2_RL)
        if [[ -f "$path_LR1" && -f "$path_RL2" ]]; then
            temp_inter="$temp_dir/tmp_inter_LRRL_${rsn}_${subject}.nii.gz"
            fslmaths "$path_LR1" -mul "$path_RL2" "$temp_inter"

            vox1=$(fslstats "$path_LR1" -V | awk '{print $1}')
            vox2=$(fslstats "$path_RL2" -V | awk '{print $1}')
            inter=$(fslstats "$temp_inter" -V | awk '{print $1}')
            dice_inter=$(echo "scale=4; (2 * $inter) / ($vox1 + $vox2)" | bc -l)

            echo -e "$rsn\tREST1_LR_REST2_RL\t$subject\t$dice_inter" >> "$output_file"
            rm -f "$temp_inter"
        fi

        # Inter-session Dice (REST1_RL vs REST2_LR)
        if [[ -f "$path_RL1" && -f "$path_LR2" ]]; then
            temp_inter="$temp_dir/tmp_inter_RLLR_${rsn}_${subject}.nii.gz"
            fslmaths "$path_RL1" -mul "$path_LR2" "$temp_inter"

            vox1=$(fslstats "$path_RL1" -V | awk '{print $1}')
            vox2=$(fslstats "$path_LR2" -V | awk '{print $1}')
            inter=$(fslstats "$temp_inter" -V | awk '{print $1}')
            dice_inter=$(echo "scale=4; (2 * $inter) / ($vox1 + $vox2)" | bc -l)

            echo -e "$rsn\tREST1_RL_REST2_LR\t$subject\t$dice_inter" >> "$output_file"
            rm -f "$temp_inter"
        fi
    done
done

echo "========================================"
echo "Completed: ${n_subs} subjects, ${n_volumes} volumes, iteration ${n_iteration}"
echo "Finished at: $(date)"
echo "Output: $output_file"
echo "========================================"
