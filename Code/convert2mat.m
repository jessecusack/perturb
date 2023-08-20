% Create mat files from the p files
%
% June-2023, Pat Welch, pat@mousebrains.com
%
%%

function filenames = convert2mat(filenames, debug)
arguments (Input)
    filenames table % List of filenames to work with, output of mk_filenames
    debug logical = false % Should debugging messages be printed out?
end % arguments Input
arguments (Output)
    filenames table % qUse may be updated if there is a problem converting the file
end % arguments Output

% Use odas_p2mat to generate a mat file version of each pfile

for index = 1:size(filenames,1)
    row = filenames(index,:);
    if ~row.qUse
        if debug
            fprintf("%s not using %s\n", row.basename);
        end % if info.debug
        continue;
    end % if ~qUse
    fnP = row.fnP; % Input .P filename
    fnM = row.fnM; % Output .mat filename
    if isnewer(fnM, fnP)
        if debug
            fprintf("%s fnM is newer than fnP %s %s\n", row.basename, fnP, fnM)
        end % if info.debug
        continue;
    end % if isnewer
    stime = tic();

    my_mk_directory(fnM); % Make sure target directory exists
    try
        a = odas_p2mat(char(fnP)); % extract P file contents
        save(row.fnM, "-struct", "a"); % save into a mat file
        fprintf("Took %.2f seconds to convert %s\n", toc(stime), row.basename);
    catch ME
        filenames.qUse(index) = false;
        fprintf("Failed to convert %s\n\n%s\n", fnP, getReport(ME));
    end % try catch
end % for index
end % convert2mat
