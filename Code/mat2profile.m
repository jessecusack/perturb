% Split mat file into individual profiles
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, profilesInfo] = mat2profile(row, mat, pars, gps)
arguments (Input)
    row table % row to work on
    mat struct % Output of odas_p2mat
    pars struct % Parameters, defaults from get_info
    gps % empty or GPS_base_class
end % arguments Input
arguments (Output)
    row table % row worked on
    profilesInfo struct % profiles extracted from a
end % arguments Output

stime = tic();

fnM = row.fnMat;
fnProf = fullfile(pars.profile_root, append(row.name, ".mat"));
row.fnProf = fnProf;

if isnewer(fnProf, fnM) % fnProf is newer than fnM
    fprintf("%s: %s newer than %s\n", row.name, fnProf, fnM);
    profilesInfo = [];
    return;
end

if isempty(mat) % we need to load a
    fprintf("Loading %s\n", row.fnMat);
    mat = load(row.fnMat);
end

if pars.profile_direction == "time"
    indicesSlow = [1; numel(mat.t_slow)];
else
    indicesSlow = get_profile( ...
        mat.P_slow, mat.W_slow, ...
        pars.profile_pressure_min, ...
        pars.profile_speed_min, ...
        char(pars.profile_direction), ...
        pars.profile_min_duration, ...
        mat.fs_slow);
end

if isempty(indicesSlow) % No profiles found, so change qProfileOkay to false
    row.qProfileOkay = false;
    profilesInfo = [];
    fprintf("No profiles found in %s\n", row.name);
    return;
end % if isempty indices

nProfiles = size(indicesSlow, 2);

fprintf("%s spliting into %d profiles\n", row.name, nProfiles);

indicesFast = interp1(mat.t_fast, 1:numel(mat.t_fast), mat.t_slow(indicesSlow), ...
    "nearest", "extrap"); % Fast indices for each profile

% First change values in a for calibration and time shifts
% Adjust T?_(slow|fast) and shift CT_T_name and CT_C_name

mat = fp07_calibration(mat, indicesSlow, pars, row.name);
qFP07 = isfield(mat, "fp07Info"); % FP07 lags calculated

mat = CT_align(mat, indicesSlow, pars, row.name); % Shift CT_C_name to match CT_T_name

if isempty(gps) % Only initialize GPS if needed
    gps = pars.gps_class.initialize();
end % if isempty gps

profiles = cell(nProfiles, 1);
profileInfo = mk_profile_info(row, nProfiles, mat);

if qFP07 % fp07 lags calculated
    fp07_lags = mat.fp07Info;
    fp07_lags.name = repmat(row.name, size(fp07_lags, 1), 1);
end % if qFP07

% Pre-build list of variables that are fast, slow, and other
szSlow = size(mat.t_slow);
szFast = size(mat.t_fast);
names = string(fieldnames(mat));
namesFast = strings(size(names));
namesSlow = strings(size(names));
namesOtro = strings(size(names));
for i = 1:numel(names)
    name = names(i);
    sz = size(mat.(name));
    if sz == szFast
        namesFast(i) = name;
    elseif sz == szSlow
        namesSlow(i) = name;
    else
        namesOtro(i) = name;
    end % if sz
end % for name

namesFast = namesFast(namesFast ~= "")';
namesSlow = namesSlow(namesSlow ~= "")';
namesOtro = namesOtro(namesOtro ~= "")';

namesFast = namesFast(~endsWith(namesFast, "_YD")); % Drop year day
namesSlow = namesSlow(~endsWith(namesSlow, "_YD"));

t0 = datetime(append(mat.date, " ", mat.time)); % Start time for this .P file

