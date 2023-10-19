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

if isnewer(row.fnMat, row.fn)
    a = [];
    fprintf("%s: %s is newer than %s\n", row.name, row.fnMat, row.fn);
    return;
end % if isnewer

stime = tic();
my_mk_directory(row.fnMat);
try
    a = odas_p2mat(char(row.fn)); % extract P file contents
    save(row.fnMat, "-struct", "a", pars.matlab_file_format); % save into a mat file
    row.qMatOkay = true;
    fprintf("Took %.2f seconds to convert %s\n", toc(stime), row.name);
catch ME
    row.qMatOkay = false;
    a = [];
    fprintf("Failed to convert %s\n\n%s\n", row.fn, getReport(ME));
end % try catch
end % convert2mat
