% Plot VMP casts, depth versus time
%
% Dec-2023, Pat Welch, pat@mousebrains.com

function h = osgl_vmp_plot(t0, t1, depth, z, dxMax)
arguments (Input)
    t0 (:,1)    % Starting time of each column in z
    t1 (:,1)    % Ending time of each column in z
    depth (:,1) % Depth value of each row in z
    z (:,:)     % color value value in pcolor plot
    dxMax (1,1) = nan % Maximum allowed distance between t1(1:end) and t0(2:end) before inserting a column of nans
end % arguments Input
arguments (Output)
    h % Output of pcolor
end % arguments Output

if numel(t0) ~= numel(t1)
    error("numel of t0, %d, and t1, %d, don't agree", numel(t0), numel(t1));
end

if ~isequal(size(z), [numel(depth), numel(t0)])
    error("Size of z, [%s], not [%d %d]", num2str(size(z)), numel(depth), numel(t0));
end

if any(t0 >= t1)
    error("Some of t0 are >= t1");
end

h = osgl_plot_pcolor(t0, t1, depth, z, dxMax);
h.LineStyle = "none";
axis ij;
grid on;
% cb = colorbar("eastoutside");
% clim(quantile(z(:), [0.01, 0.99]));
end % osgl_vmp_plot