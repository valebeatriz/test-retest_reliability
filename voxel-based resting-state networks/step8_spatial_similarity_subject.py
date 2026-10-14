#!/usr/bin/env python3
"""
step8_spatial_similarity_subject.py

Run after step6_dice_subject.sh. For every subject, reads that subject's Dice
at the IC that was matched to each RSN at the group level and writes:

  dice_INDIVIDUAL.xlsx
    - All_Data:           each subject's Dice at the group-matched IC.
    - Summary_Statistics: two-step average (mean across subjects within each
                          iteration, then mean/std across iterations).

The group-matched ICs come from the output of step3_spatial_similarity_group.py

Usage: python step8_spatial_similarity_individual.py /path/to/dice_reg [group_matches_file]
  (expects dice_<n_subs>subs/DR/<subject>_HCP_<session>_<n_volumes>_<n_subs>subs_<iter>_<ICA_options>.txt)

Requires: pandas, openpyxl.
"""

import pandas as pd
import os
import sys

# Configuration
ICA_options = "IC50"
base_path = sys.argv[1] if len(sys.argv) > 1 else "./dice_reg"
group_file = sys.argv[2] if len(sys.argv) > 2 else os.path.join(base_path, "dice_GROUP_manual.xlsx")
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
if not os.path.exists(group_file):
    sys.exit(f"Error: group matches file not found: {group_file} (run step3 first)")

# ==================== LOAD GROUP-MATCHED ICs ====================
if group_file.lower().endswith(".csv"):
    # No header assumed; a header row (non-numeric "ic") is dropped below
    group_results_df = pd.read_csv(
        group_file, header=None, usecols=range(6),
        names=["rsn", "session", "n_volumes", "n_subs", "n_iteration", "IC"], dtype=str
    )
    for col in group_results_df.columns:
        group_results_df[col] = group_results_df[col].str.strip()
    group_results_df["IC"] = pd.to_numeric(group_results_df["IC"], errors="coerce")
    group_results_df = group_results_df.dropna(subset=["IC"])
    for col in ["n_volumes", "n_subs", "n_iteration", "IC"]:
        group_results_df[col] = group_results_df[col].astype(int)
else:
    group_results_df = pd.read_excel(group_file, sheet_name="All_Data")

print(f"Loaded {len(group_results_df)} group-matched ICs from {group_file}")

# ==================== INDIVIDUAL SUBJECT ANALYSIS ====================
print("=" * 80)
print("Processing INDIVIDUAL subject files")
print("=" * 80)

subject_results_list = []

for n_subs, folder in subject_groups.items():
    dr_folder = os.path.join(base_path, folder, "DR")

    if not os.path.exists(dr_folder):
        print(f"Warning: DR folder not found: {dr_folder}")
        continue

    # Get unique subject IDs from filenames in this folder
    subject_ids = set()
    for file in os.listdir(dr_folder):
        if file.endswith(f"_{ICA_options}.txt"):
            subject_ids.add(file.split("_")[0])

    print(f"\nProcessing {len(subject_ids)} subjects for n_subs={n_subs}")

    for subject_id in sorted(subject_ids):
        for session in sessions:
            for n_volumes in volumes:
                for iteration in iterations:
                    filename = f"{subject_id}_HCP_{session}_{n_volumes}_{n_subs}subs_{iteration}_{ICA_options}.txt"
                    file_path = os.path.join(dr_folder, filename)

                    if not os.path.exists(file_path):
                        continue

                    try:
                        df = pd.read_csv(file_path, sep=r"\s+", names=RSNs, header=None)
                        df.insert(0, "IC", range(1, len(df) + 1))

                        # For each RSN, look up the IC matched in the group analysis
                        for RSN in RSNs:
                            group_match = group_results_df[
                                (group_results_df['rsn'] == RSN) &
                                (group_results_df['session'] == session) &
                                (group_results_df['n_volumes'] == n_volumes) &
                                (group_results_df['n_subs'] == n_subs) &
                                (group_results_df['n_iteration'] == iteration)
                            ]

                            if not group_match.empty:
                                ic_number = int(group_match['IC'].values[0])

                                # This subject's Dice at that IC
                                if ic_number <= len(df):
                                    dice_value = df.loc[df['IC'] == ic_number, RSN].values[0]

                                    subject_results_list.append({
                                        "subject_id": subject_id,
                                        "rsn": RSN,
                                        "session": session,
                                        "n_volumes": n_volumes,
                                        "n_subs": n_subs,
                                        "n_iteration": iteration,
                                        "IC": ic_number,
                                        "dice": dice_value
                                    })

                        print(f"✓ Processed: {filename}")

                    except Exception as e:
                        print(f"Error processing {file_path}: {str(e)}")
                        continue

if not subject_results_list:
    sys.exit("Error: no subject Dice files were matched. Check base path, DR folders and file names.")

# Create subject DataFrame
subject_results_df = pd.DataFrame(subject_results_list)
subject_results_df = subject_results_df.sort_values(
    by=["rsn", "session", "n_volumes", "n_subs", "n_iteration", "subject_id"]
).reset_index(drop=True)

# Create subject summary statistics with two-step averaging
subject_summary_list = []

for rsn in RSNs:
    for session in sessions:
        for n_volumes in volumes:
            for n_subs in subject_groups.keys():
                filtered = subject_results_df[
                    (subject_results_df['rsn'] == rsn) &
                    (subject_results_df['session'] == session) &
                    (subject_results_df['n_volumes'] == n_volumes) &
                    (subject_results_df['n_subs'] == n_subs)
                ]

                if not filtered.empty:
                    # Step 1: mean across subjects within each iteration
                    iteration_means = []
                    for iteration in filtered['n_iteration'].unique():
                        iteration_data = filtered[filtered['n_iteration'] == iteration]
                        iteration_means.append(iteration_data['dice'].mean())

                    # Step 2: mean and std across iterations
                    mean_value = sum(iteration_means) / len(iteration_means)
                    std_value = 0.0 if len(iteration_means) == 1 else pd.Series(iteration_means).std()

                    subject_summary_list.append({
                        "rsn": rsn,
                        "session": session,
                        "n_volumes": n_volumes,
                        "n_subs": n_subs,
                        "mean_dice": mean_value,
                        "std_dice": std_value,
                        "n_iterations": len(iteration_means),
                        "n_subjects": len(filtered['subject_id'].unique()),
                        "n_data_points": len(filtered)
                    })

subject_summary_df = pd.DataFrame(subject_summary_list)
subject_summary_df = subject_summary_df.sort_values(
    by=["rsn", "session", "n_volumes", "n_subs"]
).reset_index(drop=True)

# Save subject-level Excel
subject_output_file = os.path.join(base_path, "dice_INDIVIDUAL.xlsx")

with pd.ExcelWriter(subject_output_file, engine='openpyxl') as writer:
    subject_results_df.to_excel(writer, sheet_name='All_Data', index=False)
    subject_summary_df.to_excel(writer, sheet_name='Summary_Statistics', index=False)

print(f"\n✓ Individual subject results saved to: {subject_output_file}")
print(f"Total records in individual All_Data: {len(subject_results_df)}")
print(f"Total records in individual Summary: {len(subject_summary_df)}")
