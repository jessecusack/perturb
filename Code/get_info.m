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
validPositive = @(x) inRange(x, 0);
validNotNegative = @(x) inRange(x, 0, inf, true);

%% Debugging related parameters
addParameter(p, "debug", false, @(x) ismember(x, [true, false])); % Turn on debugging messages
%% Matlab binary file version to save files as
% Tables require v6 or greater
addParameter(p, "matlab_file_format", "-v7.3", @(x) ismember(x, ["-v7.3", "-v7", "-v6"])); 
%% Path related parameters
addParameter(p, "p_file_root", string(fullfile(fileparts(mfilename("fullpath")), "../Data/VMP")), @(x) isfolder(x));
addParameter(p, "output_root", string(fullfile(fileparts(mfilename("fullpath")), "../Data/Output")), validString);
%% Glob pattern appended to p_file_root to get list of P files
addParameter(p, "p_file_pattern", "*", validString);
%% Should p files be merged if they were broken up due to size of file breaks?
addParameter(p, "p_file_merge", false, @(x) ismember(x, [true, false]));
%% GPS related parameters
addParameter(p, "gps_class", GPS_NaN(), @(x) isa(x, "GPS_base_class")); % Class to get GPS information from
addParameter(p, "gps_max_time_diff", 60, validPositive); % maximum time difference for warning
%% Profile split parameters
addParameter(p, "profile_pressure_min", 0.5, validPositive); % Minimum pressure in dbar for a profile
addParameter(p, "profile_speed_min", 0.3, validPositive); % Minimum vertical speed in m/s for a profile
addParameter(p, "profile_min_duration", 7, validPositive); % Minimum cast length in seconds for a profile
addParameter(p, "profile_direction", "down", @(x) ismember(x, ["up", "down"])); % profile direction, up or down
%% Cast trimming for shear dissipation estimates to drop initial instabilities
addParameter(p, "trim_dz", 0.5, validPositive); % depth bin size for calculating variances (0.5 gives enough samples on the slow side at 1m/s and )
addParameter(p, "trim_min_depth", 1, validPositive); % Minimum depth to look at for variances
addParameter(p, "trim_max_depth", 50, validPositive); % maximum depth to look down to for variances
addParameter(p, "trim_quantile", 0.6, @(x) inRange(x, 0, 1, true, true)); % Which quantile to choose as the minimum depth
addParameter(p, "trim_use", true, @(x) ismember(x, [true, false])); % Should the trim depth be used to trim the top of dives off
addParameter(p, "trim_extra_depth", 0, validNotNegative); % Extra depth to add to the trim depth value when processing dissipation
%% Cast trimming from the bottom up, think bottom crashing to go after BBL
addParameter(p, "bbl_calculate", false, @(x) ismember(x, [true, false])); % Calculate BBL stuff
addParameter(p, "bbl_dz", 0.5, validPositive); % depth bin size for calculating variances (0.5 gives enough samples on the slow side at 1m/s and )
addParameter(p, "bbl_min_depth", 10, validPositive); % Minimum depth to look at for variances
addParameter(p, "bbl_max_depth", 50, validPositive); % Maximum depth to look down to for variances
addParameter(p, "bbl_quantile", 0.6, @(x) inRange(x, 0, 1, true, true)); % Which quantile to choose as the minimum depth
addParameter(p, "bbl_use", false, @(x) ismember(x, [true, false])); % Should the bbl depth be used to trim the top of dives off
addParameter(p, "bbl_extra_depth", 0, validNotNegative); % Extra depth to add to the bottom depth value when processing dissipation
%% FP07 calibration
addParameter(p, "fp07_calibration", true, @(x) ismember(x, [true, false])); % Perform an in-situ calibration of the FP07 probes agains JAC_T
addParameter(p, "fp07_order", 2, @(x) inRange(x, 1, 3)); % Steinhart-Hart equation order
addParameter(p, "fp07_reference", "JAC_T", validString); % Which sensor is the reference sensor
%% Does the instrument of CT information?
addParameter(p, "CT_has", true, @(x) ismember(x, [true, false]));
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
addParameter(p, "diss_downwards_fft_length_sec", 0.5, validPositive); % Disspation FFT length in seconds for top -> bottom estimates
addParameter(p, "diss_upwards_fft_length_sec", 0.25, validPositive); % Disspation FFT length in seconds for bottom -> top estimates
addParameter(p, "diss_downwards_length_fac", 2, validPositive); % Multiples fft_length_sec to get dissipation length for top -> bottom estimates
addParameter(p, "diss_upwards_length_fac", 2, validPositive); % Multiples fft_length_sec to get dissipation length for bottom -> top estimates
addParameter(p, "diss_T1_norm", 1, validPositive); % Value to multiple T1_fast temperature probe by to calculate mean for dissipation estimate
addParameter(p, "diss_T2_norm", 1, validPositive); % Value to multiple T2_fast temperature probe by to calculate mean for dissipation estimate
addParameter(p, "diss_warning_fraction", 0.1); % When to warn about difference of e probes > diss_warning_ratio
addParameter(p, "diss_epsilon_minimum", 3e-10, validPositive); % Dissipation estimates less than this are set to nan, for bad electronics
%% Binning parameters
addParameter(p, "bin_method", "median", @(x) ismember(x, ["median", "mean"])); % Which method to use to combine bins together
addParameter(p, "bin_width", 1, validPositive); % Bin width in (m)
%% CTD time binning parameters
addParameter(p, "ctd_bin_dt", 0.5, validPositive); % Width in seconds of CTD binning
addParameter(p, "ctd_bin_variables", ["JAC_T", "JAC_C", "Chlorophyll", "DO", "DO_T"], validString); % Sensors to time bin
%% NetCDF global attributes
addParameter(p, "netCDF_acknowledgement", missing, validString);
addParameter(p, "netCDF_contributor_name", missing, validString);
addParameter(p, "netCDF_contributor_role", missing, validString);
addParameter(p, "netCDF_creator_email", missing, validString);
addParameter(p, "netCDF_creator_institution", missing, validString);
addParameter(p, "netCDF_creator_name", missing, validString);
addParameter(p, "netCDF_creator_type", missing, validString);
addParameter(p, "netCDF_creator_url", missing, validString);
addParameter(p, "netCDF_id", missing, validString);
addParameter(p, "netCDF_institution", missing, validString);
addParameter(p, "netCDF_instrument_vocabulary", missing, validString);
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
addParameter(p, "netCDF_title", missing, validString);
%%
parse(p, varargin{:});
a = p.Results(1);

a.p_file_root = abspath(a.p_file_root);
if ~isfolder(a.p_file_root)
    error("p_file_root is not a folder, %s", a.p_file_root);
end % if

names = string(p.Parameters);

% Convert numbers from strings to double
for name = names(~ismember(names, p.UsingDefaults)) % Only work with non-default values
    x = str2double(a.(name));
    if ~isnan(x)
        a.(name) = x;
    end % if ~isnan
end % for name
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
