%
% Convert .P files to binned data
% For Rota 2022 data
%
% Aug-2023, Pat Welch, pat@mousebrains.com

year = "2022";
project = "ARCTERX";
subproj = "Wake";

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");

parent_root = fullfile(my_root, sprintf("../../%s/%s%s", project, subproj, year));
data_root = fullfile(parent_root, "Data");

p_file_root = fullfile(data_root, "VMP");
output_root = fullfile(parent_root, "Processed/VMP");

origPath = addpath(code_root, "-begin"); % Before reference to GPS_from_mat

try
    GPS_filename = fullfile(data_root, "GPS/tsg.mat");
    GPS_class = GPS_from_mat(GPS_filename, "M");

    pars = process_P_files( ...
        "debug", true, ...
        "gps_class", GPS_class, ... % Where to get GPS data from
        "p_file_root", p_file_root, ... % Where the input .P files are located
        "p_file_pattern", "*", ...   % Glob pattern appended to p_file_root to locate P files
        "output_root", output_root, ...  % Where to write output to
        "netCDF_contributor_name", "Pat Welch", ...
        "netCDF_contributor_role", "researcher", ...
        "netCDF_creator_name", "Pat Welch", ...
        "netCDF_creator_email", "pat@mousebrains.com", ...
        "netCDF_creator_institution", "CEOAS, Oregon State University", ...
        "netCDF_creator_type", "researcher", ...
        "netCDF_creator_url", "https://arcterx.ceoas.oregonstat.edu", ...
        "netCDF_id", sprintf("%s %s %s", project, subproj, year), ...
        "netCDF_institution", "CEOAS, Oregon State University", ...
        "netCDF_platform", "Rockland VMP250", ...
        "netCDF_product_version", "0.1", ...
        "netCDF_program", sprintf("%s %s %s", project, subproj, year), ...
        "netCDF_project", sprintf("%s %s %s", project, subproj, year) ...
        );
catch ME
    disp(getReport(ME));
end % try

path(origPath); % Restore the original path
