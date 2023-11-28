%
% Bin data by a real vector, such as depth
%
% This is a rewrite of existing code
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function binned = bin_by_real(binSize, sName, tbl, method, vNames, qStd)
arguments (Input)
    binSize double % scalar step size to bin data into
    sName string   % scalar vector name in tbl
    tbl table      % Table of data to bin
    method  % How to aggregate data into bins, string or function handle
    vNames (:,1) string = strings(0) % List of columns to be binned
    qStd logical = false % Should standard deviations be calculated?
end % arguments (Input)
arguments (Output)
    binned table % Binned data
end % arguments Output

if ~isa(method, "function_handle")
    if method == "median"
        method = @(x) median(x, 1, "omitnan");
    elseif method == "mean"
        method = @(x) mean(x, 1, "omitnan");
    else
        error("Unrecognized binning method %s\n", method)
    end % if
end % if ~isa

tblNames = string(tbl.Properties.VariableNames);

if ~ismember(sName, tblNames)
    error("%s is not in table, %s", sName, strjoin(tblNames, ","));
end % if ~ismember

if isempty(vNames) || numel(vNames) == 0 || ismissing(vNames) % No names specified, so use all columns
    vNames = tblNames;
end % if isempty

if ~all(ismember(vNames, tblNames)) % Check vNames are part of the table
    disp(tblNames(~ismember(vNames, tblNames)));
    error("Some of the variable names are not in tbl");
end % if ~all

if ~isreal(tbl.(sName))
    error("%s is not a real, %s", sName, class(tbl.(sName)));
end % ~isreal

d0 = floor(min(tbl.(sName)) / binSize) * binSize; % Find a smaller starting value rounded to binSize
d1 = ceil(max(tbl.(sName)) / binSize) * binSize; % Find a larger ending value rounded to binSize

if isnan(d0) % We can't interpolate
    binned = table();
    binned.n = uint32(zeros(0,1));
    binned.bin = nan(0,1);

    return;
end % if isnan

dBin = d0:binSize:(d1 + binSize/2); % All the bins

tbl.bin = interp1(dBin, dBin, tbl.(sName), "nearest");
tbl.grp = findgroups(tbl.bin);

binned = rowfun(@(x) x(1), tbl, ...
    "InputVariables", "bin", ...
    "GroupingVariables", "grp", ...
    "OutputVariableNames", "bin");
binned = renamevars(binned, "GroupCount", "n");
binned = removevars(binned, "grp");
binned.n = uint32(binned.n);

for vName = vNames
    binned.(vName) = rowfun(method, tbl, ...
        "InputVariables", vName, ...
        "GroupingVariables", "grp", ...
        "OutputFormat", "uniform");
    if qStd
        binned.(append(vName, "_std")) = rowfun(@(x) std(x, "omitnan"), tbl, ...
        "InputVariables", vName, ...
        "GroupingVariables", "grp", ...
        "OutputFormat", "uniform");
    end % if qStd
end % for vName
end % bin_by_real