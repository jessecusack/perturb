%
% Process CASPER MR data
%
% Dec-2023, Pat Welch, pat@mousebrains.com

project = "CASPER";
% subproj = "2015_East";
subproj = "2017_West";

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");

parent_root = fullfile(my_root, sprintf("../../%s/%s", project, subproj));
data_root = fullfile(parent_root, "Data");
hotel_file = fullfile(data_root, "hotel.mat");
gps_file = fullfile(data_root, "gps.mat");
p_file_root = fullfile(data_root, "MR_Doug");
output_root = fullfile(parent_root, "Processed");

origPath = addpath(code_root, "-begin"); % Before reference to GPS_from_netCDF

try
    GPS_class = GPS_from_mat(gps_file, missing);

    profileDirections = ["up", "down"];
    pars = cell(size(profileDirections));

    for index = 1:numel(profileDirections)
        profileDirection = profileDirections(index);

        pars{index} = process_P_files( ...
            "debug", true, ...
            "p_file_root", p_file_root, ... % Where the input .P files are located
            "p_file_pattern", "*", ...   % Glob pattern appended to p_file_root to locate P files
            "output_root", output_root, ...  % Where to write output to
            "gps_class", GPS_class, ... % Class to supply GPS data
            "diss_fft_length_sec", 0.5, ... % 1 second FFTs
            "diss_length_fac", 6, ... % fft_length_sec * length_fac is length in seconds of each dissipation estimate
            "diss_epsilon_minimum", 1e-14, ...   % Drop dissipation estimates smaller than this value
            "profile_direction", profileDirection, ... % glider profiling up and down
            "p2mat_hotel_file", hotel_file, ... % CTD information
            "p2mat_speed_cutout", 0.01, ... % Don't floor the speed at 0.05, the default
            "CT_T_name", "CTD_temp_slow", ...
            "CT_C_name", "CTD_cond_slow", ...
            "diss_T_source", "CTD_temp_slow", ...
            "profile_speed_min", 0.05, ...
            "profile_pressure_min", 0.01, ...
            "fp07_calibration", true, ... % Don't calibrate the FP07 sensors
            "fp07_order", 2, ... % We don't have any temperature range, so linear only
            "fp07_maximum_lag_seconds", 180, ... % CTD to MR time skew
            "fp07_must_be_negative", false, ... % From CTD can be in either direction
            "fp07_warn_range", false, ... % Our temperature range is very small, but I want to do quadratic
            "bin_width", 1, ... % bin width for profile scalar data
            "binDiss_width", 1, ... % bin width for dissipation data
            "ctd_bin_enable", false, ... % Don't time bin all the scalar data
            "trim_calculate", false, ... % No need to trim
            "netCDF_contributor_name", "Pat Welch", ...
            "netCDF_contributor_role", "researcher", ...
            "netCDF_creator_name", "Pat Welch", ...
            "netCDF_creator_email", "pat@mousebrains.com", ...
            "netCDF_creator_institution", "CEOAS, Oregon State University", ...
            "netCDF_creator_type", "researcher", ...
            "netCDF_creator_url", "https://arcterx.ceoas.oregonstat.edu", ...
            "netCDF_id", append(project, " ", subproj), ...
            "netCDF_institution", "CEOAS, Oregon State University", ...
            "netCDF_platform", "Rockland MR1000", ...
            "netCDF_product_version", "0.1", ...
            "netCDF_program", sprintf("%s %s", project, subproj), ...
            "netCDF_project", sprintf("%s %s", project, subproj) ...
            );
    end % for profileDirection

    glue_combo(pars, fullfile(pars{1}.output_root, "glued")); % Glue together the dissipations for up and down
catch ME
    disp(getReport(ME));
end % try

path(origPath); % Restore the original path
