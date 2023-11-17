# Data flow for [software suite](https://github.com/jessecusack/perturb/tree/main)

- A list of potential `.P` files that exist in the *p_file_root* directory is created.
- The original `.P` file is checked to see if the final buffer is corrupted. If so, the original `.P` file is trimmed and written to a `trim_p_files` directory.
- All the `.P` file headers are examined to see if they were created by the previous file "sizing" out. If so, then the previous and this file are appended to create a single `.P` file and written to the `merged_p_files` directory. [p_file_merger.m](../Code/p_file_merger.m)
- For each good `.P` file:
  * Using `odas_p2mat` convert the good `.P` file to an odas_p2mat `.mat` file in a directory like `Matfiles_0000`. See [convert2mat.m](../Code/convert2mat.m)
  * Create the profiles `.mat` file:
    - Split the odas_p2mat `.mat` file into profiles.
    - Assign a GPS fix to for each profile. See [GPS details](GPS.details.md) for how this is done.
    - Adjust FP07 sensors in time to match shear sensors using cross correlation.
    - If a temperature reference exists, using all the profiles in this file:
      * Adjust temperature reference in time to match the adjusted FP07 sensors using cross correlation.
      * Do an in-situ calibration of the FP07 sensors agains the temperature reference.
    - If a conductivity value exists, adjust it in time to match thea adjusted temperature reference using cross correlation.
    - If CT information is available, calculate seawater properties, like salinity, density, ...
    - The profiles `.mat` file is saved in a directory like `profiles_0000`.
  * Create a binned profiles `.mat` file:
    - Bin the profiles by depth or time and merge into a single table.
    - Save the binned profiles to a directory like `profiles_binned_0000`.
  * Create a dissipation `.mat` file:
    - Calculate dissipations for each of the profiles.
    - Calculate the expected dissipation variance, and merge multiple dissipation estimates together appropriately.
    - Save the dissipation estimates in a directory like `diss_0000`.
  * Create a binned dissipation `.mat` file:
    - Bin the disspation estimates by depth or time and merge into a single table.
    - Save the binned dissipations to a directory like `diss_binned_0000`.
  * Create a time binned scalar `.mat` file:
    - Time bin the scalar data for the whole odas_p2mat `.mat` file.
    - Assign a GPS fix to for each profile. See [GPS details](GPS.details.md) for how this is done.
    - Save the binned scalar data to a directory like `CTD_0000`.
- For all the `.P` files:
  * Create a profiles combo `.mat` file by merging together all the binned profiles to directory like `profiles_combo_0000`.
  * Create a dissipation combo `.mat` file by merging together all the binned dissipation estimates to a directory like `diss_combo_0000`.
  * Create a binned scalar combo `.mat` file by merging together all the time binned scalar estimates to a directory like `CTD_combo_0000`.

