%
% Parse arguments and build structure for
% P files -> mat files
% mat files -> profiles
% profiles -> binned data
%
% July-2023, Pat Welch, pat@mousebrains.com
%
%%
function a = get_info(varargin)

p = inputParser();
validString = @(x) isstring(x) || ischar(x) || iscellstr(x);
validMissingString = @(x) validString(x) || ismissing(x);
validPositive = @(x) inRange(x, 0);
validNotNegative = @(x) inRange(x, 0, inf, true);
validLogical = @(x) ismember(x, [true, false]);
validMethod = @(x) ismember(x, ["median", "mean"]);

%% Debugging related parameters
addParameter(p, "debug", false, validLogical); % Turn on debugging messages
%% Matlab binary file version to save files as
% Tables require v6 or greater
addParameter(p, "matlab_file_format", "-v7.3", @(x) ismember(x, ["-v7.3", "-v7", "-v6"])); 
%% Path related parameters
addParameter(p, "p_file_root", string(fullfile(fileparts(mfilename("fullpath")), "../Data/VMP")), @(x) isfolder(x));
addParameter(p, "output_root", string(fullfile(fileparts(mfilename("fullpath")), "../Data/Output")), validString);
%% Glob pattern appended to p_file_root to get list of P files
addParameter(p, "p_file_pattern", "*", validString);
%% Should p files be trimmed that have non-integral number of records.
% patch_odas.m does this, but generates a warning that makes it look like the processing has
% big problems. So I'll pre-trim things before the call to odas_p2mat
addParameter(p, "p_file_trim", true, validLogical);
%% Should p files be merged if they were broken up due to size of file breaks?
addParameter(p, "p_file_merge", false, validLogical);
%% GPS related parameters
addParameter(p, "gps_class", GPS_NaN(), @(x) isa(x, "GPS_base_class")); % Class to get GPS information from
addParameter(p, "gps_max_time_diff", 60, validPositive); % maximum time difference for warning
%% Parameters for odas_p2mat
addParameter(p, "p2mat_aoa", [], @(x) isnumeric(x)); % Angle-of-attack
addParameter(p, "p2mat_constant_speed", [], validNotNegative); % Through water speed
addParameter(p, "p2mat_constant_temp", [], @(x) inRange(x, -4, 80)); % water temperature in C
addParameter(p, "p2mat_gradC_method", missing, validString); % micro conductivity gradient method
addParameter(p, "p2mat_gradT_method", missing, validString); % micro conductivity gradient method
addParameter(p, "p2mat_hotel_file", missing, @(x) isfile(x)); % micro conductivity gradient method
addParameter(p, "p2mat_speed_cutout", nan, validPositive); % Ignore speeds below this value
addParameter(p, "p2mat_speed_tau", nan, validNotNegative); % For smoothing of the speed
addParameter(p, "p2mat_time_offset", nan, @(x) isnumeric(x)); % offset to apply to time in seconds
addParameter(p, "p2mat_vehicle", missing, validString); % name of the vehicle
%% Profile split parameters
addParameter(p, "profile_pressure_min", 0.5, validPositive); % Minimum pressure in dbar for a profile
addParameter(p, "profile_speed_min", 0.3, validPositive); % Minimum vertical speed in m/s for a profile
addParameter(p, "profile_min_duration", 7, validPositive); % Minimum cast length in seconds for a profile
addParameter(p, "profile_direction", "down", @(x) ismember(x, ["up", "down", "time"])); % profile direction, up, down, or time
%% Cast trimming for shear dissipation estimates to drop initial instabilities
addParameter(p, "trim_calculate", true, validLogical); % Calculate top trimming stuff
addParameter(p, "trim_dz", 0.5, validPositive); % depth bin size for calculating variances (0.5 gives enough samples on the slow side at 1m/s and )
addParameter(p, "trim_min_depth", 1, validPositive); % Minimum depth to look at for variances
addParameter(p, "trim_max_depth", 50, validPositive); % maximum depth to look down to for variances
addParameter(p, "trim_quantile", 0.6, @(x) inRange(x, 0, 1, true, true)); % Which quantile to choose as the minimum depth
%% Cast trimming from the bottom up, think bottom crashing to go after BBL
addParameter(p, "bottom_calculate", false, validLogical); % Calculate bottom trimming stuff
addParameter(p, "bottom_depth_window", 4, validPositive); % Meters above maximum deacceleration to look in
addParameter(p, "bottom_depth_minimum", 10, validPositive); % Minimum depth to look at for variances
addParameter(p, "bottom_depth_maximum", 50, validPositive); % Maximum depth to look down to for variances
addParameter(p, "bottom_median_factor", 1, validPositive); % Acceleration standard deviation filter factor
addParameter(p, "bottom_speed_factor", 0.3, validPositive); % Required fractional dP/dt reduction
addParameter(p, "bottom_vibration_frequency", 16, validPositive); % To get number of bins to calculated standard deviation over
addParameter(p, "bottom_vibration_factor", 4, validPositive); % Number of vibration standard deviations to accept
%% FP07 calibration
addParameter(p, "fp07_calibration", true, validLogical); % Perform an in-situ calibration of the FP07 probes agains CT_T_name
addParameter(p, "fp07_order", 2, @(x) inRange(x, 1, 3, true, true)); % Steinhart-Hart equation order
addParameter(p, "fp07_maximum_lag_seconds", 10, @(x) inRange(x, 0, 3600)); % Lag range in seconds
addParameter(p, "fp07_must_be_negative", true, validLogical); % For falling VMPs, the lag should be negative
addParameter(p, "fp07_warn_range", true, validLogical); % Warn if the temperature range is too small and order high
%% CT sensor names, default to JAC_T and JAC_C
addParameter(p, "CT_T_name", "JAC_T", validMissingString); % What is the slow T sensor name. If none, set to missing
addParameter(p, "CT_C_name", "JAC_C", validMissingString); % What is the slow C sensor name. If none, set to missing
%% Despike parameters for shear dissipation calculation
% [thresh, smooth, and length] (in seconds) -> Rockland default value,
addParameter(p, "despike_sh_thresh", 8, validPositive); % Shear probe
addParameter(p, "despike_sh_smooth", 0.5, validPositive);
addParameter(p, "despike_sh_N_FS", 0.05, validPositive);
addParameter(p, "despike_sh_warning_fraction", 0.03, validPositive); % Warning fraction
addParameter(p, "despike_A_thresh", 8, validPositive); % Acceleration
addParameter(p, "despike_A_smooth", 0.5, validPositive);
addParameter(p, "despike_A_N_FS", 0.05, validPositive);
addParameter(p, "despike_A_warning_fraction", 0.02, validPositive); % Warning fraction
%% Dissipation parameters
addParameter(p, "diss_trim_top", false, validLogical); % Trim the top of profiles
addParameter(p, "diss_trim_bottom", false, validLogical); % Trim the bottom of profiles
addParameter(p, "diss_trim_top_offset", 0, @isreal); % Meters added to top trim before dissipation calc
addParameter(p, "diss_trim_bottom_offset", 0, @isreal); % Meters added to bottom trim before dissipation calc
addParameter(p, "diss_reverse", false, validLogical); % Calculate dissipation backwards in time, for BBL on downcast
addParameter(p, "diss_fft_length_sec", 0.5, validPositive); % Disspation FFT length in seconds
addParameter(p, "diss_length_fac", 2, @(x) x>=2); % Multiples fft_length_sec to get dissipation length
addParameter(p, "diss_overlap_factor", 2, @(x) x>=0 && x<=1); % Distance of the overlap of successive dissipation estimates, 0-> none
addParameter(p, "diss_fit_order", nan, validPositive); % Polynomial order of fit to shear spectra, in log-space
addParameter(p, "diss_f_AA", nan, validPositive); % Cut-off frequency of the anti-aliasing filter
addParameter(p, "diss_fit_2_isr", nan, validPositive); % Value of dissipation rate to switch from isr to integration
addParameter(p, "diss_f_limit", nan, validPositive); % Maximum frequency to use when estimating the rate of dissipation
addParameter(p, "diss_goodman", nan, validLogical); % Should Goodman coherent noise reduction be applied?
addParameter(p, "diss_speed_source", "speed_fast", validString); % Source of axial flow speed
addParameter(p, "diss_T_source", missing, validMissingString); % Temperature source for kinematic viscosity estimate
                                                               % If missing, then use T1*T1_norm+T2*T2_norm
