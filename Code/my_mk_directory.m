% Create the directory that a file will live in, if needed
%
% June-2023, Pat Welch, pat@mousebrains.com

function my_mk_directory(fn, debug)
arguments (Input)
    fn string % Filename to make sure the directory portion exists
    debug logical = false % Print out debug messages
end % arguments

directory = fileparts(fn); % Directory portion of fn

if ~exist(directory, "dir") % Directory does not exist
    if debug
        fprintf("Creating %s\n", directory);
    end % if debug
    mkdir(directory)
end % ~exist directory
end % mkMyDir
