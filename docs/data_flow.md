# Data flow for [software suite](https://github.com/jessecusack/perturb/tree/main)

- A list of potential `.P` files that exist in the *vmp_root* directory is created.
- All the `.P` file headers are examined to see if they were created by the previous file "sizing" out. If so, then the previous and this file are appended to create a single `.P` file. [p_file_merger.m](../Code/p_file_merger.m)
- A list of potential `.P` files that exist in the *vmp_root* directory is created, after the previous step.
- For each of the `.P` files: [mat2profiles.m](../Code/mat2profiles.m)
  * If a corresponding `.mat` file from ***odas_p2mat*** exists and is newer than the `.P` file, nothing new is done.
  * A new `.mat` file is created by processing the `.P` file with ***odas_p2mat***.
- For each of the ***odas_p2mat*** files:
  * If a corresponding `profiles.mat` file exist and is newer than the ***odas_p2mat*** `.mat` file, nothing new is done.
  * The ***odas_p2mat*** `.mat` file is loaded
  * The file is split into profiles using ***get_profile***
  * [FP07 thermistor](FP07.md) is calibrated against the reference temperature, *JAC_T*, and the slow and fast temperatures from the FP07 thermistors is recomputed.  [FP07_calibration.m](../Code/fp07_calibration.m)
  * For each profile the conductivity/temperature lag is estimated. A median weighted lag is estimated from all the profiles. This median weighted lag is used to adjust the timing of the conductivity sensor for the entire file. [CT_align.m](../Code/CT_align.m)
  * The non-turbulence sensors, CTD, DO, Chlorophyll, Turbidity, ... are collected and a not-insane Geo-reference is assigned for each observation through out the file. [mkCTD.m](../Code/mkCTD.m)
  * For each profile found by ***get_profile:***
    - A Geo-reference is assigned as of the start of the profile.
    - A table of all the *slow* variables is created
    - A table of all the *fast* variables is created
    - Seawater properties are computed for each slow observation in the profile.
  * All the profiles are used to determine the expected variances to determine when the instrument is stable and able to provide "good" dissipation estimates. [trim_profiles.m](../Code/trim_profiles.m)
  * All the profiles are used to determine the expected variances to determine when the instrument crashed into the bottom. [bottom_crash_profiles.m](../Code/bottom_crash_profiles.m)
  * For each profile, dissipation estimates are computed. [calc_diss_shear.m](../Code/calc_diss_shear.m)
  * The collection of profiles and associated ancillary data is written to a `profiles.mat` file.
- For each of the `profiles.mat` file:
  * The profiles are binned in depth and written to a `binned.mat` file. [bin_data.m](../Code/bin_data.m) 
  * The non-turbulence sensors for the entire file are binned in time and written to a `CTD.mat` file. [bin_CTD.m](../Code/bin_CTD.m) 
- For each of the `binned.mat` files, the binned profiles are collected and written to a `combo.mat` file. [mk_combo.m](../Code/mk_combo.m)

