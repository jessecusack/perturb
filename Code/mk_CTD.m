%
% This has a strong assumption of doing tow-yo or station cast operations!!!!!!!!
%
% Extract CTD, DO, Fluorometer information for the whole file.

% Attempt to assign not insande Lat/Lon positions to the CTD data
% while it is being reeled back in.
%
% July-2023, Pat Welch, pat@mousebrains.com

function [ctd, fast] = mk_CTD(a, indicesSlow, gps)
arguments
    a struct % Output from odas_p2mat
    indicesSlow (2,:) int64 % Output from get_profile for the slow variables
    gps GPS_base_class % GPS class for getting GPS fixes
end % arguments Input
arguments (Output)
    ctd table  % slow CTD/DO/... variables
    fast table % fast Chlorophyll/Turbidity/... variables 
end % arguments Output

nameMap = struct( ...
    "P_slow", "P", ...
    "JAC_T", "T", ...
    "JAC_C", "C", ...
    "Chlorophyll", "Chlorophyll", ...
    "Turbidity", "Turbidity", ...
    "DO", "DO", ...
    "DO_T", "DO_T" ...
    );

ctd = table();
fast = table();
t0 = datetime(append(a.date, " ", a.time));
ctd.t = t0 + seconds(a.t_slow);
fast.t = t0 + seconds(a.t_fast);
szSlow = size(ctd.t);
for name = string(fieldnames(nameMap))'
    if isfield(a, name)
        val = a.(name);
        key = nameMap.(name);
        if isequal(size(val), szSlow)
            ctd.(key) = val;
        else
            fast.(key) = val;
        end % if isequal
    end % if
end % for name

ctd = addGPS(ctd, indicesSlow, gps);

ctd.SP = gsw_SP_from_C(ctd.C, ctd.T, ctd.T); % Practical salinity
ctd.SA = gsw_SA_from_SP(ctd.SP, ctd.P, ctd.lon, ctd.lat); % Absolute salinity
ctd.theta = gsw_CT_from_t(ctd.SA, ctd.T, ctd.P); % Conservation T
ctd.sigma = gsw_sigma0(ctd.SA, ctd.theta);
ctd.rho = gsw_rho(ctd.SA, ctd.theta, ctd.P) - 1000; % density kg/m^3 - 1000
ctd.depth = gsw_depth_from_z(gsw_z_from_p(ctd.P, ctd.lat)); % Depth  in meters

if size(fast,2) > 1
    fast.lat = interp1(ctd.t, ctd.lat, fast.t, "linear", "extrap");
    fast.lon = interp1(ctd.t, ctd.lon, fast.t, "linear", "extrap");
    fast.depth = interp1(ctd.t, ctd.depth, fast.t, "linear", "extrap");
else
    fast = [];
end % if size
end % mkCTD

function ctd = addGPS(ctd, indices, gps)
if isempty(indices) % No casts
    ctd.lon = gps.lon(ctd.t);
    ctd.lat = gps.lat(ctd.t);
    ctd.dtGPS = gps.dt(ctd.t);
    return
end % if

ctd.lon = nan(size(ctd.t)); % Preallocate
ctd.lat = nan(size(ctd.t));
ctd.dtGPS = nan(size(ctd.t));

% Before the first cast, assume the fix is at ctd.t
if indices(1,1) > 1
    ii = 1:(indices(1,1) - 1);
    t = ctd.t(ii);
    ctd.lon(ii) = gps.lon(t);
    ctd.lat(ii) = gps.lat(t);
    ctd.dtGPS(ii) = gps.dt(t);
end % if indices(1,1) > 1

nProfiles = size(indices,2);

for index = 1:nProfiles % Walk through each cast
    ii = indices(1,index):indices(2,index);
    t = ctd.t(ii(1)); % Time at start of cast
    ctd.lon(ii) = gps.lon(t);
    ctd.lat(ii) = gps.lat(t);
    ctd.dtGPS(ii) = gps.dt(t);
end % for

for index = 1:nProfiles % Gaps between casts
    if index == nProfiles % All the way to the end
        ii = (indices(2,index)+1):numel(ctd.t);
    else % between casts
        ii = (indices(2,index)+1):(indices(1,index+1)-1);
    end % if index

    if isempty(ii), continue; end

    lon0 = ctd.lon(ii(1)-1); % GPS fix for the down cast
    lat0 = ctd.lat(ii(1)-1);
    t0 = ctd.t(ii(1)-1); % last time in the cast
    t1 = ctd.t(ii(end)); % Last time before next cast
    dt = seconds(t1 - t0); % Time from start of being reeled in until reeled in
    dLon = gps.lon(t0) - lon0; % Lon difference between cast and ship fix at end of cast
    dLat = gps.lat(t0) - lat0;
    dLondt = dLon / dt; % Rate of change cast
    dLatdt = dLat / dt;

    t = ctd.t(ii);
    dt = seconds(t1 - t);
    ctd.lon(ii) = gps.lon(t) - dLondt .* dt;
    ctd.lat(ii) = gps.lat(t) - dLatdt .* dt;
end
end % addGPS