# Description of input parameters to [process_p_files](../Code/process_p_files.m)`

For examples of calling [process_P_files](../Code/process_P_files.m), please see [Examples](../Examples).

To see all the current parameters, please execute `process_P_files` for the names and defaults.

The parameter functionality is grouped by the parameter prefix:
- `p_file_` control where the P files are located, and how they are selected.
- `gps_` control how GPS locations are selected.
- `p2mat_` control the conversion from `.P` files to `.mat` files via ***odas_p2mat***.
- `profile_` control how profiles are extracted from the data.
- `trim_` For downcast VMP data, how to calculate the where good data starts.
- `bbl_` For bottom crashing VMP data, how the bottom depth is calculated, i.e. where the good data ends. (Not currently implemented.)
- `fp07_` How the FP07 sensors are adjusted in time and the in-situ calibration is done.
- `CT_` What is the name of the refereence temperature and conductivity. For VMPs, this is commonly JAC_T and JAC_C.
- `despike_` Despiking parameters used in dissipation estimates.
- `diss_` Dissipation estimation parameters.
- `bin_` How profile bins are constructed.
- `binDiss_` How dissipation bins are constructed.
- `ctd_` How to calculate CTD bins
- `netCDF_` NetCDF global metadata parameters

- `p_file_` control where the P files are located, and how they are selected.
  * `p_file_root` is the parent directory that `p_file_pattern` is append to to locate the `.P` files.
  * `p_file_pattern` is a glob pattern appended to `p_file_root` to locate the `.P` files. If one stores their P files in directories like SN555 and SN1038, representing the instrument's serial number, the `p_file_pattern` would be ***SN*/**** **Please note, you don't need a `.P` suffix on your pattern, that is handled by [find_P_filenames](../Code/find_P_filenames.m).
- `gps_` control how GPS locations are selected.
  * `gps_class` is a class handle derived from [GPS_base_class.m](../Code/GPS_base_class.m). Please see [Examples](../Examples) for how to set `gps_class`.
  * `gps_max_time_diff` controls if a warning is generated for a GPS fix which is a long time from the current time.
- `p2mat_` control the conversion from `.P` files to `.mat` files via ***odas_p2mat***. Please see ***odas*** documentation for the following parameters.
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
- `profile_` control how profiles are extracted from the data.
- `trim_` For downcast VMP data, how to calculate the where good data starts.
- `bbl_` For bottom crashing VMP data, how the bottom depth is calculated, i.e. where the good data ends. (Not currently implemented.)
- `fp07_` How the FP07 sensors are adjusted in time and the in-situ calibration is done.
- `CT_` What is the name of the refereence temperature and conductivity. For VMPs, this is commonly JAC_T and JAC_C.
- `despike_` Despiking parameters used in dissipation estimates.
- `diss_` Dissipation estimation parameters.
- `bin_` How profile bins are constructed.
- `binDiss_` How dissipation bins are constructed.
- `ctd_` How to calculate CTD bins
- `netCDF_` NetCDF global metadata parameters

- 
- *P file* related parameters
- `p_file_pattern` A glob pattern defining how to find `.P` files relative to `p_file_root`

