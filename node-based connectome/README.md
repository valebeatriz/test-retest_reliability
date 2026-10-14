# Node-based connectome metrics pipeline

MATLAB pipeline that parcellates HCP resting-state fMRI (Schaefer 400, Yeo 7 networks), computes functional connectivity (FC), and tests its test-retest reliability with:

- edge-level ICC, averaged within each network
- connectome-level ICC (one value per subject)
- connectome correlation (Iself)
- connectome fingerprinting (Idiff, success rate)
- discriminability

Each metric is swept across subject counts (10, 20, 50, 80), volume counts (300, 600, 900, 1200) and session type (INTRA or INTER), using one of three volume-selection methods:

- **truncation**: the first N volumes
- **scrubbing**: N random, non-contiguous volumes
- **segment**: one random, contiguous window of N volumes

## Setup

Add the whole folder and subfolders to the MATLAB path before running anything.

## Data

Preprocessed data is expected in `<data>/preprocessed/<subject>/<session>/<session>_hpf_clean_smooth.nii.gz`. `<data>` is `<repo>/data` by default, or the folder set in the environment variable `FINGERPRINTING_DATA_ROOT`. Outputs are written to `<data>/derivatives/`.

## Run order

**Steps 0-3: prepare the data (once)**
```matlab
run('scripts/step0_parcellation_config.m')    % writes the step 1 config
run('scripts/step1_parcellation.m')           % parcellate (Schaefer 400)
run('scripts/step2_parcellation_reorder.m')   % reorder regions by Yeo network
run('scripts/step3_parcellation_volumes.m')   % first 300/600/900 volumes (truncation only)
```

**Step 4: run the sweep(s) you need**
```matlab
run('scripts/step4_RUN_ALL_truncation.m')
run('scripts/step4_RUN_ALL_scrubbing.m')
run('scripts/step4_RUN_ALL_segment.m')
```
For every combination and each of the 100 internal iterations, a RUN_ALL script runs:

1. stage 1: FC matrices (Pearson)
2. stage 1b: Fisher z-transform and test/retest pairing
3. stage 2: fingerprinting (Idiff, Iself, success rate)
4. stage 3: edge-level ICC averaged within each network
5. stage 4: discriminability
6. stage 5: connectome-level ICC

Results are saved as one `.mat` per combination in `<data>/derivatives/ICC_Idiff_Discr/`.

**Session types**

- **INTRA**: REST1_LR vs REST1_RL
- **INTER**: REST1_LR vs REST2_RL, or REST1_RL vs REST2_LR
