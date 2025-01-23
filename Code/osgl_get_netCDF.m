% Load data from a netCDF file into a matlab structure.
% If no optional arguments are supplied, all variables with
% a supported data type are loaded.
%
% The optional arguments can be strings or cell arrays of strings,
% which specify the variable names to load.
%
% If a specified variable name does not exist in fn, or is an
% unsupported data type, an error is thrown.
%
% The structure field 'fn' is set to the input filename.
%
% Jan-2012, Pat Welch, pat@mousebrains.com
% Jan-2019, Pat Welch, pat@mousebrains.com, switch to low level interface
%                      for speed reasons
% Dec-2022, Pat Welch, pat@mousebrains.com, add in compliance with CF-1.8
%                      metadata standards
% Jan-2024, Pat Welch, pat@mosuebrains.com, straighten out handling of variable names

function a = osgl_get_netCDF(fn, names)
arguments (Input)
    fn string {mustBeFile} % Input filename
end % arguments Input
arguments (Input,Repeating)
    names (:,1) string % Optional variable names
end % arguments Repeating
arguments (Output)
    a struct % Output structure of data read from fn
end % arguments output

names = cellfun(@(x) x(:), names, "UniformOutput", false); % Make sure any arrays are in the same orientation
names = string(vertcat(names{:}));

ncid = netcdf.open(fn); % Open the netCDF file
cleanUpObj = onCleanup(@() netcdf.close(ncid)); % In case of errors/warnings/...

if isempty(names)
    [names, varids] = loadNames(ncid);
else
    names = unique(names); % No duplicates
    [names, varids] = getVarIDs(ncid, names);
end % if

a = struct('fn', fn);
n = -1;

for i = 1:numel(names)
    name = names(i);
    varid = varids(i);
    try
        item = netcdf.getVar(ncid, varid);
        item = modifyCF(item, ncid, varid); % CF Metadata Convention modifications
        a.(genvarname(name)) = item;
        if isvector(item)
            n = max(n, size(item,1));
        end % if
    catch e
        warning('Error getting %s\n%s', name, getReport(e))
    end % try
end % for i

if ~isfield(a, 'uniqueID') && (n > 0)
    a.uniqueID = uint32(1:n)';
end % if
end % osgl_get_netCDF

function data = modifyCF(data, ncid, varid)
arguments (Input)
    data % Input data column from NetCDF file
    ncid double % NetCDF id from netcdf.open
    varid double % Variable id within ncid
end % arguments Output
arguments (Output)
    data % Possibly modified version of input data
end % arguments Output

qOkay = true(size(data)); % Initially assume all the data is good

try
    fillValue = netcdf.getAtt(ncid, varid, "_FillValue");
    if isnan(fillValue)
        qOkay(isnan(data)) = false;
    elseif isinf(fillValue)
        qOkay(isinf(data)) = false;
    else
        qOkay(fillValue == data) = false;
    end % if
catch
    % Do nothing
end % try _FillValue

try
    minVal = netcdf.getAtt(ncid, varid, "valid_min");
    qOkay(data < minVal) = false;
catch
    % Do nothing
end % try valid_min

try
    maxVal = netcdf.getAtt(ncid, varid, "valid_max");
    qOkay(data > maxVal) = false;
catch
    % Do nothing
end % try valid_max

try 
    values = netcdf.getAtt(ncid, varid, "valid_range");
    warning("valid_range handling not yet implemented! %f %s", varid, values);
%     minVal = values(1);
%     maxVal = values(2);
%     qOkay(data < minVal | data > maxVal) = false;
catch
    % Do nothing
end % try valid_range

try
    norm = netcdf.getAtt(ncid, varid, "scale_factor", "double");
    data = double(data);
    data(~qOkay) = nan;
    data(qOkay) = data(qOkay) * norm;
catch
    % Do nothing
end % try scale_factor

try
    offset = netcdf.getAtt(ncid, varid, "add_offset");
    data = data(qOkay) + offset;
catch
    % Do nothing
end % try add_offset

try
    units = netcdf.getAtt(ncid, varid, "units");
    tokens = regexpi(units, "^\s*(.*)\s+since\s+(\d+.*)\s*$", "tokens");
    if ~isempty(tokens) && (numel(tokens{1}) == 2)
        data = ctConvert(data, ncid, varid, tokens{1}{1}, tokens{1}{2}, qOkay);
    end % if
catch 
    % Do nothing
end % try calendar
end % modifyCF

function data = ctConvert(data, ncid, varid, dtUnits, timeStr, qOkay)
arguments (Input)
    data         % Input from NetCDF file various formats
    ncid double  % NetCDF id from netcdf.open
    varid double % Variable id within ncid
    dtUnits string % Time units from units attribute (The part before "since")
    timeStr string % Time reference from units attribute (The part after "since")
    qOkay logical % % Which data entries are good
end % arguments Input
arguments (Output)
    data % possibly datetime, if converted
end % arguments Output

try
    calendar = netcdf.getAtt(ncid, varid, "calendar");
    goodCalendars = ["", "standard", "gregorian", "proleptic_gregorian"];
    if ~ismember(calendar, goodCalendars)
        warning("Unsupported calendar, %s, for %s", ...
            calendar, netcdf.inqVar(ncid, varid));
        return
    end % if
