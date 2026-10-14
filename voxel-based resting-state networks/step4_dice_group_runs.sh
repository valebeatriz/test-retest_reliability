#!/bin/bash
#
# step3_dice_group_runs.sh
#
# Computes intra- and inter-session Dice overlap (LR vs RL) for the
# RSN-matched IC of each RSN, across every (subsample size, volume count,
# iteration) combination. For each combination it looks up the matched IC
# index from a manually curated CSV (INPUT_FILE) and computes:
#   - intra-session:  REST1_LR vs REST1_RL
#   - inter-session:  REST1_LR vs REST2_RL, and REST1_RL vs REST2_LR
#
# Usage: ./step3_dice_group_runs.sh  (no arguments; configure via env vars)
#
# Optional env vars:
#   BASE_DIR        Root of per-subsample-size ICA output (default:
#                   ./derivatives_reg/ICA).
#   INPUT_FILE      CSV mapping rsn,session,n_volumes,n_subs,iteration,ic
#                   (default: <BASE_DIR>/dice_GROUP_manual.csv, exported from
#                   step3's dice_GROUP.xlsx).
#                   "ic" is 1-indexed; converted to 0-indexed IC0000 filenames.
#   N_VOLUMES_LIST  Volume counts to sweep (default: "300 600 900 1200").
#   N_SUBS_LIST     Subsample sizes to sweep (default: "10 20 50 80").
#                   Every subsample size uses iterations 1-10.
#   RSNS            RSN names to process (default: "DAN DMN FPN LN SMN VAN VN").
#
# Expects IC maps at (produced by step2_dice_group.sh):
#   <BASE_DIR>/<n_subs>subs/HCP_<session>_<n_volumes>_<n_subs>subs[_<iter>]_IC50/all_ICs/IC<index>_bin.nii.gz

module load fsl

BASE_DIR="${BASE_DIR:-./derivatives_reg/ICA}"
INPUT_FILE="${INPUT_FILE:-$BASE_DIR/dice_GROUP_manual.csv}"

read -ra n_volumes_list <<< "${N_VOLUMES_LIST:-300 600 900 1200}"
read -ra n_subs_list <<< "${N_SUBS_LIST:-10 20 50 80}"
read -ra rsns <<< "${RSNS:-DAN DMN FPN LN SMN VAN VN}"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: IC mapping CSV not found: $INPUT_FILE" >&2
    echo "Set INPUT_FILE to a CSV with columns: rsn,session,n_volumes,n_subs,iteration,ic" >&2
    exit 1
fi

# Map: RSN + session + n_volumes + n_subs + iteration -> matched IC index
declare -A IC_mapping

while IFS=',' read -r rsn session csv_n_volumes csv_n_subs iteration ic; do
    ic=$(echo "$ic" | xargs)
    iteration=$(echo "$iteration" | xargs)
    rsn=$(echo "$rsn" | xargs)
    session=$(echo "$session" | xargs)
    csv_n_volumes=$(echo "$csv_n_volumes" | xargs)
    csv_n_subs=$(echo "$csv_n_subs" | xargs)

    if [[ "$ic" =~ ^[0-9]+$ ]]; then
        # CSV stores 1-indexed IC numbers; convert to 0-indexed IC0000 filenames.
        IC_corrected=$((ic - 1))
        key="${rsn}_${session}_${csv_n_volumes}_${csv_n_subs}_${iteration}"
        IC_mapping["$key"]=$(printf "%04d" "$IC_corrected")
    fi
done < "$INPUT_FILE"

