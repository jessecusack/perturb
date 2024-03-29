%
% Convert ARCTERX 2023 MR .P files to binned data
%
% August-2023, Pat Welch, pat@mousebrains.com

glider = "685";
year = "2023";
project = "ARCTERX";
subproj = "Interior";

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");

parent_root = fullfile(my_root, sprintf("../../ARCTERX/Interior%s", year));
data_root = fullfile(parent_root, "Data"); % Root of data

GPS_filename = fullfile(data_root, "glider", sprintf("OSU%s.gps.mat", glider));
hotel_file = fullfile(data_root, "glider", sprintf("OSU%s.hotel.mat", glider));

p_file_root = fullfile(data_root, sprintf("MR%s", glider)); % Where the p files are located
output_root = fullfile(parent_root, "Processed", sprintf("MR%s", glider)); % Where to place output files

origPath = addpath(code_root, "-begin"); % Before reference to GPS_from_mat

try
    GPS_class = GPS_from_mat(GPS_filename, missing);

    % "p_file_pattern", "*01*.p", ...
    % "diss_speed_source", "U_EM", ... % Axial flow speed source for dissipation estimates

    pars = process_P_files( ...
        "p2mat_hotel", hotel_file, ...
        "bin_width", 1, ...
        "debug", true, ...
        "p_file_root", p_file_root, ... % Where the input .P files are located
        "output_root", output_root, ... % Where to write output to
        "gps_class", GPS_class, ... % Class to supply GPS data
        "p_file_merge", true, ... % Attempt to merge p files for MR
        "profile_direction", "up", ... % Profiles going from bottom to top
        "profile_speed_min", 0.05, ... % Vertical speed cutoff
        "fp07_calibration", false, ... % Don't calibrate FP07s
        "CT_T_name", "ctd_temp_slow", ... % temperature information from glider's CTD via hotel file
        "CT_C_name", "ctd_cond_slow", ... % conductivity information from glider's CTD via hotel file
        "diss_T_source", "ctd_temp_slow", ... % Temperature for kinematic viscosity
        "diss_fft_length_sec", 0.5, ... % 1 second FFT lengths (This is really forward in time)
        "diss_length_fac", 5, ... % 10 overlaps, so at 0.1m/s -> 1 m
        "trim_calculate", false, ... % Don't trim at the top
        "netCDF_contributor_name", "Pat Welch", ...
        "netCDF_contributor_role", "researcher", ...
        "netCDF_creator_name", "Pat Welch", ...
        "netCDF_creator_email", "pat@mousebrains.com", ...
        "netCDF_creator_institution", "CEOAS, Oregon State University", ...
        "netCDF_creator_type", "researcher", ...
        "netCDF_creator_url", "https://arcterx.ceoas.oregonstat.edu", ...
        "netCDF_id", sprintf("%s %s %s MR%s", project, subproj, year, glider), ...
        "netCDF_institution", "CEOAS, Oregon State University", ...
        "netCDF_platform", "Rockland MR1000 on Slocum G3", ...
        "netCDF_product_version", "0.1", ...
        "netCDF_program", sprintf("%s %s %s MR%s", project, subproj, year, glider), ...
        "netCDF_project", sprintf("%s %s %s MR%s", project, subproj, year, glider) ...
    	);
catch ME
    disp(getReport(ME));
end % try

path(origPath);
