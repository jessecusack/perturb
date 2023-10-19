%
% This is an override of Matlab's input method for using odas in parallel processing
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function result = input(prompt, extra)
arguments (Input)
    prompt string
    extra string = missing
end % arguments Input
arguments (Output)
    result char
end % arguments Output
fprintf("TPW: Input request '%s' extra '%s'\n", prompt, extra);
result = ''; % Take default
end % input