%
% Find cross correlation maximum between slow T and C to adjust C to T time
%
% July-2023, Pat Welch, pat@mousebrains.com

function a = CT_align(a, indicesSlow, info, basename)
arguments (Input)
    a struct % Output of odas_p2mat
    indicesSlow (2,:) int64 % output of get_profile for the slow variables
    info struct % parameters, defaults from get_info
    basename string % Label for the file
end % arguments Input
arguments (Output)
    a struct % Possibly modified version of odas_p2mat structure
end % arguments Output

if ~info.CT_has
    return % No CT data to align
end % isempty

TName = info.fp07_reference;

if contains(TName, "_")
    parts = split(TName, "_");
    prefix = parts(1);
else
    prefix = "JAC_";
end % if

names = string(fieldnames(a));
names = names(startsWith(names, prefix));
CName = names(names ~= TName);

T = a.(TName);
C = a.(CName);

fs_slow = a.fs_slow;
maxLags = round(5 * fs_slow); % 20 second maximum lag
[bb, aa] = butter(2, 4/(fs_slow/2)); % 4 Hz smoother to supress high-frequency noise

items = cell(size(indicesSlow,2),1);
for index = 1:numel(items)
    ii = indicesSlow(1,index):indicesSlow(2,index);
    t = a.t_slow(ii);
    x = filter(bb, aa, detrend(diff(T(ii))));
    y = filter(bb, aa, detrend(diff(C(ii))));
    [correlation, lags] = xcorr(x, y, maxLags, "coeff");
    [maxCorr, ix] = max(abs(correlation));
    items{index} = struct2table(struct( ...
        "lag", lags(ix) / fs_slow, ...
        "maxCorr", maxCorr, ...
        "n", numel(ii)));

    CC = circshift(C, lags(ix));
    y = filter(bb, aa, detrend(diff(CC(ii))));
    [correlation, lags] = xcorr(x, y, maxLags, "coeff");
    [maxCorr, ix] = max(abs(correlation));
    items{index}.shiftedLag = lags(ix) / fs_slow;
    items{index}.shiftedMax = maxCorr;
end % for index
items = vertcat(items{:});
items = sortrows(items, "lag");
items.cumsum = cumsum(items.maxCorr .* items.n);
[~, iMid] = min(abs(items.cumsum - (items.cumsum(end)/2)));

iShift = round(items.lag(iMid) * fs_slow);
fprintf("%s shifting %s by %f seconds to match %s\n", ...
    basename, CName, iShift / fs_slow, TName);
a.(CName) = circshift(C, iShift);
end % CTalign
