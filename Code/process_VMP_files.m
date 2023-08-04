%
% Convert P files to binned data
%
% This is ground up rewrite of Fucent's code with a lot of enhancements
%
% July-2023, Pat Welch, pat@mousebrains.com
%
%

function c_info = process_VMP_files(varargin)
% Default for saves will now be v7.3 during this session
rootSettings = settings();
rootSettings.matlab.general.matfile.SaveFormat.TemporaryValue = "v7.3";

% Process input arguments and build a structure with parameters
info = get_info(varargin{:}); % Parse arguments and supply defaults
info = update_paths(info); % Populate all the paths

my_mk_directory(info.log_filename, true); % Make sure the directory to write logfile to exists

diary(info.log_filename);
diary on; % Record all output
fprintf("\n\n********* Started at %s **********\n\n", datetime());
fprintf("%s\n\n", jsonencode(rmfield(info, "gps_class"), "PrettyPrint", true));

try
    filenames = mk_filenames(info); % Build a list of filenames to be processed from .P files on disk
    filenames = convert2mat(filenames, info.debug); % Convert .P to .mat files using odas_p2mat
    save(info.p2mat_filename, "filenames"); % Save the list of filenames for future processing

    p_info = mat2profiles(filenames, info); % Split into profiles

    b_info = bin_data(p_info, info); % Bin profiles into depth bins
    c_info = mk_combo(b_info, info); % Combine profiles together
    mk_combo_netCDF(info); % Create a NetCDF version of combo.mat, if needed

    bin_CTD(p_info, info); % Bin CTD/DO/Chlorophyll/Turbidity/... data by time bins
catch ME
    fprintf("\n\nEXCEPTION\n%s\n\n", getReport(ME));
end % try

fprintf("\n\n********* Finished at %s **********\n", datetime());
diary off;

end % processVMPfiles
