%
% Convert test .P files to binned data
%
% August-2023, Pat Welch, pat@mousebrains.com

glider = "685";

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");
data_root = append("~/Desktop/ARCTERX/2023 IOP/glider-offload/OSU", glider, "/MR");

p_file_root = data_root;
output_root = append("~/Desktop/ARCTERX/2023 IOP/tpw_MR/", glider);

addpath(code_root, "-begin"); % Before reference to GPS_from_mat
% 
% GPS_filename = fullfile(data_root, "GPS/gps.mat");
% GPS_class = GPS_from_mat(GPS_filename);
GPS_class = GPS_NaN();

process_P_files( ...
    "debug", true, ...
    "p_file_root", p_file_root, ... % Where the input .P files are located
    "output_root", output_root, ... % Where to write output to
    "gps_class", GPS_class, ... % Class to supply GPS data
    "p_file_merge", false, ... % Don't attempt to merge p files for MR
    "profile_direction", "up", ... % Profiles going from bottom to top
    "profile_speed_min", 0.1, ... % Vertical speed cutoff
    "fp07_calibration", false, ... % Don't calibrate FP07s
    "CT_has", false, ... % Doesn't have CT information
    "diss_forwards_fft_length_sec", 1, ... % 1 second FFT lengths (This is really forward in time)
    "diss_forwards_length_fac", 10, ... % 10 overlaps, so at 0.1m/s -> 1 m
    "diss_epsilon_minimum", 1e-13, ...   % Drop dissipation estimates smaller than this value
    "trim_use", false, ... % Don't trim at the top
    "netCDF_contributor_name", "Pat Welch", ...
    "netCDF_contributor_role", "researcher", ...
    "netCDF_creator_name", "Pat Welch", ...
    "netCDF_creator_email", "pat@mousebrains.com", ...
    "netCDF_creator_institution", "CEOAS, Oregon State University", ...
    "netCDF_creator_type", "researcher", ...
    "netCDF_creator_url", "https://arcterx.ceoas.oregonstat.edu", ...
    "netCDF_id", "ARCTERX 2023", ...
    "netCDF_institution", "CEOAS, Oregon State University", ...
    "netCDF_platform", "Rockland MR1000 on Slocum G3", ...
    "netCDF_product_version", "0.1", ...
    "netCDF_program", "ARCTERX 2023", ...
    "netCDF_project", "ARCTERX 2023" ...
	);

rmpath(code_root);
