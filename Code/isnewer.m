% Check if the lhs file is newer than the rhs file
%
% June-2023, Pat Welch, pat@mousebrains.com

function q = isnewer(lhs, rhs, rhs_info)
arguments (Input)
    lhs string % Filename
    rhs string % Filename
    rhs_info struct = [] % Output of dir for rhs, use this instead of dir(rhs) for speed
end % arguments Input
arguments (Output)
    q logical % Does lhs exist and is it newer than rhs?
end % arguments Output

q = exist(lhs, "file");
if ~q, return; end
lhs_info = dir(lhs);

if isempty(rhs_info), rhs_info = dir(rhs); end

q = lhs_info.datenum > rhs_info.datenum;
end % if isnewer
