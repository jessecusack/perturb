%
% Get an absolute path
%
% January-2022, Pat Welch, pat@mousebrains.com

function name = abspath(name)
arguments (Input)
    name string % Input pathname
end % arguments Input
arguments (Output)
    name string % Absolute path version of pathname
end % arguments Output

switch exist(name, "file") % Check if directory or file or doesn't exist
    case 2 % It is a file
        items = dir(name);
        name = fullfile(items(1).folder, items(1).name);
    case 7 % It is a folder
        items = dir(name);
        name = items(1).folder;
    otherwise
        [directory, filename, suffix] = fileparts(name);
        if isfolder(directory)
            items = dir(directory);
            name = fullfile(items(1).folder, append(filename, suffix));
        end % parent was a folder
end % switch
end % abspath
