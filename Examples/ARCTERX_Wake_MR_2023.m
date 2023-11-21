%
% Convert ARCTERX Wake MR .P files to binned data
%
% Nov-2023, Pat Welch, pat@mousebrains.com

% SN = 330;
SN = 429;

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");
data_root = "~/Desktop/Wake2023/Data";
bank_root = fullfile(data_root, "Bank Seaspider");
hotel_file = fullfile(bank_root, "hotel.mat");
MR_dir = sprintf("MR%d", SN);
p_file_root = fullfile(bank_root, MR_dir);
output_root = fullfile(data_root, "Temp_SeaSpider", MR_dir);

addpath(code_root, "-begin"); % Before reference to GPS_from_netCDF

GPS_class = GPS_from_vectors(datetime(["2023-04-01", "2023-06-01"]), 6.930167 + [0, 0], 134.199417 + [0,0]);

% "p2mat_speed_cutout", 0.01, ... % Don't floor the speed at 0.05, the default

pars = process_P_files( ...
    "debug", true, ...
    "p_file_root", p_file_root, ... % Where the input .P files are located
    "p_file_pattern", "*", ...   % Glob pattern appended to p_file_root to locate P files
    "output_root", output_root, ...  % Where to write output to
    "gps_class", GPS_class, ... % Class to supply GPS data
    "diss_fft_length_sec", 2, ... % 1 second FFTs
    "diss_length_fac", 8, ... % 8 second dissipation estimates
    "diss_epsilon_minimum", 1e-14, ...   % Drop dissipation estimates smaller than this value
    "diss_T_source", "CTD_temp_slow", ... % Temperature source from CTD
    "profile_direction", "time", ... % Not profiling, bin by time
    "p2mat_hotel_file", hotel_file, ... % CTD informationa.
    "p2mat_vehicle", "AUV_EMC", ... % Use EM sensor
    "CT_T_name", "CTD_temp_slow", ... % No CT information
    "CT_C_name", "CTD_cond_slow", ... % No CT information
    "fp07_calibration", true, ... % Don't calibrate the FP07 sensors
    "fp07_order", 2, ... % We don't have any temperature range, so linear only
    "fp07_maximum_lag_seconds", 180, ... % CTD to MR time skew
    "fp07_must_be_negative", false, ... % From CTD can be in either direction
    "fp07_warn_range", false, ... % Our temperature range is very small, but I want to do quadratic
    "bin_width", 1, ... % bin width for profile scalar data
    "binDiss_width", 60, ... % bin width for dissipation data
    "trim_calculate", false, ... % No need to trim
    "netCDF_contributor_name", "Pat Welch", ...
    "netCDF_contributor_role", "researcher", ...
    "netCDF_creator_name", "Pat Welch", ...
    "netCDF_creator_email", "pat@mousebrains.com", ...
    "netCDF_creator_institution", "CEOAS, Oregon State University", ...
    "netCDF_creator_type", "researcher", ...
    "netCDF_creator_url", "https://arcterx.ceoas.oregonstat.edu", ...
    "netCDF_id", "Wake ARCTERX 2023", ...
    "netCDF_institution", "CEOAS, Oregon State University", ...
    "netCDF_platform", "Rockland MR1000", ...
    "netCDF_product_version", "0.1", ...
    "netCDF_program", "Wake ARCTERX 2023", ...
    "netCDF_project", "Wake ARCTERX 2023" ...
    );

rmpath(code_root);