- *GPS* related parameters
  - `gpsClass` This is a class object for obtaining a GPS fix at a specified time. `(default: @GPSInfo)`
  - 1gpsFilename` This is a filename input to the `gpsClass` object, relative to `dataRoot`. `(default: GPS/gps.nc)`
  - `gpsMethod` The interpolation method to obtain a GPS fix for an unknown timestamp. Options include:
    - linear
    - nearest
    - next
    - previous
    - pchip
    - cubic
    - v5cubic
    - makima
    - spline
  - `gpsMaxTimeDiff` a warning is issued if the actual GPS fix is further than this time from the target time. The units here are seconds. `(default: 60)`
- profile related parameters
  - `profiel_pressureMin` This is the minimum pressure for a cast. The units are decibars. `(default: 0.5)`
  - `profile_speedMin` The minimum vertical speed to be in a cast. The units are m/s. `(default: 0.3)`
  - `profile_minDuration` The minimum duration of a cast in seconds. `(default: 7)`
  - `profile_direction` The cast direction, up or down. `(default: down)` ***The code has only been tested with down!!!***
- Top [trimming](Trim.md) parameters
  - `trim_use` Should top trimming be done? (true or false) `(default: true)`
  - `trim_quantile` is the quantile of the various variance metrics to use. `(default: 0.6)`
  - `trim_dz` Triming bin width in decibars for calculating variances. `(default: 0.5)`
  - `trim_minDepth` The depth to start looking at for triming. `(default: 1)`
  - `trim_maxDepth` The depth to stop looking at for triming. `(default: 50)`
  - `trim_extraDepth` Additional depth added to the automatic trim depth. This is in decibars and can be positive or negative. `(default: 0)`
- [Bottom boundary layer trimming](BBL.md) parameters ***Bottom crash detection not implemented***
  - `bbl_use` Should bottom trimming be done? (true or false) `(default: false)`
  - `bbl_quantile` is the quantile of the various variance metrics to use. `(default: 0.6)`
  - `bbl_dz` BBL triming bin width in decibars for calculating variances. `(default: 0.5)`
  - `bbl_minDepth` The depth to start looking at for BBL triming. `(default: 10)`
  - `bbl_maxDepth` The depth to stop looking at for BBL triming. `(default: 50)`
  - `bbl_extraDepth` Additional depth added to the automatic BBL trim depth. This is in decibars and can be positive or negative. `(default: 0)`
- [FP07 calibration and shift](FP07.md) parameters
  - `fp07_calibration` Should FP07 calibration be done? (true or false) `(default: true)`
  - `fp07_order` Order of polynomial fit to use. `(default: 2)`
  - `fp07_reference` Reference slow variable to use for calibrating the FP07s. `(default: JAC_T)`
- [Despiking](Despiking.md) parameters
  - `despike_sh_thres` Shear probe threshold `(default: 8)`
  - `despike_sh_smooth` Shear probe smoothing `(default: 0.5)`
  - `despike_sh_N_FS` Shear probe N_FS `(default: 0.05)`
  - `despike_sh_warning_fraction` Shear probe fraction above which to issue a warning. `(default: 0.03)`
  - `despike_A_thres` Accelerometer probe threshold `(default: 8)`
  - `despike_A_smooth` Accelerometer probe smoothing `(default: 0.5)`
  - `despike_A_N_FS` Accelerometer probe N_FS `(default: 0.05)`
  - `despike_A_warning_fraction` Shear probe fraction above which to issue a warning. `(default: 0.03)`
- [Dissipation](Dissipation.md) parameters
 - `diss_T1Norm` Positive value to normalize T1_fast by to calclate T_fast. `(default: 1)`
 - `diss_T2Norm` Positive value to normalize T2_fast by to calclate T_fast. `(default: 1)`
 - `diss_warning_ratio` If the ratio of the e samples are further than this apart, tag as big. `(default: 5)`
 - `diss_warning_fraction` Isssue a warning if more than this fraction are *big*. `(default: 0.15)`
 - Downward calculation
   - `diss_downwards_fft_length_sec` Seconds for the FFT length. `(default: 0.5)`
   - `diss_downwards_length_fac` Number of FFTs to combine. `(default: 2)`
 - Upward calculation
   - `diss_upwards_fft_length_sec` Seconds for the FFT length. `(default: 0.5)`
   - `diss_upwards_length_fac` Number of FFTs to combine. `(default: 2)`
- [Binning](Binning.md) parameters
 - `bin_method` How should bins values be calculated? (median or mean) `(default: median)`
 - `bin_width` With of a bin in decibars. Bins are centered on multiples of the width. `(default: 1)`
 - `bin_dissFloor` Values less than this value are set to NaN. `(default: 1e-11)`
 - `bin_dissRatio` If the ratio of e values is greater than this, then the minimum is taken. `(default: 5)`
