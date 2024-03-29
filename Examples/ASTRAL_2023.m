%
% Convert ASTRAL 2023 VMP .P files to binned data
%
% August-2023, Pat Welch, pat@mousebrains.com

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");
parent_root = fullfile(my_root, "../../ASTRAL/2023");
data_root = fullfile(parent_root, "Data");
p_file_root = fullfile(data_root, "VMP");
output_root = fullfile(parent_root, "Processed");

origPath = addpath(code_root, "-begin"); % Before reference to GPS_from_mat

try
    GPS_filename = fullfile(data_root, "GPS/gps.mat");
    GPS_class = GPS_from_mat(GPS_filename);

    pars = process_P_files( ...
        "debug", true, ...
        "p_file_root", p_file_root, ... % Where the input .P files are located
        "output_root", output_root, ... % Where to write output to
        "gps_class", GPS_class, ... % Class to supply GPS data
        "netCDF_contributor_name", "Pat Welch", ...
        "netCDF_contributor_role", "researcher", ...
        "netCDF_creator_name", "Pat Welch", ...
        "netCDF_creator_email", "pat@mousebrains.com", ...
        "netCDF_creator_institution", "CEOAS, Oregon State University", ...
        "netCDF_creator_type", "researcher", ...
        "netCDF_creator_url", "https://arcterx.ceoas.oregonstat.edu", ...
        "netCDF_id", "ASTRAL 2023", ...
        "netCDF_institution", "CEOAS, Oregon State University", ...
        "netCDF_platform", "Rockland VMP250", ...
        "netCDF_product_version", "0.1", ...
        "netCDF_program", "ASTRAL 2023", ...
        "netCDF_project", "ASTRAL 2023" ...
    	);
catch ME
    disp(getReport(ME));
end % try

path(origPath);