addParameter(p, "diss_T1_norm", 1, validPositive); % Value to multiple T1_fast temperature probe by to calculate mean for dissipation estimate
addParameter(p, "diss_T2_norm", 1, validPositive); % Value to multiple T2_fast temperature probe by to calculate mean for dissipation estimate
addParameter(p, "diss_warning_fraction", 0.1); % When to warn about difference of e probes > diss_warning_ratio
addParameter(p, "diss_epsilon_minimum", 1e-13, validPositive); % Dissipation estimates less than this are set to nan, for bad electronics
%% Binning parameters for profiles, non-dissipation
addParameter(p, "bin_method", "mean", validMethod); % Which method to use to combine bins together
addParameter(p, "bin_width", 1, validPositive); % Bin width in (m)
addParameter(p, "bin_variable", "depth", validString); % Which variable to bin by, unless direction==time
%% Binning parameters for dissipation
addParameter(p, "binDiss_method", "mean", validMethod); % Which method to use to combine bins together
addParameter(p, "binDiss_width", 1, validPositive); % Bin width in (m)
addParameter(p, "binDiss_variable", "depth", validString); % Which variable to bin by, unless direction==time
%% CTD time binning parameters
addParameter(p, "ctd_bin_enable", true, validLogical); % Should CTD be binned outside of profiles?
addParameter(p, "ctd_bin_dt", 0.5, validPositive); % Width in seconds of CTD binning
addParameter(p, "ctd_bin_variables", ["JAC_T", "JAC_C", "Chlorophyll", "DO", "DO_T", "P_slow"], validString); % Sensors to time bin
addParameter(p, "ctd_method", "mean", validMethod); % How to average
%% NetCDF global attributes
addParameter(p, "netCDF_acknowledgement", missing, validString);
addParameter(p, "netCDF_comment", missing, validString);
addParameter(p, "netCDF_contributor_name", missing, validString);
addParameter(p, "netCDF_contributor_role", missing, validString);
addParameter(p, "netCDF_creator_email", missing, validString);
addParameter(p, "netCDF_creator_institution", missing, validString);
addParameter(p, "netCDF_creator_name", missing, validString);
addParameter(p, "netCDF_creator_type", missing, validString);
addParameter(p, "netCDF_creator_url", missing, validString);
addParameter(p, "netCDF_history", missing, validString);
addParameter(p, "netCDF_id", missing, validString);
addParameter(p, "netCDF_institution", missing, validString);
addParameter(p, "netCDF_instrument", missing, validString);
addParameter(p, "netCDF_instrument_vocabulary", missing, validString);
addParameter(p, "netCDF_keywords", missing, validString);
addParameter(p, "netCDF_keywords_vocabulary", missing, validString);
addParameter(p, "netCDF_license", missing, validString);
addParameter(p, "netCDF_metadata_link", missing, validString);
addParameter(p, "netCDF_platform", missing, validString);
addParameter(p, "netCDF_platform_vocabulary", missing, validString);
addParameter(p, "netCDF_product_version", missing, validString);
addParameter(p, "netCDF_program", missing, validString);
addParameter(p, "netCDF_project", missing, validString);
addParameter(p, "netCDF_publisher_email", missing, validString);
addParameter(p, "netCDF_publisher_institution", missing, validString);
addParameter(p, "netCDF_publisher_name", missing, validString);
addParameter(p, "netCDF_publisher_type", missing, validString);
addParameter(p, "netCDF_publisher_url", missing, validString);
addParameter(p, "netCDF_references", missing, validString);
addParameter(p, "netCDF_source", missing, validString);
addParameter(p, "netCDF_summary", missing, validString);
addParameter(p, "netCDF_title", missing, validString);
%%
parse(p, varargin{:});
a = p.Results(1);

