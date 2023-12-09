%
% Convert SUNRISE .P files to binned data
%
% Nov-2023, Pat Welch, pat@mousebrains.com

project = "SUNRISE";
year = 2021;
% ship = "Pelican";
ship = "WaltonSmith";
% ship = "PointSur";

% bbl = true; % Trim at bottom and bin in elevation or not
bbl = false; % Don't trim bottom and bin in depth

if bbl
    diss_trim_top = true;
    diss_trim_bottom = true;
    diss_reverse = true;
    diss_fft_length = 0.25; % 1/4 second FFT length
    diss_length_fac = 2;    % 2*1/4 second for dissipation length, ~0.5m
    binDiss_width = 0.5;    % ~0.5m bins
    bin_variable = "elevation";
else
    diss_trim_top = true;
    diss_trim_bottom = true;
    diss_reverse = false;
    diss_fft_length = 0.5; % 1/2 second FFT length
    diss_length_fac = 2;    % 2*1/2 second for dissipation length, ~1m
    binDiss_width = 1;    % ~1m bins
    bin_variable = "depth";
end

suffix = fullfile(string(year), ship);

my_root = fileparts(mfilename("fullpath"));
code_root = fullfile(my_root, "../Code");
data_root = fullfile(my_root, "../..", project);
p_file_root = fullfile(data_root, "Data", suffix, "VMP");
output_root = fullfile(data_root, "Processed", suffix);

origPath = addpath(code_root, "-begin"); % Before reference to GPS_from_...

try
    GPS_filename = fullfile(data_root, "Data", suffix, "GPS", "gps.mat");
    GPS_class = GPS_from_mat(GPS_filename, missing, "linear", "time");

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
        "bin_variable", bin_variable, ... % which variable to bin scalar quantities by
        "diss_trim_top", diss_trim_top, ... % Trim top to drop prop wash
        "diss_trim_bottom", diss_trim_bottom, ... % Trim off bottom
        "diss_fft_length", diss_fft_length, ... % FFT length in seconds
        "diss_length_fac", diss_length_fac, ... % dissipation length factor, diss_fft_lenght * diss_length_fac
        "diss_reverse", diss_reverse, ... % FFTs from top to bottom or reversed?
        "binDiss_width", binDiss_width, ... % dissipation estimate bin size in meters
        "binDiss_variable", bin_variable, ... % Which variable to bin dissipation estimates by
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
catch ME
    disp(getReport(ME));
end % try

path(origPath);
