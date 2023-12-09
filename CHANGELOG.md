# 8-Dec-2023: Pat Welch, pat@mousebrains.com
 * Restore path in examples

# 1-Dec-2023: Pat Welch, pat@mousebrains.com
 * Point and click dissipation inspector

# 28-Nov-2023: Pat Welch, pat@mousebrains.com
 * Fix timezone issue with date_created... for NetCDF files

# 27-Nov-2023: Pat Welch, pat@mousebrains.com
 * Implement bottom crash detection for downcast VMPs. This was tested using data from 15-40m casts into the bottom of the Gulf of Mexico off Lousiana/Texas. i.e. a nice soft bottom.
 * Implement bottom trimming and bottom upwards dissipation estimates for VMP downcasts with bottom detection.
 * Implement binning by elevation above the bottom.

# 17-Nov-2023: Pat Welch, pat@mousebrains.com

 * Split up profile and dissipation calculations.
 * Add support for binning profiles by time for use in analyzing AUV data.
- Documenation updates. 

# 19-Oct-2023: Pat Welch, pat@mousebrains.com

## Refactor the code to handle the following:
 * Merged P files are kept in the output_root directory in a merged_p_files
 directory. If the user changes theh p_file_merge setting from true to false,
 the user won't be using a merged P file, like before.
 * Changed from using Matlab's hashKey function to SHA-1. The hashKey had a
  random seed, so between Matlab sessions, the generated hash of a
  configuration was not stable. With SHA-1 it now is stable.
 * Changed the output directory filenaming from a prefix plus the hash key
  of the configuration, to a sequential numbering as the configuration
  changes. There is now a JSON file, with the configuration parameters for
  that section in it.
 * Renamed `process_VMP_files` to `process_P_files` to reflect it is dealing
  with both MR and VMP P files.
 * Changed processing from all the `odas_p2mat` operations, then generating
   all the profiles, then binning, then to combining everything, into a
   pipeline for each P file. This reduced the amount of disk reads and
   decreases the execution time by ~20%.
 * Changed many of the operations to be parallelized using parfor. This
  reduces the execution time by roughly 50% of the number of cores. i.e. a 10
  core system reduces the execution time to roughly 20% of the single process
  execution time.
 * Changed all the `example` scripts for the refactored code.
