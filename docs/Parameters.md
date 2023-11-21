# Description of input parameters to [process_p_files](../Code/process_p_files.m)`

For examples of calling [process_P_files](../Code/process_P_files.m), please see [Examples](../Examples).

To see all the current parameters, please execute `process_P_files` for the names and defaults.

The parameter functionality is grouped by the parameter prefix:
- `p_file_` control where the P files are located, and how they are selected.
- `gps_` control how GPS locations are selected.
- `p2mat_` control the conversion from `.P` files to `.mat` files via ***odas_p2mat***.
- `profile_` control how profiles are extracted from the data.
- `trim_` For downcast VMP data, how to calculate the where good data starts.
- `bottom_` For bottom crashing VMP data, how the bottom depth is calculated, i.e. where the good data ends. (Not currently implemented.)
- `fp07_` How the FP07 sensors are adjusted in time and the in-situ calibration is done.
- `CT_` What is the name of the refereence temperature and conductivity. For VMPs, this is commonly JAC_T and JAC_C.
- `despike_` Despiking parameters used in dissipation estimates.
- `diss_` Dissipation estimation parameters.
- `bin_` How profile bins are constructed.
- `binDiss_` How dissipation bins are constructed.
- `ctd_` How to calculate CTD bins
- `netCDF_` NetCDF global metadata parameters

## Individual parameters

- `p_file_` control where the P files are located, and how they are selected.
  * `p_file_root` is the parent directory that `p_file_pattern` is append to to locate the `.P` files.
  * `p_file_pattern` is a glob pattern appended to `p_file_root` to locate the `.P` files. If one stores their P files in directories like SN555 and SN1038, representing the instrument's serial number, the `p_file_pattern` would be ***SN*/**** **Please note, you don't need a `.P` suffix on your pattern, that is handled by [find_P_filenames](../Code/find_P_filenames.m).
- `gps_` control how GPS locations are selected.
  * `gps_class` is a class handle derived from [GPS_base_class.m](../Code/GPS_base_class.m). Please see [Examples](../Examples) for how to set `gps_class`.
  * `gps_max_time_diff` controls if a warning is generated for a GPS fix which is a long time from the current time.
- `p2mat_` control the conversion from `.P` files to `.mat` files via ***odas_p2mat***. Please see ***odas*** documentation for the following parameters. See [convert2mat](../Code/convert2mat.m)
  * `p2mat_aoa` Angle of attack.
  * `p2mat_constant_speed` Axial speed of the instrument in m/s.
  * `p2mat_constant_temp` Water temperature in Celsius.
  * `p2mat_gradC_method` Gradient method for micro-conductivity.
  * `p2mat_gradT_method` Gradient method for micro-conductivity.
  * `p2mat_hotel_file` Hotel filename.
  * `p2mat_speed_cutout` Speeds are floored at this value.
  * `p2mat_speed_tau` Speed smoothing parameter.
  * `p2mat_time_offset` Time skew of the instrument in seconds.
  * `p2mat_vehicle` Vehicle's processing name.
- `profile_` control how profiles are extracted from the data. Please see ***ODAS's get_profile*** for an explantion of the parameters. See [mat2profile](../Code/mat2profile.m)
  * `profile_pressure_min` Minimum pressure pressure for a profile in dbar.
  * `profile_speed_min` Minimum vertical speed for a profile in m/s.
  * `profile_min_duration` Minimum length of a profile in seconds.
  * `profile_direction` Up and down are as described in the ***ODAS*** manual, and we've added time for AUV type work.
- `trim_` For downcast VMP data, how to calculate the where good data starts. See [trim_profiles](../Code/trim_profiles.m)
  * `trim_calculate` Should the trim level for a down casting instrument be calculated?
  * `trim_dz` Depth bin size for cacluating variances over.
  * `trim_min_depth` Minimum depth to start calculating variances.
  * `trim_max_depth` Maximum depth to calculate variances to.
  * `trim_quantile` How many of the variance estimates have to be satisfied.
- `bottom_` For bottom crashing VMP data, how the bottom depth is calculated, i.e. where the good data ends. (Not currently implemented.) See [bottom_crash_profile](../Code/bottom_crash_profile.m)
  * `bottom_calculate` Should the bottom trim level for a down casting instrument be calculated?
  * `bottom_depth_window` Depth bin size for cacluating variances over.
  * `bottom_depth_minimum` Minimum depth to start calculating variances.
  * `bottom_depth_maximum` Maximum depth to calculate variances to.
  * `bottom_median_factor` Multiply median acceleration standard deviation to find acceptable in range value
  * `bottom_speed_factor` Speed must reduce by this amount below maximum deacceleration to be considered bottom
  * `bottom_vibration_frequency` Divide fs_fast by this value to get number of bins for AxAy moving standard deviation
  * `bottom_vibration_factor` Multiply vibration standarad deviation to get threshold
