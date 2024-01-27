%
% Update paths from parameters set in get_info
% This is to clean up what the outside user can specify
%
% August-2023, Pat Welch, pat@mousebrains.com

function pars = update_paths(pars)
arguments (Input)
    pars struct % parameters, defaults from get_info
end % arguments Input
arguments (Output)
    pars struct % Modified version of input pars with paths set/updated
end % arguments

names = string(fieldnames(pars))'; % All the fields in info

qPfiles = startsWith(names, "p_file_"); % Which files will be in the combo file
qPfilesTrim = qPfiles & endsWith(names, "_trim");
qPfilesMerge = (qPfiles & endsWith(names, "_merge")) | qPfilesTrim;
qP2Mat = startsWith(names, "p2mat_") | qPfilesMerge; % How to go from P file to mat via odas_p2mat
qNetCDF = startsWith(names, "netCDF_"); % NetCDF global parameters for combined files
qProfileGen = startsWith(names, "profile_"); % How profiles are extracted
qCT = startsWith(names, "CT_");
qGPS = startsWith(names, "gps_");
qProf = qP2Mat ...
    | qProfileGen ...
    | qCT ...
    | qGPS ...
    | startsWith(names, "trim_") ...
    | startsWith(names, "bbl_") ...
    | startsWith(names, "fp07_");
qProfBin = qProf | startsWith(names, "bin_");
qDiss = qProf ...
    | startsWith(names, "diss_"); % Dissipation parameters
qDissBin = qDiss ...
    | startsWith(names, "binDiss_"); % how to bin dissipation
qChi = qDiss ...
    | startsWith(names, "chi_"); % Chi related parameters
qChiBin = qChi ...
    | startsWith(names, "binChi_"); % how to bin chi
qCTD = qP2Mat ...
    | (qProfileGen & (pars.profile_direction == "down")) ...
    | qCT ...
    | qGPS ...
    | startsWith(names, "ctd_bin_"); % ctd binning parameters

[hashPtrimmed,  jsonPtrimmed]  = mk_hash_json(pars, names(qPfilesTrim));
[hashPmerged,   jsonPmerged]   = mk_hash_json(pars, names(qPfilesMerge));
[hashP2Mat,     jsonP2Mat]     = mk_hash_json(pars, names(qP2Mat));
[hashCTD,       jsonCTD]       = mk_hash_json(pars, names(qCTD));
[hashCTDcombo,  jsonCTDcombo]  = mk_hash_json(pars, names(qCTD | qPfiles | qNetCDF));
[hashProf,      jsonProf]      = mk_hash_json(pars, names(qProf));
[hashProfBin,   jsonProfBin]   = mk_hash_json(pars, names(qProfBin));
[hashProfCombo, jsonProfCombo] = mk_hash_json(pars, names(qProfBin | qPfiles | qNetCDF));
[hashDiss,      jsonDiss]      = mk_hash_json(pars, names(qDiss));
[hashDissBin,   jsonDissBin]   = mk_hash_json(pars, names(qDissBin));
[hashDissCombo, jsonDissCombo] = mk_hash_json(pars, names(qDissBin | qPfiles | qNetCDF));
[hashChi,       jsonChi]       = mk_hash_json(pars, names(qChi));
[hashChiBin,    jsonChiBin]    = mk_hash_json(pars, names(qChiBin));
[hashChiCombo,  jsonChiCombo]  = mk_hash_json(pars, names(qChiBin | qPfiles | qNetCDF));

pars.output_root = abspath(pars.output_root); % Get rid of ~ or relative paths
my_mk_directory(pars.output_root); % Make sure the root path exists

pars.p_trim_root      = mkRootDir(pars.output_root, "trimed_p_files", hashPtrimmed, jsonPtrimmed, pars.p_file_trim); % Trimmed P files
pars.p_merge_root     = mkRootDir(pars.output_root, "merged_p_files", hashPmerged, jsonPmerged, pars.p_file_merge); % Merged P files
pars.mat_root         = mkRootDir(pars.output_root, "Matfiles", hashP2Mat, jsonP2Mat);
if pars.ctd_bin_enable
    pars.ctd_root         = mkRootDir(pars.output_root, "CTD", hashCTD, jsonCTD);
    pars.ctd_combo_root   = mkRootDir(pars.output_root, "CTD_combo", hashCTDcombo, jsonCTDcombo);
end % if
pars.profile_root     = mkRootDir(pars.output_root, "profiles", hashProf, jsonProf);
pars.prof_binned_root = mkRootDir(pars.output_root, "profiles_binned", hashProfBin, jsonProfBin);
pars.prof_combo_root  = mkRootDir(pars.output_root, "profiles_combo", hashProfCombo, jsonProfCombo);
pars.diss_root        = mkRootDir(pars.output_root, "diss", hashDiss, jsonDiss);
pars.diss_binned_root = mkRootDir(pars.output_root, "diss_binned", hashDissBin, jsonDissBin);
pars.diss_combo_root  = mkRootDir(pars.output_root, "diss_combo", hashDissCombo, jsonDissCombo);
if pars.chi_enable
    pars.chi_root = mkRootDir(pars.output_root, "chi", hashChi, jsonChi);
    pars.chi_binned_root = mkRootDir(pars.output_root, "chi_binned", hashChiBin, jsonChiBin);
    pars.chi_combo_root  = mkRootDir(pars.output_root, "chi_combo", hashChiCombo, jsonChiCombo);
end % if chi

pars.log_root = fullfile(pars.output_root, "logs"); % Where to write log files to
pars.database_root = fullfile(pars.output_root, "database"); % Where to store various databases

pars.log_filename = fullfile(pars.log_root, "master.log"); % output of diary

names = string(fieldnames(pars));
for name = names(endsWith(names, "_root") | endsWith(names, "_filename"))'
    if ~ismissing(pars.(name))
        pars.(name) = abspath(pars.(name));
    end % if ~ismissing
end % for
end % update_paths

function directory = mkRootDir(root, prefix, hash, json, qMake)
arguments (Input)
    root string
    prefix string
    hash string
    json string
    qMake logical = true
end % arguments Input
arguments (Output)
    directory string
end % arguments Output

if ~qMake
    directory = missing;
    return;
end

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