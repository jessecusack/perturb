% For VMP/MR cast data which has a start/stop time,
% plot columns which have a start/stop time.
%
% Dec-2023, Pat Welch, pat@mousebrains.comfunction h = tpw_plot_pcolor(x0, x1, y, z)

function h = osgl_plot_pcolor(x0, x1, y, z, dxMax)
arguments (Input)
    x0 (:,1) % Starting time of a cast
    x1 (:,1) % Ending time of a cast
    y  (:,1) % depth of a bin
    z  (:,:) % color value
    dxMax (1,1) = nan % Maximum distance between x1(1:end-1) and x0(2:end) before inserting NaNs
end % arguments Input
arguments (Output)
    h % Ouput of pcolor command
end % arguments Output

if size(z,1) ~= numel(y)
    error("Number of rows in z, %d, not equal to length of y, %d", size(z,1), numel(y));
end % if zy

if size(z,2) ~= numel(x0)
    error("Number of columns in z, %d, not equal to length of x0, %d", size(z,2), numel(x0));
end % zx

if numel(x1) ~= numel(x0)
    error("x0, %d, and x1, %d, don't have the same length", numel(x0), numel(x1));
end % zx

if ~issorted(x0)
    error("x0 is not sorted");
end

if any(x1 <= x0)
    error("Some x1 <= x0");
end % if any

if any(x1(1:end-1) > x0(2:end))
    error("Some x1(1:end-1) > x0(2:end)")
end % if any

% x = [x0; x1(end)];
% x(2:end-1) = x1(1:end-1) + (x0(2:end) - x1(1:end-1)) / 2;
% zz = nan(numel(y), numel(x0) + 1);
% zz(:,1:end-1) = z;
% h = pcolor(x, y, zz);
% return;

x = [x0, x1]; % First col is starting time of cast, second is ending time
xx = reshape(x', 1, []); % A vector twice t0, t1, ...

zz = nan(numel(y), numel(xx));
zz(:,1:2:end) = z; % Every other column is nan

if ~ismissing(dxMax) % User specified a dtMax
    qClose = (x0(2:end) - x1(1:end-1)) <= dxMax; % Casts which are close enough to merge
    if any(qClose) % Found some columns close enough to drop nan column between them
        xMid = x1(1:end-1) + (x0(2:end) - x1(1:end-1)) / 2; % Mid point betweeen x1(i) and x0(i+1)
        x(qClose,2) = xMid(qClose); % Change end time of column
        x([false; qClose],1) = xMid(qClose); % Change starting time of next column
        iDrop = find(qClose) * 2; % Indices of columns to drop
        iKeep = setdiff(1:size(zz,2), iDrop); % Which columns to keep
        xx = reshape(x', 1, []);
        xx = xx(iKeep);
        zz = zz(:,iKeep);
    end % if ~isempty
end % if ismissing

h = pcolor(xx, y, zz);
h.EdgeColor = "none";
end % tpw_plot_color
