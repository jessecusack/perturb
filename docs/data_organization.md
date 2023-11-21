# The output data is orginized into a set of directories.

The trailing four digits of the directories are sequential and correspond to a unique set of parameters. The parameters corresponding to the directory are stored in a ***JSON*** file inside the directory.

## We treat the input `.P` files as if they are in a read-only directory. The ODAS library does not, so it may try to modify some of the `.P` files in the input directory.

* trimed_p_files are `.P` files which had bad buffers and have been trimmed.
* merged_p_files are `.P` files which have been glued together. If a `.P` file reaches a specified size, it is closed and a new `.P` file is opened. This does not lose any data. For Rockland firmware version 6.1 and before, the timestamps are not correct for the subsequent file. The merged_p_files will have the correct time stamps.
* Matfiles_0000 contains the output of odas_p2mat.
* profiles_0000 contains the individual profiles.
* profiles_binned_0000 contains the depth or time binned version of profiles_0000.
* profiles_combo_0000 contains the glued together binned profiles from profiles_binned_0000.
* diss_0000 contains the dissipation estimates for each from profiles_0000.
* diss_binned_0000 contains the depth or time binned dissipation estimtes from diss_0000.
* diss_combo_0000 contains the glued together binned dissipation estimates from diss_binned_0000.
* CTD_0000 is the time binned scalar variables for an entire `.P` file from Matfiles_0000.
* CTD_combo_0000 is the glued together time binned scalar variables from CTD_0000.
