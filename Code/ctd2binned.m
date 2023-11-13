%
% aggregate CTD/Chlorophyll data into time bins to reduce the size to something manageable
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, retval, mat, gps] = ctd2binned(row, mat, pars, latitude_default)
arguments (Input)
    row table % row to work on
    mat struct % Output of mat2profile
    pars struct % Parameters, defaults from get_info
    latitude_default double {mustBeInRange(latitude_default, -90, 90)} = 0
end % arguments Input
arguments (Output)
    row table % row worked on
    retval (2,1) cell % (filename ormissing) and (binned or empty)
    mat struct % Output of mat2profile
    gps % empty GPS_base_class
end % arguments Output

gps = []; % Maybe initialized, if needed

fnCTD = fullfile(pars.ctd_root, append(row.name, ".mat"));
row.fnCTD = fnCTD;

if isnewer(fnCTD, row.fnMat)
    retval = {fnCTD, []}; % Filename of the data
    fprintf("%s: %s is newer than %s\n", row.name, row.fnCTD, row.fnMat);
    return;
end

if isempty(mat)
    fprintf("%s: Loading %s\n", row.name, row.fnMat);
    mat = load(row.fnMat);
end % if isempty

t0 = datetime(append(mat.date, " " , mat.time));

tblSlow = table();
tblFast = table();

szSlow = size(mat.t_slow);
szFast = size(mat.t_fast);

ctd_bin_variables = unique([pars.CT_T_name, pars.CT_C_name, pars.ctd_bin_variables]);

for name = intersect(string(fieldnames(mat)), ctd_bin_variables)'
    val = mat.(name);
    sz = size(val);
    if isequal(sz, szSlow)
        tblSlow.(name) = val;
    elseif isequal(sz, szFast)
        tblFast.(name) = val;
    else
        fprintf("%s: %s is not fast nor slow\n", row.name);
    end
end % for

if isempty(tblSlow) && isempty(tblFast)
    retval = {missing, []};
    return;
end

dtBin = pars.ctd_bin_dt;

tMin = round(min(mat.t_slow(1), mat.t_fast(1)) / dtBin) * dtBin;
tMax = round(max(mat.t_slow(end), mat.t_fast(end)) / dtBin) * dtBin;
binned = table();
binned.t = (tMin:dtBin:tMax)';
binned.nSlow = zeros(size(binned.t));
binned.nFast = zeros(size(binned.t));

if ~isempty(tblSlow)
    binned = binTable(dtBin, mat.t_slow, mat.P_slow, tblSlow, binned, "Slow");
end % if ~isempty tblSlow

if ~isempty(tblFast)
    binned = binTable(dtBin, mat.t_fast, [], tblFast, binned, "Fast");
end % if ~isempty tblFast

binned.t = t0 + seconds(binned.t);

gps = pars.gps_class.initialize(); % initialize GPS

if isequal(pars.profile_direction, "down") % Check for profiles for tow-yo
    indicesSlow = get_profile( ...
        mat.P_slow, mat.W_slow, ...
        pars.profile_pressure_min, ...
        pars.profile_speed_min, ...
        char(pars.profile_direction), ...
        pars.profile_min_duration, ...
        mat.fs_slow); % This will be redone in mat2profile, but this keeps it separate

    if isempty(indicesSlow) % No profiles
        binned.lat = gps.lat(binned.t);
        binned.lon = gps.lon(binned.t);
        binned.dtGPS = gps.dt(binned.t);
    else % Profiles
        t0 = datetime(append(mat.date, " ", mat.time));
        tSlow = t0 + seconds(mat.t_slow(indicesSlow));
        binned = addGPS(binned, tSlow, gps);
    end % profiles
else % Not down
    binned.lat = gps.lat(binned.t);
    binned.lon = gps.lon(binned.t);
    binned.dtGPS = gps.dt(binned.t);
end % if direction

lat = binned.lat;
lat(isnan(lat)) = latitude_default;

binned.pressure(binned.pressure < -10 | binned.pressure > 12000) = nan; % Physical constraints for the pressure

binned.depth = gsw_depth_from_z(gsw_z_from_p(binned.pressure, lat));

TName = pars.CT_T_name;
CName = pars.CT_C_name;

if all(ismember([TName, CName], fieldnames(mat))) % We can calculate seawater properties
    lon = binned.lon;
    lon(isnan(lon)) = 0;
    try
        binned.SP = gsw_SP_from_C(binned.(CName), binned.(TName), binned.pressure); % Practical salinity
        binned.SA = gsw_SA_from_SP(binned.SP, binned.pressure, lon, lat); % Absolute salinity
        binned.theta = gsw_CT_from_t(binned.SA, binned.(TName), binned.pressure); % Conservation T
        binned.sigma = gsw_sigma0(binned.SA, binned.theta);
        binned.rho = gsw_rho(binned.SA, binned.theta, binned.pressure) - 1000; % density kg/m^3 - 1000
    catch ME
        fprintf("Pressure range %f to %f nans %d\n", ...
            min(binned.pressure, [], "omitmissing"), ...
            max(binned.pressure, [], "omitmissing"), ...
            sum(isnan(binned.pressure)));
        rethrow(ME)
    end % try
