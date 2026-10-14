# Voxel-based RSN Analysis

Group-level ICA (FSL MELODIC) is run on Human Connectome Project resting-state data, and
the components matching the 7 Yeo (2011) networks are identified by their
spatial overlap (Dice coefficient) with the Yeo templates. Subject-level maps
are then obtained with dual regression.

We assess how scan length (300, 600, 900, 1200 volumes) and sample size (10,
20, 50, 80 participants) affect:
- spatial similarity to the Yeo networks;
- within-session reliability (Dice between the LR and RL runs of the same session);
- between-session reliability (Dice between runs from REST1 and REST2).

Each sample size was drawn 10 times, and results are reported as the mean and
std across these iterations.

## Pipeline

| Step | Script | Level | What it does |
|---|---|---|---|
| 1 | `step1_melodic.sh` | Group | Runs FSL MELODIC group-ICA. |
| 2 | `step2_dice_group.sh` | Group | Splits and binarizes group ICs, computes Dice against each Yeo RSN template. |
| 3 | `step3_spatial_similarity_group.py` | Group | Selects the best-matching IC per RSN and run; writes `dice_GROUP.xlsx`. |
| 4 | `step4_dice_group_runs.sh` | Group | Intra-/inter-session Dice of the matched ICs. |
| 5 | `step5_dualregression.sh` | Subject | Runs FSL `dual_regression` to obtain subject maps. |
| 6 | `step6_dice_subject.sh` | Subject | Splits and binarizes subject maps, computes Dice against each RSN template. |
| 7 | `step7_dice_subject_runs.sh` | Subject | Intra-/inter-session Dice per subject. |
| 8 | `step8_spatial_similarity_individual.py` | Subject | Reads each subject's Dice at the group-matched IC; writes `dice_INDIVIDUAL.xlsx`. |

Run the steps in order. Steps 4 and 7 need the IC mapping CSV
(`dice_GROUP_manual.csv`) exported from step 3 after visual checking.

## Requirements

FSL, Bash, Python (pandas, openpyxl)

## RSN templates

Steps 2 and 6 expect the Yeo (2011) templates in a `templates/` folder next to
the scripts:

```
Yeo_rsn0000.nii.gz   # Visual (VN)
Yeo_rsn0001.nii.gz   # Somatomotor (SMN)
Yeo_rsn0002.nii.gz   # Dorsal Attention (DAN)
Yeo_rsn0003.nii.gz   # Ventral Attention (VAN)
Yeo_rsn0004.nii.gz   # Limbic (LN)
Yeo_rsn0005.nii.gz   # Frontoparietal (FPN)
Yeo_rsn0006.nii.gz   # Default Mode (DMN)
```

## Notes

- Dice coefficient: `2 * |A ∩ B| / (|A| + |B|)` on binarized maps (|Z| > 3).