%
% Convert SUNRISE .P files to binned data
%
% Nov-2023, Pat Welch, pat@mousebrains.com

project = "SUNRISE";
year = 2021;
ship = "Pelican";

suffix = fullfile(string(year), ship);

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");
data_root = fullfile("~/Desktop", project);
p_file_root = fullfile(data_root, "Data", suffix, "VMP");
output_root = fullfile(data_root, "Processed", suffix);

addpath(code_root, "-begin"); % Before reference to GPS_from_...

GPS_filename = fullfile(data_root, "Data", suffix, "Ship", "gps.mat");
GPS_class = GPS_from_mat(GPS_filename, missing);

%    "p_file_pattern", "SR1P2_002*", ...

pars = process_P_files( ...
    "debug", true, ...
    "p_file_root", p_file_root, ... % Where the input .P files are located
    "p_file_merge", true, ... % Merge P files that were rolled over due to size
    "output_root", output_root, ... % Where to write output to
    "gps_class", GPS_class, ... % Class to supply GPS data
    "fp07_order", 1, ... % Small temprature range, so linear fit
    "trim_calculate", true, ... % Calculate when the VMP is in stable descent below prop wash
    "bottom_calculate", true, ... % Calculate the bottom depth from VMP crashing into the bottom
    "bin_width", 0.25, ... % Bin size for scalar variables
    "bin_variable", "elevation", ... % Bin by height above bottom
    "diss_trim_top", true, ... % Trim top to drop prop wash
    "diss_trim_bottom", true, ... % Trim off bottom
    "diss_reverse", true, ... % Calculate bottom up, reverse in time
    "diss_fft_length", 0.25, ... % 1/4 second FFT lengths
    "diss_length_fac", 2, ... % 1/2 second dissipation calculations, ~1/2 meter
    "binDiss_width", 0.5, ... % 1/2 meter dissipation estimates
    "binDiss_variable", "elevation", ... % Bin in elevation above bottom
    "netCDF_contributor_name", "Pat Welch", ...
    "netCDF_contributor_role", "researcher", ...
    "netCDF_creator_name", "Pat Welch", ...
    "netCDF_creator_email", "pat@mousebrains.com", ...
    "netCDF_creator_institution", "CEOAS, Oregon State University", ...
    "netCDF_creator_type", "researcher", ...
    "netCDF_creator_url", "https://arcterx.ceoas.oregonstat.edu", ...
    "netCDF_id", append(project, " ", string(year), " ",ship), ...
    "netCDF_institution", "CEOAS, Oregon State University", ...
    "netCDF_platform", "Rockland VMP250", ...
    "netCDF_product_version", "0.1", ...
    "netCDF_program", append(project, " ", string(year)), ...
    "netCDF_project", append(project, " ", string(year)) ...
	);

rmpath(code_root);