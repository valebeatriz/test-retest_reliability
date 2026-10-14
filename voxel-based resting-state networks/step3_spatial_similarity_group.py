#!/usr/bin/env python3
"""
step3_spatial_similarity_group.py
 
Run after step2_dice_group.sh. Finds, for every RSN and run, the group-ICA
component with the highest Dice against the Yeo template, and writes:
 
  dice_GROUP.xlsx
    - All_Data:           best-matching IC and its Dice, for every
                          (RSN, session, n_volumes, n_subs, iteration).
    - Summary_Statistics: mean/std of that Dice across iterations.
 
NOTE on "manual": the IC with the highest Dice was selected for each RSN, with
an exception for the VN. ICA typically splits the VN into several subcomponents
(e.g., medial, lateral and occipital visual areas), giving about 3 ICs with
similarly high Dice. For the VN, the three ICs with the top Dice values were
inspected visually, and the ones corresponding to the same visual subnetwork
across sessions/runs were chosen, so the selected IC is not always the one with
the highest Dice. The corrected table is saved as
dice_GROUP_manual.csv.

Its columns are
rsn,session,n_volumes,n_subs,iteration,ic ("ic" is 1-indexed), and it is the
INPUT_FILE that step4_dice_group_runs.sh and step7_dice_subject_runs.sh read.
 
Usage: python step3_spatial_similarity_group.py /path/to/dice_reg
  (expects dice_<n_subs>subs/group_dice_HCP_<session>_<n_volumes>_<n_subs>subs_<iter>_<ICA_options>.txt)

"""

import pandas as pd
import os
import sys

# Configuration
ICA_options = "IC50"
base_path = sys.argv[1] if len(sys.argv) > 1 else "./dice_reg"
RSNs = ["VN", "SMN", "DAN", "VAN", "LN", "FPN", "DMN"]

# Define subject groups and their folder mappings
subject_groups = {
    10: "dice_10subs",
    20: "dice_20subs",
    50: "dice_50subs",
    80: "dice_80subs"
}

sessions = ["REST1_LR", "REST1_RL", "REST2_LR", "REST2_RL"]
volumes = [300, 600, 900, 1200]
iterations = range(1, 11)  # every subsample size was drawn 10 times

if not os.path.exists(base_path):
    sys.exit(f"Error: base path does not exist: {base_path}")

print("=" * 80)
print("Processing GROUP-level files")
print("=" * 80)

group_results_list = []

# Process each subject group
for n_subs, folder in subject_groups.items():
    folder_path = os.path.join(base_path, folder)

    if not os.path.exists(folder_path):
        print(f"Warning: Folder not found: {folder_path}")
        continue

    for session in sessions:
        for n_volumes in volumes:
            for iteration in iterations:
                filename = f"group_dice_HCP_{session}_{n_volumes}_{n_subs}subs_{iteration}_{ICA_options}.txt"
                file_path = os.path.join(folder_path, filename)

                if not os.path.exists(file_path):
                    print(f"Warning: File not found: {file_path}")
                    continue

                try:
                    # rows = ICs, columns = RSNs (whitespace-separated, as written by step2)
                    df = pd.read_csv(file_path, sep=r"\s+", names=RSNs, header=None)
                    df.insert(0, "IC", range(1, len(df) + 1))

                    # Best-matching IC (highest Dice) for each RSN
                    for RSN in RSNs:
                        max_value = df[RSN].max()
                        max_ic = df.loc[df[RSN].idxmax(), "IC"]

                        group_results_list.append({
                            "rsn": RSN,
                            "session": session,
                            "n_volumes": n_volumes,
                            "n_subs": n_subs,
                            "n_iteration": iteration,
                            "dice": max_value,
                            "IC": max_ic
                        })

                    print(f"✓ Processed: {filename}")

                except Exception as e:
                    print(f"Error processing {file_path}: {str(e)}")
                    continue

if not group_results_list:
    sys.exit("Error: no group Dice files were found. Check base path and file names.")

# Create group DataFrame
group_results_df = pd.DataFrame(group_results_list)
group_results_df = group_results_df.sort_values(by=["rsn", "session", "n_volumes", "n_subs", "n_iteration"]).reset_index(drop=True)

# Create group summary statistics (mean/std of best-match Dice across iterations)
group_summary_list = []

for rsn in RSNs:
    for session in sessions:
        for n_volumes in volumes:
            for n_subs in subject_groups.keys():
                filtered = group_results_df[
                    (group_results_df['rsn'] == rsn) &
                    (group_results_df['session'] == session) &
                    (group_results_df['n_volumes'] == n_volumes) &
                    (group_results_df['n_subs'] == n_subs)
                ]

                if not filtered.empty:
                    group_summary_list.append({
                        "rsn": rsn,
                        "session": session,
                        "n_volumes": n_volumes,
                        "n_subs": n_subs,
                        "mean_dice": filtered['dice'].mean(),
                        "std_dice": filtered['dice'].std()
                    })

group_summary_df = pd.DataFrame(group_summary_list)
group_summary_df = group_summary_df.sort_values(by=["rsn", "session", "n_volumes", "n_subs"]).reset_index(drop=True)

# Save group-level Excel
group_output_file = os.path.join(base_path, "dice_GROUP.xlsx")

with pd.ExcelWriter(group_output_file, engine='openpyxl') as writer:
    group_results_df.to_excel(writer, sheet_name='All_Data', index=False)
    group_summary_df.to_excel(writer, sheet_name='Summary_Statistics', index=False)

print(f"\n✓ Group results saved to: {group_output_file}")
print(f"Total records in group All_Data: {len(group_results_df)}")