for n_subs in "${n_subs_list[@]}"; do
    output_dir="$BASE_DIR/dice_${n_subs}subs_runs"
    mkdir -p "$output_dir"

    for n_volumes in "${n_volumes_list[@]}"; do
        echo "========================================"
        echo "Processing: ${n_subs} subjects, ${n_volumes} volumes"
        echo "========================================"

        # Each subsample size was drawn 10 times.
        for iter in {1..10}; do
            echo "Processing iteration: $iter"
            output_file="$output_dir/dice_group_runs_${n_volumes}_${n_subs}subs_${iter}.txt"
            iter_suffix="_${iter}"

            echo -e "RSN\tComparison\tDice" > "$output_file"

            for rsn in "${rsns[@]}"; do
                echo " RSN: $rsn"

                key_LR1="${rsn}_REST1_LR_${n_volumes}_${n_subs}_${iter}"
                key_RL1="${rsn}_REST1_RL_${n_volumes}_${n_subs}_${iter}"
                key_LR2="${rsn}_REST2_LR_${n_volumes}_${n_subs}_${iter}"
                key_RL2="${rsn}_REST2_RL_${n_volumes}_${n_subs}_${iter}"

                IC_LR1=${IC_mapping["$key_LR1"]:-}
                IC_RL1=${IC_mapping["$key_RL1"]:-}
                IC_LR2=${IC_mapping["$key_LR2"]:-}
                IC_RL2=${IC_mapping["$key_RL2"]:-}

                if [[ -z "$IC_LR1" || -z "$IC_RL1" || -z "$IC_LR2" || -z "$IC_RL2" ]]; then
                    echo "  Missing IC mapping for: $rsn (${n_subs}subs, ${n_volumes}vols, iter $iter) — LR1=${IC_LR1}, RL1=${IC_RL1}, LR2=${IC_LR2}, RL2=${IC_RL2}"
                    continue
                fi

                path_LR1="$BASE_DIR/${n_subs}subs/HCP_REST1_LR_${n_volumes}_${n_subs}subs${iter_suffix}_IC50/all_ICs/IC${IC_LR1}_bin.nii.gz"
                path_RL1="$BASE_DIR/${n_subs}subs/HCP_REST1_RL_${n_volumes}_${n_subs}subs${iter_suffix}_IC50/all_ICs/IC${IC_RL1}_bin.nii.gz"
                path_LR2="$BASE_DIR/${n_subs}subs/HCP_REST2_LR_${n_volumes}_${n_subs}subs${iter_suffix}_IC50/all_ICs/IC${IC_LR2}_bin.nii.gz"
                path_RL2="$BASE_DIR/${n_subs}subs/HCP_REST2_RL_${n_volumes}_${n_subs}subs${iter_suffix}_IC50/all_ICs/IC${IC_RL2}_bin.nii.gz"

                # Intra-session Dice (REST1: LR vs RL)
                if [[ -f "$path_LR1" && -f "$path_RL1" ]]; then
                    temp_intra="$output_dir/tmp_intra_${rsn}_${n_volumes}_${n_subs}${iter_suffix}.nii.gz"
                    fslmaths "$path_LR1" -mul "$path_RL1" "$temp_intra"
                    vox1=$(fslstats "$path_LR1" -V | awk '{print $1}')
                    vox2=$(fslstats "$path_RL1" -V | awk '{print $1}')
                    inter=$(fslstats "$temp_intra" -V | awk '{print $1}')
                    dice_intra=$(echo "scale=4; (2 * $inter) / ($vox1 + $vox2)" | bc -l)
                    echo -e "$rsn\tREST1_LR_RL\t$dice_intra" >> "$output_file"
                    rm -f "$temp_intra"
                else
                    echo "  Missing IC files for INTRA-session $rsn (${n_subs}subs, ${n_volumes}vols, iter $iter)"
                    [[ ! -f "$path_LR1" ]] && echo "    Not found: $path_LR1"
                    [[ ! -f "$path_RL1" ]] && echo "    Not found: $path_RL1"
                fi

                # Inter-session Dice (REST1_LR vs REST2_RL)
                if [[ -f "$path_LR1" && -f "$path_RL2" ]]; then
                    temp_inter="$output_dir/tmp_inter_LRRL_${rsn}_${n_volumes}_${n_subs}${iter_suffix}.nii.gz"
                    fslmaths "$path_LR1" -mul "$path_RL2" "$temp_inter"
                    vox1=$(fslstats "$path_LR1" -V | awk '{print $1}')
                    vox2=$(fslstats "$path_RL2" -V | awk '{print $1}')
                    inter=$(fslstats "$temp_inter" -V | awk '{print $1}')
                    dice_inter=$(echo "scale=4; (2 * $inter) / ($vox1 + $vox2)" | bc -l)
                    echo -e "$rsn\tREST1_LR_REST2_RL\t$dice_inter" >> "$output_file"
                    rm -f "$temp_inter"
                else
                    echo "  Missing IC files for INTER-session $rsn (${n_subs}subs, ${n_volumes}vols, iter $iter)"
                    [[ ! -f "$path_LR1" ]] && echo "    Not found: $path_LR1"
                    [[ ! -f "$path_RL2" ]] && echo "    Not found: $path_RL2"
                fi

                # Inter-session Dice (REST1_RL vs REST2_LR)
                if [[ -f "$path_RL1" && -f "$path_LR2" ]]; then
                    temp_inter="$output_dir/tmp_inter_RLLR_${rsn}_${n_volumes}_${n_subs}${iter_suffix}.nii.gz"
                    fslmaths "$path_RL1" -mul "$path_LR2" "$temp_inter"
                    vox1=$(fslstats "$path_RL1" -V | awk '{print $1}')
                    vox2=$(fslstats "$path_LR2" -V | awk '{print $1}')
                    inter=$(fslstats "$temp_inter" -V | awk '{print $1}')
                    dice_inter=$(echo "scale=4; (2 * $inter) / ($vox1 + $vox2)" | bc -l)
                    echo -e "$rsn\tREST1_RL_REST2_LR\t$dice_inter" >> "$output_file"
                    rm -f "$temp_inter"
                else
                    echo "  Missing IC files for INTER-session $rsn (${n_subs}subs, ${n_volumes}vols, iter $iter)"
                    [[ ! -f "$path_RL1" ]] && echo "    Not found: $path_RL1"
                    [[ ! -f "$path_LR2" ]] && echo "    Not found: $path_LR2"
                fi
            done
        done
    done
done

echo "========================================"
echo "Dice computation complete for all combinations."
echo "========================================"