- `fp07_` How the FP07 sensors are adjusted in time and the in-situ calibration is done. See [fp07_calibration](../Code/fp07_calibration.m)
  * `fp07_calibration` Should an in-situ calibration of the FP07 sensors be done, if a CT_T_name value is set?
  * `fp07_order` Polynomial order for calibration.
  * `fp07_maximum_lag_seconds` Maximum lag to search within for the lag between FP07 sensors and the reference temperature.
  * `fp07_must_be_negative` For VMPs with a JAC sensor, the JAC sensor will be behind the FP07 sensors in time due to geometry and flow.
  * `fp07_wrn_range` Should a warning be generated if the temperature range is too small for the order supplied.
- `CT_` What is the name of the refereence temperature and conductivity. For VMPs, this is commonly JAC_T and JAC_C.
  * `CT_T_name` Name of the temperature reference. For VMPs this is typically JAC_T, but for MRs it is the name from a hotel file plus _slow.
  * `CT_C_name` Name of the conductivity references.
- `despike_` Despiking parameters used in dissipation estimates. See ***ODAS's despike*** for an explanation of the parameters. See [calc_diss_shear](../Code/calc_diss_shear.m). 
  * `despike_sh_thres` Shear sensors' threshold parameter.
  * `despike_sh_smooth` Shear sensors' smoothing parameter.
  * `despike_sh_N_FS` Shear sensors' spike removal scale in fs units. 
  * `despike_A_thres` Vibration/accelerometer sensors' threshold parameter.
  * `despike_A_smooth` Vibration/accelerometer sensors' smoothing parameter.
  * `despike_A_N_FS` Vibration/accelerometer sensors' spike removal scale in fs units.
- `diss_` Dissipation estimation parameters. See ***get_diss_odas*** for some explanation. See [profile2diss](../Code/profile2diss.m)
  * `diss_trim_top` Should the shallowest depths be trimmed by trim_depth prior to calculating the dissipation?
  * `diss_trim_top_offset` Amount to add to trim_depth for dissipation estimate triming.
  * `diss_trim_bottom` Should the deepest depths be trimmed by bbl_depth prior to calculating the dissipation?
  * `diss_trim_bottom_offset` Amount to add to bottom crsh depth for dissipation estimate triming.
  * `diss_reverse` Should the dissipations estimates be calculated from latest to earliest? For a downcast VMP, this is from the bottom up.
  * `diss_fft_length_sec` FFT window size in seconds.
  * `diss_length_fac` Multiply `diss_fft_length_sec` by this parameter to the the dissipation length in seconds.
  * `diss_speed_source` Data source for estimating the axial speed.
  * `diss_T_source` Temperature source, if missing then use T1*`diss_T1_norm` + T2*`diss_T2_norm`.
  * `diss_T1_norm`
  * `diss_T2_norm`
  * `diss_warning_fraction` What fraction of epsilon pairs outside the 95% confidence interval should a warning be generated.
  * `diss_epsilon_minimum` If epsilon values are less than this, set them to ***NaN*** This is useful when there is bad electronics in a channel.
- `bin_` How profile bins are constructed. See [profile2binned](../Code/profile2binned.m)
  * `bin_method` How should profile bins be aggregated, mean or median?
  * `bin_width` Binning width in meters for down or up profiling direction or seconds for time.
- `binDiss_` How dissipation bins are constructed. See [diss2binned](../Code/diss2binned.m)
  * `binDiss_method` How should dissipation bins be aggregated, mean or median?
  * `binDiss_width` Binning width in meters for down or up profiling direction or seconds for time.
- `ctd_` How to calculate CTD bins See [ctd2binned](../Code/ctd2binned.m)
  * `ctd_bin_dt` Bin width for scalar variable time binning in seconds.
  * `ctd_bin_variables` Scalar variables to bin, if they exist.
  * `ctd_method` How should scalar bins be aggregated, mean or median?
- `netCDF_` NetCDF global metadata parameters
  * `netCDF_acknowledgement`
  * `netCDF_contributor_name`
  * `netCDF_contributor_role`
  * `netCDF_creator_email`
  * `netCDF_creator_institution`
  * `netCDF_creator_name`
  * `netCDF_creator_type`
  * `netCDF_creator_url`
  * `netCDF_id`
  * `netCDF_institution`
  * `netCDF_instrument_vocabulary`
  * `netCDF_license`
  * `netCDF_metadata_link`
  * `netCDF_platform`
  * `netCDF_platform_vocabulary`
  * `netCDF_product_version`
  * `netCDF_program`
  * `netCDF_project`
  * `netCDF_publisher_email`
  * `netCDF_publisher_institution`
  * `netCDF_publisher_name`
  * `netCDF_publisher_type`
  * `netCDF_publisher_url`
  * `netCDF_title`
