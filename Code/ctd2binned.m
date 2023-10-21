%
% aggregate CTD/Chlorophyll data into time bins to reduce the size to something manageable
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, retval, gps] = ctd2binned(row, mat, pars, gps)
arguments (Input)
    row table % row to work on
    mat struct % Output of mat2profile
    pars struct % Parameters, defaults from get_info
    gps % empty or GPS_base_class
end % arguments Input
arguments (Output)
    row table % row worked on
    retval (2,1) cell % (filename ormissing) and (binned or empty)
    gps % empty GPS_base_class
end % arguments Output

fnCTD = fullfile(pars.ctd_root, append(row.name, ".mat"));
row.fnCTD = fnCTD;

if isnewer(fnCTD, row.fnMat)
    retval = {fnCTD, []}; % Filename of the data
    fprintf("%s: %s is newer than %s\n", row.name, row.fnMat, row.fnCTD);
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

for name = intersect(string(fieldnames(mat)), pars.ctd_bin_variables)'
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

if isempty(gps) % Only initialize GPS if needed
    gps = pars.gps_class.initialize();
end % if isempty gps

binned.lat = gps.lat(binned.t);
binned.lon = gps.lon(binned.t);
binned.dtGPS = gps.dt(binned.t);

lat = binned.lat;
lat(isnan(lat)) = 0;

binned.depth = gsw_depth_from_z(gsw_z_from_p(binned.pressure, lat));

if all(ismember(["JAC_T", "JAC_C"], fieldnames(mat))) % We can calculate seawater properties
    lon = binned.lon;
    lon(isnan(lon)) = 0;
    try
        binned.SP = gsw_SP_from_C(binned.JAC_C, binned.JAC_T, binned.pressure); % Practical salinity
        binned.SA = gsw_SA_from_SP(binned.SP, binned.pressure, lon, lat); % Absolute salinity
        binned.theta = gsw_CT_from_t(binned.SA, binned.JAC_T, binned.pressure); % Conservation T
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

save(fnCTD, "binned", pars.matlab_file_format);
fprintf("%s: wrote %s\n", row.name, fnCTD);

retval = {fnCTD, binned};
end % bin_CTD

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
a = rowfun(@myMedian, tbl, ...
    "InputVariables", iNames, ...
    "GroupingVariables", "grp", ...
    "OutputVariableNames", oNames);
[~, iLHS, iRHS] = innerjoin(binned, a, "Keys", "t");
try
binned.(append("n", suffix))(iLHS) = a.GroupCount(iRHS);
binned(iLHS, cNames) = a(iRHS, cNames);
catch ME
    a(IRHS,:)
    binned(iLHS,:)
    cNames
    suffix
    rethrow(ME)
end % try
end % binTable

function varargout = myMedian(varargin)
mu = cellfun(@(x) median(x, "omitnan"), varargin, "UniformOutput", false);
sigma = cellfun(@(x) std(x, "omitnan"), varargin(2:end), "UniformOutput", false);
varargout = [mu, sigma];
end % myFun