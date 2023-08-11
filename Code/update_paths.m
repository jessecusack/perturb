%
% Update paths from parameters set in get_info
% This is to clean up what the outside user can specify
%
% August-2023, Pat Welch, pat@mousebrains.com

function a = update_paths(a)
arguments (Input)
    a struct % parameters, defaults from get_info
end % arguments Input
arguments (Output)
    a struct % Modified version of input with paths set/updated
end % arguments

names = string(fieldnames(a))'; % All the fields in info
qPaths = endsWith(names, "_root") | endsWith(names, "_filename");
qKeep = structfun(@(x) isstring(x) || isnumeric(x), a)'; % Skip function handles
qBinned = ~qPaths & qKeep; % All the parameters
qProfile = qBinned & ~startsWith(names, "bin_"); % Everything except binning parameters

% Get unique hashs for the profileing and binning parameter sets
hash_profile = string(dec2hex(keyHash(jsonencode(rmfield(a, names(~qProfile))))));
hash_bin = string(dec2hex(keyHash(jsonencode(rmfield(a, names(~qBinned))))));

a.mat_root = fullfile(a.output_root, "Matfiles");
a.profile_root = fullfile(a.output_root, append("profiles.", hash_profile)); % Where to save profiles
a.binned_root = fullfile(a.output_root, append("binned.", hash_bin)); % Where to save binned data
a.ctd_root = fullfile(a.output_root, append("CTD.", hash_bin)); % Where to save the time binned CTD/DO... data

a.log_filename = fullfile(a.output_root, "log.txt"); % output of dairy
a.p2mat_filename = fullfile(a.mat_root, "filenames.mat"); % filenames information table
a.profile_info_filename = fullfile(a.profile_root, "profileInfo.mat"); % Profile information table
a.cast_info_filename = fullfile(a.binned_root, "cast.info.mat");
a.combo_info_filename = fullfile(a.binned_root, "combo.info.mat");
a.combo_filename = fullfile(a.binned_root, "combo.mat");
a.ctd_filename = fullfile(a.ctd_root, "CTD.mat");
a.ctd_info_filename = fullfile(a.ctd_root, "CTD.info.mat");

names = string(fieldnames(a));
for name = names(endsWith(names, "_root") | endsWith(names, "_filename"))'
    a.(name) = abspath(a.(name));
end % for
end % update_paths