catch ME
    getReport(ME)
    % Do nothing
end

switch lower(dtUnits) % The part before since
    case {"years", "year", "y"}
        dt = data(qOkay) * 365.242198781;
    case {"months", "month", "mon"}
        dt = data(qOkay) * 365.242198781 / 12;
    case {"days", "day", "d"}
        dt = days(data(qOkay));
    case {"hours", "hour", "hr", "h"}
        dt = hours(data(qOkay));
    case {"minutes", "minute", "min"}
        dt = minutes(data(qOkay));
    case {"seconds", "second", "sec", "s"}
        dt = seconds(data(qOkay));
    case {"milliseconds", "millisecond", "millisec", "msec", "ms"}
        dt = milliseconds(data(qOkay));
    case {"microseconds", "microsecond", "microsec", "usec", "us"}
        dt = milliseconds(data(qOkay) / 1e3);
    case {"nanoseconds", "nanosecond", "nanosec", "nsec", "ns"}
        dt = milliseconds(data(qOkay) / 1e6);
    otherwise
        warning("Unsupported calendar units, %s, for %s", ...
            units, netcdf.inqVar(ncid, varid));
        return
end % switch

fmt = "^\s*(\d{4})-(\d{1,2})-(\d{1,2})[\sT]?(\s*\d{1,2}:\d{1,2}:\d{1,2}([.]\d*|)(\s+([A-Za-z/_]+|[+-]?\d{1,2}([:]?\d{1,2}|))|)|)\s*$";
tfmt = "^\s*(\d{1,2}):(\d{1,2}):(\d{1,2}([.]?\d*|))(\s+([A-Za-z/_]+|[+-]?\d{1,2}([:]?\d{1,2}|))|)$";

tokens = regexp(timeStr, fmt, "tokens", "once");
if isempty(tokens)
    warning("Unable to parse time string, %s, for %s", ...
        timeStr, netcdf.inqVar(ncid, varid));
    return
end % if isempty

% Default time/timezone are midnight UTC
tHours = 0;
tMinutes = 0;
tSeconds = 0;
tz = "UTC";

if tokens{4} ~= "" %  time/timezone specified
    items = regexp(tokens{4}, tfmt, "tokens", "once");
    if isempty(items)
        warning("Unable to parse time string, %s, for %s", ...
            timeStr, netcdf.inqVar(ncid, varid));
        return
    end % isempty
    tHours = str2double(items{1});
    tMinutes = str2double(items{2});
    tSeconds = str2double(items{3});
    tz = strtrim(items{4}); % Pull off leading/trailing whitespace
    % For datetime, we need a leading plus sign, so if there isn't one on a pure numeric
    % version, add it
    if regexp(tz, "^\d{1,4}$")
        tz = strcat("+", tz);
    else % Need leading +- and two digits in 6:44
        items = regexp(tz, "^([+-]?)(\d{1,2}):(\d{1,2})$", "tokens", "once");
        if ~isempty(items)
            if items{1} == "", items{1} = "+"; end
            if items{3} == "", items{3} = "0"; end
            tz = sprintf("%s%02d:%02d", items{1}, str2double(items{2}), str2double(items{3}));
        end % if items
    end % if
    if isempty(tz), tz = "UTC"; end
end % if tokens{4}

refTime = datetime(str2double(tokens{1}), str2double(tokens{2}), str2double(tokens{3}), ...
    tHours, tMinutes, tSeconds, ...
    "TimeZone", tz);

data = NaT(size(data), "TimeZone", "UTC");
data(qOkay) = refTime + dt;
data.TimeZone = "UTC"; % Convert to UTC
data.TimeZone = ""; % Drop an explict timezone since it causes other problems
end % ctConvert

function [names, varids] = loadNames(ncid)
arguments (Input)
    ncid double % NetCDF file id from netcdf.open
end % arguments Input
arguments (Output)
    names (:,1) string  % Variable names in NetCDF file
    varids (:,1) double % Variable ids in ncid
end % arguments Output

[~, n] = netcdf.inq(ncid); % Get the number of variables
names = cell(n,1);
varids = zeros(size(names)) - 1;
minxtype = netcdf.getConstant('NC_BYTE');
maxxtype = netcdf.getConstant('NC_STRING');
for i = 1:n
    [varname, xtype] = netcdf.inqVar(ncid, i-1);
    if (xtype >= minxtype) && (xtype <= maxxtype)
        names{i} = varname;
        varids(i) = i-1;
    end % if
end % for i
msk = varids >= 0;
names = string(names(msk));
varids = varids(msk);
end % loadNames

function [names, varids] = getVarIDs(ncid, names)
arguments (Input)
    ncid double % NetCDF file id from netcdf.open
    names (:,1) string  % Variable names to get from the NetCDF file
end % arguments Input
arguments (Output)
    names (:,1) string  % Variable names to get from the NetCDF file
    varids (:,1) double % Variable ids in ncid
end % arguments Output

varids = zeros(size(names));
for i = 1:numel(names)
    varids(i) = netcdf.inqVarID(ncid, names(i));
end % for i
end % getVarIDs
