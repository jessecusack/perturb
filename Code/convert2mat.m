% Create mat files from the p files
%
% June-2023, Pat Welch, pat@mousebrains.com
%
%%

function [row, a] = convert2mat(row, pars)
arguments (Input)
    row (1,:) table % List of filenames to work with, output of mk_filenames
    pars struct     % Defaults from get_info
end % arguments Input
arguments (Output)
    row (1,:) table % qUse may be updated if there is a problem converting the file
    a struct        % Output of odas_p2mat
end % arguments Output

% Use odas_p2mat to generate a mat file version of each pfile

if ~row.qMatOkay % Converting from a P file to a mat file has already failed
    a = [];
    return;
end % if ~row.qUse

row.fnMat = fullfile(pars.mat_root, append(row.name, ".mat"));

if isnewer(row.fnMat, row.fn) && ...
        (ismissing(pars.p2mat_hotel_file) || isnewer(row.fnMat, pars.p2mat_hotel_file))
    a = [];
    fprintf("%s: %s is newer than %s\n", row.name, row.fnMat, row.fn);
    return;
end % if isnewer

try
    stime = tic();
    p2args = mkP2MatArgs(pars);
    a = odas_p2mat(char(row.fn), p2args{:}); % extract P file contents
    my_mk_directory(row.fnMat);
    save(row.fnMat, "-struct", "a", pars.matlab_file_format); % save into a mat file
    row.qMatOkay = true;
    fprintf("Took %.2f seconds to convert %s\n", toc(stime), row.name);
catch ME
    row.qMatOkay = false;
    a = [];
    fprintf("Failed to convert %s\n\n%s\n", row.fn, getReport(ME));
end % try catch
end % convert2mat

function args = mkP2MatArgs(pars)
arguments (Input)
    pars struct % Defaults from get_info
end % arguments Input
arguments (Output)
    args cell
end % arguments Output

names = string(fieldnames(pars))';
names = names(startsWith(names, "p2mat_"));
args = cell(numel(names), 2);

for index = 1:numel(names)
    name = names(index);
    val = pars.(name);
    if ismissing(val), continue; end
    if isempty(val), continue; end
    if isstring(val) || ischar(val), val = char(val); end % odas does not like strings
    args{index,1} = char(extractAfter(name, "p2mat_"));
    args{index,2} = val;
end % for name

q = ~cellfun(@isempty, args(:,1));
args = args(q,:)';
args = args(:);
end % mkP2MatArgs
