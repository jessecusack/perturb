% Bin profiles into depth bins
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, retval] = diss2binned(row, a, pars)
arguments (Input)
    row (1,:) table % row to work on
    a struct % Output of profile2diss, struct or empty
    pars struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    row table % row worked on
    retval (2,1) cell % {filename or missing, empty or binned profiles}
end % arguments Output

retval = {missing, []};

if ~row.qProfileOkay
    return;
end % if ~row.qProfileOkay

fnDiss = row.fnDiss;
fnBin = fullfile(pars.diss_binned_root, append(row.name, ".mat"));
row.fnDissBin = fnBin;

if isnewer(fnBin, fnDiss)
    retval = {fnBin, []}; % We want this for combining
    fprintf("%s: %s is newer than %s\n", row.name, row.fnBin, row.fnDiss);
    return;
end % if isnewer

if isempty(a)
    fprintf("Loading %s\n", row.fnDiss);
    a = load(row.fnDiss);
end % if isempty

%% Bin the data into depth bins

pInfo = a.info;
profiles = a.profiles;

fprintf("%s: Binning %d profiles\n", row.name, numel(profiles));

if pars.profile_direction == "time" % Bin in time
    binSize = seconds(pars.binDiss_width); % Bin stepsize in (sec)
    keyName = "t";
    binFunc = @bin_by_time;
    glueFunc = @glue_lengthwise;
else % Bin by depth
    binSize = pars.binDiss_width; % Bin stepsize (m)
    keyName = "depth";
    binFunc = @bin_by_real;
    glueFunc = @glue_widthwise;
end % if profile_direction

casts = cell(numel(profiles),1);
for index = 1:numel(profiles)
    profile = profiles{index};
    nE = size(profile.e, 2);
    prof2 = table();
    for name = string(profile.Properties.VariableNames)
        sz = size(profile.(name),2);
        if ~ismatrix(profile.(name)), continue; end
        if sz == 1
            prof2.(name) = profile.(name);
        elseif sz == nE
            for j = 1:sz
                prof2.(append(name, "_", string(j))) = profile.(name)(:,j);
            end % for j;
        end % if sz
    end % for name

    casts{index} = binFunc(binSize, keyName, prof2, pars.binDiss_method);
end % for index

qDrop = cellfun(@isempty, casts); % This shouldn't happend

if any(qDrop)
    casts = casts(~qDrop);
    pInfo = pInfo(~qDrop,:);
end % any qDrop

if isempty(casts)
    row.qProfileOkay = false;
    fprintf("%s: No usable casts found in %s\n", row.name, row.fnProf);
    return;
end

tbl = glueFunc("bin", casts);

binned = struct ( ...
    "tbl", tbl, ...
    "info", pInfo);
if isfield(a, "fp07")
    binned.fp07 = a.fp07;
end % if isfield

my_mk_directory(fnBin);
save(fnBin, "-struct", "binned", pars.matlab_file_format);
fprintf("%s: Saving %d profiles to %s\n", row.name, size(binned.info,1), fnBin);
retval = {fnBin, binned};
end % bin_data