a.p_file_root = abspath(a.p_file_root);
if ~isfolder(a.p_file_root)
    error("p_file_root is not a folder, %s", a.p_file_root);
end % if

% Convert numbers from strings to double for non-default values

for name = setdiff(string(p.Parameters), p.UsingDefaults) % Only work with non-default values
    x = str2double(a.(name));
    if ~isnan(x)
        a.(name) = x;
    end % if ~isnan
end % for name

if ismember("ctd_bin_enable", p.UsingDefaults) && isequal(a.profile_direction, "time")
    a.ctd_bin_enable = false;
end % if ~ismember
end % getInfo

%% Function to check if a value, string or numeric, is in a range, open/closed
function q = inRange(x, lhs, rhs, clhs, crhs)
arguments
    x % Input value to check
    lhs double = nan % minimum value
    rhs double = nan % maximum value
    clhs double = false % < or <=
    crhs double = false % > or >=
end; % arguments

q = false;

if isstring(x) || ischar(x)
    x = str2double(x);
    if isnan(x)
        return; % Not a numeric string
    end % if isnan
end % if

if ~isnan(lhs)
    if (lhs > x) || (~clhs && lhs >= x)
        return;
    end
end % isnan lhs

if ~isnan(rhs)
    if (rhs < x) || (~crhs && rhs <= x)
        return;
    end
end % isnan lhs
q = true;
end % inRange
