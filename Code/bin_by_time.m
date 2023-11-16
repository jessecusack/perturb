%
% Bin data by time (or any other datetime like variable)
%
% This is a rewrite of existing code so it can be used for CTD time bining
% and AUV time binning.
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function binned = bin_by_time(dtBin, tName, tbl, method, vNames, qStd)
arguments (Input)
    dtBin duration % Time step to bin data into
    tName string   % Time vector name in tbl
    tbl table      % Table of data to bin
    method  % How to aggregate data into bins, string or function handle
    vNames (:,1) string = strings(0) % List of columns to be binned
    qStd logical = false % Should standard deviations be added?
end % arguments (Input)
arguments (Output)
    binned table % Binned data
end % arguments Output

tblNames = string(tbl.Properties.VariableNames);

if ~ismember(tName, tblNames)
    error("%s is not in table, %s", tName, tblNames);
end % if ~ismember

if ~isdatetime(tbl.(tName))
    error("%s is not a datetime", tName);
end % ~isdatetime

tbl.(tName) = posixtime(tbl.(tName));
binned = bin_by_real(seconds(dtBin), tName, tbl, method, vNames, qStd);
binned.bin = datetime(binned.bin, "ConvertFrom", "posixtime");
binned.(tName) = datetime(binned.(tName), "ConvertFrom", "posixtime");
end % bin_by_time