for j = 1:nProfiles
    ii = indicesSlow(1,j):indicesSlow(2,j); % Indices for slow variables
    jj = indicesFast(1,j):indicesFast(2,j); % Indices for fast variables
    profile = struct("slow", table(), "fast", table());
    profile.slow.t = t0 + seconds(mat.t_slow(ii)); % Times of slow samples
    profile.fast.t = t0 + seconds(mat.t_fast(jj)); % Times of fast samples
    for name = namesFast
        profile.fast.(name) = mat.(name)(jj);
    end % for namesFast
    for name = namesSlow
        profile.slow.(name) = mat.(name)(ii);
    end % for namesSlow
    for name = namesOtro
        profile.(name) = mat.(name);
    end % for namesOtro

    profile.lat = gps.lat(profile.slow.t); % Latitude at start of profile
    profile.lon = gps.lon(profile.slow.t); % Longitude at start of profile
    profile.dtGPS = gps.dt(profile.slow.t); % Nearest GPS timestamp
    profile.slow = add_seawater_properties(profile, pars); % SP/SA/theta/rho/...
    profile.fast.depth = interp1(profile.slow.t_slow, profile.slow.depth, ...
        profile.fast.t_fast, "linear", "extrap");
    profile.slow.lat = profile.lat; % Thinking about AUVs
    profile.slow.lon = profile.lon;
    profile.slow.dtGPS = profile.dtGPS;
    profileInfo.lat(j) = profile.lat(1); % Start of profile
    profileInfo.lon(j) = profile.lon(1);
    profileInfo.dtGPS(j) = profile.dtGPS(1);
    profileInfo.min_depth(j) = min(profile.slow.depth, [], "omitnan");
    profileInfo.max_depth(j) = max(profile.slow.depth, [], "omitnan");
    profileInfo.t0(j) = profile.slow.t(1);
    profileInfo.t1(j) = profile.slow.t(end);
    profileInfo.n_slow(j) = numel(ii);
    profileInfo.n_fast(j) = numel(jj);
    [profileInfo(j,:), profile] = bottom_crash_profile(j, profileInfo(j,:), profile, pars);
    profile = pruneProfile(profile); % Remove some fields
    profiles{j} = profile;
    if profileInfo.dtGPS(j) > pars.gps_max_time_diff
        fprintf("WARNING: %s profile %d GPS fix %s from t0 %s\n", ...
            row.name, j, string(seconds(profileInfo.dtGPS(j)), "hh:mm:ss"), ...
            profileInfo.t0(j));
    end % if profile
end % for j

if ~pars.bottom_calculate
    profileInfo = removevars(profileInfo, "bottom_depth");
end % Drop bottom_depth if not calculated

profileInfo = trim_top_profiles(profiles, profileInfo, pars);

profilesInfo = struct();
profilesInfo.profiles = profiles;
profilesInfo.row = row(1,["name", "date", "fClock" "t0", "t1", "tEnd"]);
profilesInfo.pInfo = profileInfo;
if qFP07
    profilesInfo.fp07Lags = fp07_lags;
end % qFP07

my_mk_directory(fnProf);
save(fnProf, "-struct", "profilesInfo", pars.matlab_file_format);
fprintf("%s: Took %.2f seconds to create %d profiles in %s\n", row.name, toc(stime), numel(profiles), fnProf);
end % mat2profiles

function tbl = mk_profile_info(row, nProfiles, mat)
arguments (Input)
    row (1,:) table
    nProfiles uint32
    mat struct
end % arguments input
arguments (Output)
    tbl table
end % arguments Output

tbl = table();
tbl.name = repmat(row.name, nProfiles, 1);
tbl.index = (1:nProfiles)';
tbl.t0 = NaT(nProfiles,1);
tbl.t1 = NaT(nProfiles,1);
tbl.n_slow = nan(nProfiles,1);
tbl.n_fast = nan(nProfiles,1);
tbl.min_depth = nan(nProfiles,1);
tbl.max_depth = nan(nProfiles,1);
tbl.lat = nan(nProfiles,1);
tbl.lon = nan(nProfiles,1);
tbl.bottom_depth = nan(nProfiles, 1);

for name = ["fullPath", "fs_fast", "fs_slow", "odas_version"]
    tbl.(name) = repmat(mat.(name), nProfiles, 1);
end % for name
tbl.fullPath = string(tbl.fullPath); % char to string

for name = ["aoa", "speed_cutout", "speed_tau", "vehicle", "temperature_source", "speed_source"]
    if isfield(mat.params, name)
        val = mat.params.(name);
        if ischar(val), val = string(val); end
        tbl.(name) = repmat(val, nProfiles, 1);
    end % if
end % for name
end % mk_profile_info

function profile = pruneProfile(profile)
arguments (Input)
    profile struct
end % arguments Input
arguments (Output)
    profile struct
end % arguments Output

names = string(fieldnames(profile));
profile = rmfield(profile, setdiff(names, ["slow", "fast"]));
end % pruneProfile