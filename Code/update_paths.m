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

qP2Mat = startsWith(names, "p_file_");
qCTD = startsWith(names, "ctd_bin_") | startsWith(names, "profile_"); % ctd binning parameters
qCombo = startsWith(names, "netCDF_"); % Used in combined phase
qBinning = startsWith(names, "bin_") & ~qCombo; % Parameters for binning
qProfile = ~qCTD & ~qCombo & ~qBinning; % Parameters used in profile generation

[hashCTD,     jsonCTD]       = mk_hash_json(a, names(qCTD));
[hashCTDcombo, jsonCTDcombo] = mk_hash_json(a, names(qCTD | qP2Mat | qCombo));
[hashCombo,   jsonCombo]     = mk_hash_json(a, names(qCombo | qProfile | qBinning | qP2Mat));
[hashProfile, jsonProfile]   = mk_hash_json(a, names(qProfile));
[hashBinning, jsonBinning]   = mk_hash_json(a, names(qBinning));

a.output_root = abspath(a.output_root); % Get rid of ~ or relative paths
my_mk_directory(a.output_root); % Make sure the root path exists

a.mat_root       = fullfile(a.output_root, "Matfiles");
a.ctd_root       = mkRootDir(a.output_root, "CTD", hashCTD, jsonCTD);
a.ctd_combo_root = mkRootDir(a.output_root, "CTD_combo", hashCTDcombo, jsonCTDcombo);
a.combo_root     = mkRootDir(a.output_root, "combo", hashCombo, jsonCombo);
a.profile_root   = mkRootDir(a.output_root, "profiles", hashProfile, jsonProfile);
a.binned_root    = mkRootDir(a.output_root, "binned", hashBinning, jsonBinning);

a.log_root = fullfile(a.output_root, "logs"); % Where to write log files to
a.p_merge_root = fullfile(a.output_root, "merged_p_files"); % Merged P files
a.database_root = fullfile(a.output_root, "database"); % Where to store various databases

a.log_filename = fullfile(a.log_root, "master.log"); % output of diary

names = string(fieldnames(a));
for name = names(endsWith(names, "_root") | endsWith(names, "_filename"))'
    a.(name) = abspath(a.(name));
end % for
end % update_paths

function directory = mkRootDir(root, prefix, hash, json)
arguments (Input)
    root string
    prefix string
    hash string
    json string
end % arguments Input
arguments (Output)
    directory string
end % arguments Output

fn = append(prefix, ".", hash, ".json");
items = dir(fullfile(root, append(prefix, "_*"), fn));

if ~isempty(items)
    directory = string(items(1).folder);
    return;
end

directory = fullfile(root, append(prefix, "_0000"));

items = struct2table(dir(fullfile(root, append(prefix, "_*"))));

if ~isempty(items)
    n = regexp(string(items.name), append("^", prefix, "_(\d{4})$"), "tokens", "once");
    n = n(~cellfun(@isempty, n)); % Get rid of things like CTD_combo_\d{4} when looking for CTD_\d{4}
    if ~isempty(n)
        n = max(str2double(string(n)));
        directory = fullfile(root, sprintf("%s_%04d", prefix, n + 1));
    end
end

fn = fullfile(directory, fn);

my_mk_directory(fn);

[fid, errmsg] = fopen(fn, "w");
if fid == -1
    error("Error opening %s, %s", fn, errmsg);
end % if fid == -1

fwrite(fid, json);

status = fclose(fid);
if status ~= 0
    error("Error closing %s, %s", fn, ferror(fid));
end
end % mkRootDir

function [hash, json] = mk_hash_json(a, names)
arguments (Input)
    a struct
    names (:,1) string
end % Arguments Input
arguments (Output)
    hash string
    json string
end % arguments Output

namesAll = string(fieldnames(a))';
qPaths = endsWith(namesAll, "_root") | endsWith(namesAll, "_filename"); % Skip directories and filenames
qFunction = structfun(@(x) isa(x, 'function_handle'), a)'; % Find functions
qGeneral = startsWith(namesAll, "matlab_") | isequal(namesAll, "debug");
qDrop = qPaths | qFunction | qGeneral;

qKeep = ismember(namesAll, names) & ~qDrop;

json = jsonencode(rmfield(a, namesAll(~qKeep)), "PrettyPrint", true);

sha1 = java.security.MessageDigest.getInstance("SHA-1");
hash = join(string(dec2hex(uint8(sha1.digest(uint8(json))), 2)), "");
end % mk_hash_json