end % if all ismember

fnCTD = fullfile(pars.ctd_root, append(row.name, ".mat"));
row.fnCTD = fnCTD;
my_mk_directory(fnCTD);
a = table2struct(binned, "ToScalar", true);
save(fnCTD, "-struct", "a", pars.matlab_file_format);
fprintf("%s: wrote %s\n", row.name, fnCTD);

retval = {fnCTD, binned};
end % ctd2binned

function binned = binTable(dtBin, t, pressure, tbl, binned, suffix)
arguments (Input)
    dtBin double {mustBePositive}
    t (:,1) double
    pressure (:,1) double
    tbl table
    binned table
    suffix string
end % arguments Input
arguments (Output)
    binned table
end % arguments Output

if ~isempty(pressure)
    tbl.pressure = pressure;
end % if ~isempty

names = string(tbl.Properties.VariableNames);
iNames = ["t", names];
oNames = [iNames, append(names, "_std")];
cNames = setdiff(oNames, "t");

tbl.t = round(t / dtBin) * dtBin;
tbl.grp = findgroups(tbl.t);
a = rowfun(@myMean, tbl, ...
    "InputVariables", iNames, ...
    "GroupingVariables", "grp", ...
    "OutputVariableNames", oNames);
[~, iLHS, iRHS] = innerjoin(binned, a, "Keys", "t");

if size(binned,1) ~= numel(iLHS) % There are more binned rows than iLHS
    binned(:, cNames) = array2table(nan(size(binned,1), numel(cNames)));
end % if

binned.(append("n", suffix))(iLHS) = a.GroupCount(iRHS);
binned(iLHS, cNames) = a(iRHS, cNames);
end % binTable

function varargout = myMean(varargin)
mu = cellfun(@(x) mean(x, "omitnan"), varargin, "UniformOutput", false);
sigma = cellfun(@(x) std(x, "omitnan"), varargin(2:end), "UniformOutput", false);
varargout = [mu, sigma];
end % myMean

function ctd = addGPS(ctd, tSlow, gps)
arguments (Input)
    ctd table
    tSlow (2,:) datetime
    gps GPS_base_class
end % arguments Input
arguments (Output)
    ctd table
end % arguments Output

ctd.lon = nan(size(ctd.t)); % Preallocate
ctd.lat = nan(size(ctd.t));
ctd.dtGPS = nan(size(ctd.t));

% Before the first cast, assume the fix is at ctd.t
q = ctd.t < tSlow(1,1); % Before first profile
if any(q)
    t = ctd.t(q);
    ctd.lon(q) = gps.lon(t);
    ctd.lat(q) = gps.lat(t);
    ctd.dtGPS(q) = gps.dt(t);
end % if any q


nProfiles = size(tSlow,2);

for index = 1:nProfiles % Walk through each cast
    t = tSlow(1, index); % Start of the cast
    q = ctd.t >= t & ctd.t <= tSlow(2,index);
    ctd.lon(q) = gps.lon(t);
    ctd.lat(q) = gps.lat(t);
    ctd.dtGPS(q) = gps.dt(t);
end % for

for index = 1:nProfiles % Gaps between casts
    t0 = tSlow(2,index); % Start of the gap
    if index == nProfiles % All the way to the end
        t1 = ctd.t(end);
    else % between casts
        t1 = tSlow(1,index+1);
    end % if index

    q = ctd.t > t0 & ctd.t < t1; % Points in the gap between casts
    if ~any(q), continue; end % Nothing to be done here
    ii = find(q); % Get indices

    lon0 = ctd.lon(ii(1)-1); % GPS fix for the down cast
    lat0 = ctd.lat(ii(1)-1);
    dt = seconds(t1 - t0); % Time from start of being reeled in until reeled in
    dLon = gps.lon(t0) - lon0; % Lon difference between cast and ship fix at end of cast
    dLat = gps.lat(t0) - lat0;
    dLondt = dLon / dt; % Rate of change cast
    dLatdt = dLat / dt;

    t = ctd.t(q);
    dt = seconds(t1 - t);
    ctd.lon(q) = gps.lon(t) - dLondt .* dt;
    ctd.lat(q) = gps.lat(t) - dLatdt .* dt;
end
end % addGPS