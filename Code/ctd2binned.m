%
% aggregate CTD/Chlorophyll data into time bins to reduce the size to something manageable
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, retval, mat, gps] = ctd2binned(row, mat, pars, latitude_default, longitude_default)
arguments (Input)
    row table % row to work on
    mat struct % Output of mat2profile
    pars struct % Parameters, defaults from get_info
    latitude_default double {mustBeInRange(latitude_default, -90, 90)} = 0
    longitude_default double {mustBeInRange(longitude_default, -180, 180)} = 0
end % arguments Input
arguments (Output)
    row table % row worked on
    retval (2,1) cell % (filename or missing) and (binned or empty)
    mat struct % Output of mat2profile
    gps % empty or GPS_base_class
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

t0 = row.t0;

tblSlow = table();
tblFast = table();

szSlow = size(mat.t_slow);
szFast = size(mat.t_fast);

ctd_bin_variables = unique([pars.CT_T_name, pars.CT_C_name, pars.ctd_bin_variables]);

for name = intersect(string(fieldnames(mat)), ctd_bin_variables)'
    sz = size(mat.(name));
    if isequal(sz, szSlow)
        tblSlow.(name) = mat.(name);
    elseif isequal(sz, szFast)
        tblFast.(name) = mat.(name);
    else
        fprintf("%s: %s is not fast nor slow\n", row.name);
    end
end % for

if isempty(tblSlow) && isempty(tblFast)
    retval = {missing, []};
    return;
end

method = pars.ctd_method; % Which method to aggregate the data together

dtBin = seconds(pars.ctd_bin_dt);

if ~isempty(tblSlow)
    tblSlow.t = t0 + seconds(mat.t_slow);
    tbl = bin_by_time(dtBin, "t", tblSlow, method);
    tbl = renamevars(tbl, "n", "nSlow");
else
    tbl = table();
end % if ~isempty tblSlow

if ~isempty(tblFast)
    tblFast.t = t0 + seconds(mat.t_fast);
    tFast = bin_by_time(dtBin, "t", tblFast, method);
    tFast = renamevars(tFast, "n", "nFast");
    if isempty(tbl)
        tbl = tFast;
    else
        tFast = renamevars(tFast, "t", "tFast");
        tbl = outerjoin(tbl, tFast, "Keys", "bin", "MergeKeys", true);
    end % isempty tbl
end % if ~isempty tblFast

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
        tbl.lat = gps.lat(tbl.bin);
        tbl.lon = gps.lon(tbl.bin);
        tbl.dtGPS = gps.dt(tbl.bin);
    else % Profiles
        tSlow = t0 + seconds(mat.t_slow(indicesSlow));
        tbl = addGPS(tbl, tSlow, gps);
    end % profiles
else % Not down
    tbl.lat = gps.lat(tbl.bin);
    tbl.lon = gps.lon(tbl.bin);
    tbl.dtGPS = gps.dt(tbl.bin);
end % if direction

lat = tbl.lat;
lat(isnan(lat)) = latitude_default;

if ismember("P_slow", tbl.Properties.VariableNames)
    tbl.P_slow(tbl.P_slow < -10 | tbl.P_slow > 12000) = nan; % Physical constraints for the pressure

    tbl.depth = gsw_depth_from_z(gsw_z_from_p(tbl.P_slow, lat));

    TName = pars.CT_T_name;
    CName = pars.CT_C_name;

    if all(ismember([TName, CName], fieldnames(mat))) % We can calculate seawater properties
        lon = tbl.lon;
        lon(isnan(lon)) = longitude_default;
        try
            P_slow = tbl.P_slow;
            P_slow(P_slow < -1 | P_slow > 12000) = nan;
            tbl.SP = gsw_SP_from_C(tbl.(CName), tbl.(TName), tbl.P_slow); % Practical salinity
            tbl.SA = gsw_SA_from_SP(tbl.SP, tbl.P_slow, lon, lat); % Absolute salinity
            tbl.theta = gsw_CT_from_t(tbl.SA, tbl.(TName), tbl.P_slow); % Conservation T
            tbl.sigma = gsw_sigma0(tbl.SA, tbl.theta);
            tbl.rho = gsw_rho(tbl.SA, tbl.theta, tbl.P_slow) - 1000; % density kg/m^3 - 1000
        catch ME
            fprintf("Pressure range %f to %f nans %d\n", ...
                min(tbl.P_slow, [], "omitmissing"), ...
                max(tbl.P_slow, [], "omitmissing"), ...
                sum(isnan(tbl.P_slow)));
            rethrow(ME)
        end % try
    end % if all ismember
end % if ismember P_slow

fnCTD = fullfile(pars.ctd_root, append(row.name, ".mat"));
row.fnCTD = fnCTD;

cInfo = row(:,["name", "t0", "tEnd", "sn"]);
cInfo = renamevars(cInfo, "tEnd", "t1"); % For NetCDF time range

binned = struct("tbl", tbl, "info", cInfo);

my_mk_directory(fnCTD);

save(fnCTD, "-struct", "binned", pars.matlab_file_format);
fprintf("%s: wrote %s\n", row.name, fnCTD);

retval = {fnCTD, binned};
end % ctd2binned

function ctd = addGPS(ctd, tSlow, gps)
arguments (Input)
    ctd table
    tSlow (2,:) datetime
    gps GPS_base_class
end % arguments Input
arguments (Output)
    ctd table
end % arguments Output

ctd.lon = nan(size(ctd.bin)); % Preallocate
ctd.lat = nan(size(ctd.bin));
ctd.dtGPS = nan(size(ctd.bin));

% Before the first cast, assume the fix is at ctd.bin
q = ctd.bin < tSlow(1,1); % Before first profile
if any(q)
    t = ctd.bin(q);
    ctd.lon(q) = gps.lon(t);
    ctd.lat(q) = gps.lat(t);
    ctd.dtGPS(q) = gps.dt(t);
end % if any q


nProfiles = size(tSlow,2);

for index = 1:nProfiles % Walk through each cast
    t = tSlow(1, index); % Start of the cast
    q = ctd.bin >= t & ctd.bin <= tSlow(2,index);
    ctd.lon(q) = gps.lon(t);
    ctd.lat(q) = gps.lat(t);
    ctd.dtGPS(q) = gps.dt(t);
end % for

for index = 1:nProfiles % Gaps between casts
    t0 = tSlow(2,index); % Start of the gap
    if index == nProfiles % All the way to the end
        t1 = ctd.bin(end);
    else % between casts
        t1 = tSlow(1,index+1);
    end % if index

    q = ctd.bin > t0 & ctd.bin < t1; % Points in the gap between casts
    if ~any(q), continue; end % Nothing to be done here
    ii = find(q); % Get indices

    lon0 = ctd.lon(ii(1)-1); % GPS fix for the down cast
    lat0 = ctd.lat(ii(1)-1);
    dt = seconds(t1 - t0); % Time from start of being reeled in until reeled in
    dLon = gps.lon(t0) - lon0; % Lon difference between cast and ship fix at end of cast
    dLat = gps.lat(t0) - lat0;
    dLondt = dLon / dt; % Rate of change cast
    dLatdt = dLat / dt;

    t = ctd.bin(q);
    dt = seconds(t1 - t);
    ctd.lon(q) = gps.lon(t) - dLondt .* dt;
    ctd.lat(q) = gps.lat(t) - dLatdt .* dt;
end
end % addGPS
