% Join two tables together based on keys
%
% take variables from rhs if they exist in both lhs and rhs
%
% names are variables not included in join
%
% June-2023, Pat Welch, pat@mousebrains.com

function lhs = my_joiner(lhs, rhs, keys, toExclude)
arguments (Input)
    lhs table % left-hand-side table
    rhs table % right-hand-side table which has priority over lhs
    keys (:,1) string % Keys to join on
    toExclude (:,1) string = strings(0,1) % columns to exclude
end % arguments Input
arguments (Output)
    lhs table % Joined table
end % arguments Output

if isempty(rhs), return; end

[~, iLeft, iRight] = outerjoin(lhs, rhs, "Keys", keys);
qJoint = iLeft ~= 0 & iRight ~= 0; % In both lhs and rhs
qRight = iLeft == 0 & iRight ~= 0; % Not in lhs but in rhs

if any(qJoint) % There are some rows in both tables
    toExclude = setdiff(string(rhs.Properties.VariableNames), union(keys, toExclude));
    lhs(iLeft(qJoint),toExclude) = rhs(iRight(qJoint), toExclude);
end % any qJoint

if any(qRight) % Rows only in rhs
    lhs = [lhs; rhs(iRight(qRight),:)];
    lhs = sortrows(lhs, keys);
end % if any qRight
end % my_joiner
