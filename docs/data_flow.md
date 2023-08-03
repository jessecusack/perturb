# Data flow for [software suite](https://github.com/jessecusack/perturb/tree/main)

- A list of potential `.P` files that exist in the source directory is created.
- For each of the `.P` files:
  * If a corresponding `.mat` file from ***odas_p2mat*** exists and is newer than the `.P` file, nothing new is done.
  * A new `.mat` file is created by processing the `.P` file with ***odas_p2mat***.
- For each of the ***odas_p2mat*** files:
  * If a corresponding `profiles.mat` file exist and is newer than the ***odas_p2mat*** `.mat` file, nothing new is done.
  * The ***odas_p2mat*** `.mat` file is loaded
  * The file is split into profiles using ***get_profile***
  * [FP07 thermistor](FP07.md) is calibrated against the reference temperature, *JAC_T*, and the slow and fast temperatures from the FP07 thermistors is recomputed. 
