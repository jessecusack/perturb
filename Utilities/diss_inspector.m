%
% Plot a dissipation combo.mat file and present diagnostics
% plots based on where the user clicks on the pcolor plot of the dissipation.
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function diss_inspector(varargin)
arguments (Input,Repeating)
    varargin % key/val arguments
end % arguments Input,Repeating

pars = parse_arguments(varargin{:});
mkPlot(pars);
end % diss_inspector

function pars = parse_arguments(varargin)
arguments (Repeating)
    varargin % key/val arguments
end % arguments Repeating

p = inputParser();

%% pars as returned by process_P_files
addParameter(p, "pars", struct(), @isstruct); % Turn on debugging messages
addParameter(p, "figure", 10, @(x) isnumeric(x) && (rem(x, 1) == 0) && x > 0 && x < 100);
addParameter(p, "debug", false, @islogical); % Enable debugging
addParameter(p, "xLim", [], @(x) isdatetime(x) && numel(x) == 2 && isvector(x))
addParameter(p, "yLim", [], @(x) isreal(x) && numel(x) == 2 && isvector(x))
addParameter(p, "cLim", [], @(x) isreal(x) && numel(x) == 2 && isvector(x))

parse(p, varargin{:});
a = p.Results(1);
pars = a.pars;

if isempty(fieldnames(pars))
    error("You must supply pars!");
end % if isempty

for name = setdiff(string(fieldnames(a))', "pars")
    pars.(name) = a.(name);
end % for name
end % parse_arguments

function mkPlot(pars)
arguments (Input)
    pars struct % paths to where output of process_P_files is stored
end % arguments Input

combo = load(fullfile(pars.diss_combo_root, "combo.mat"));

fig = figure(pars.figure);
% clf;
t = tiledlayout(1, 3, "TileSpacing", "tight", "Padding", "tight");
h = cell(prod(t.GridSize),1);
h{1} = mkEpsilonPlot(combo, "epsilonMean");
ylabel("Depth (meters)");
h{2} = mkEpsilonPlot(combo, "e_1");
h{3} = mkEpsilonPlot(combo, "e_2", true);
cb = colorbar("EastOutside");
cb.Label.String = "log_{10}(\epsilon) (W kg^-1)";
sgtitle(pars.diss_combo_root, "Interpreter", "none");

h = vertcat(h{:});

linkaxes(h, "y"); % We'll use y linkage on many plots so split out from linkprop

persistent hLink; % Unfortunately, hLink must be long lived to keep linkprop working
hLink = linkprop(h, ["CLim", "XLim"]);

if ~isempty(pars.xLim), xlim(pars.xLim); end
if ~isempty(pars.yLim), ylim(pars.yLim); end
if ~isempty(pars.cLim)
    clim(pars.cLim);
else
    clim(quantile(log10(combo.tbl.epsilonMean(:)), [0.05, 0.95]));
end

for ax = h(2:end-1)' % Turn off y axis labels of middle plots
    ax.YAxis(1).Visible = "off";
end

for ax = h' % Add callbacks to each plot
    for kid = ax.Children'
        kid.ButtonDownFcn = @(src, evt) myButtonPress(src, evt, pars, combo.info, h);
    end
end

fig.KeyPressFcn = @(src, evt) mySpectralKeyPress(src, evt, pars, combo.info);
end % mkPlot

function h = mkEpsilonPlot(combo, name, qRHS)
arguments (Input)
    combo struct % binned dissipation information
    name string  % Dissipation column to plot
    qRHS logical = false % Use RHS axis
end % arguments Input
arguments (Output)
    h matlab.graphics.axis.Axes % Output of nexttile
end % arguments Output

h = nexttile();

p = pcolor(combo.info.t0, combo.tbl.bin, log10(combo.tbl.(name)));
p.LineStyle = "None";
axis ij;
grid("on");
xlabel("Time (UTC)");
title(name, "Interpreter", "none");

if qRHS
    set(gca, "YaxisLocation", "right");
end
end % mkEpsilonPlot

function myButtonPress(src, evt, pars, pInfo, h)
ax = src.Parent; % Axis of what was clicked on
t     = num2ruler(evt.IntersectionPoint(1), ax.XAxis); % Time of bin clicked
depth = num2ruler(evt.IntersectionPoint(2), ax.YAxis); % Depth of bin clicked

[~, ix] = min(abs(t - pInfo.t0));
if pInfo.t0(ix) > t, ix = max(ix - 1, 1); end % Time before t

hExtra = cbCommon(pars, pInfo(ix,:), depth, h);

depths = [];
for ax = hExtra'
    for kid = ax.Children'
        if endsWith(class(kid), "Patch"), continue; end
        depths = kid.YData;
        break;
    end
    if ~isempty(depths), break; end
end % for item

fig = src.Parent.Parent.Parent;
fig.UserData = struct( ...
    "t", t, ...
    "iTime", ix, ...
    "depth", depth, ...
    "pars", pars, ...
    "depths", depths, ...
    "pInfo", pInfo, ...
    "h", h);
fig.KeyPressFcn = @mySpectralKeyPress;

figure(fig); % Bring focus back to me
end % myButtonPress

function mySpectralKeyPress(src, evt)
ud = src.UserData;
iTime = ud.iTime;
[~, iDepth] = min(abs(ud.depth - ud.depths));

switch evt.Key
    case "leftarrow"
        iTime = max(iTime - 1, 1);
    case "rightarrow"
        iTime = min(iTime + 1, size(ud.pInfo,1));
    case "uparrow"
        iDepth = max(iDepth - 1, 1);
    case "downarrow"
        iDepth = min(iDepth + 1, length(ud.depths));
end

depth = ud.depths(iDepth);
src.UserData.depth = depth;
src.UserData.iTime = iTime;

cbCommon(ud.pars, ud.pInfo(iTime,:), depth, ud.h);
figure(src); % Bring focus back to me after mkDiagnosticPlots
end % mySpectralButtonPress

function hExtra = cbCommon(pars, row, depth, h)
hExtra = mkDiagnosticPlots(pars, row, depth);
linkaxes(vertcat(h, hExtra), "y"); % Link depths across figures

for ax = hExtra'
    for kid = ax.Children'
        if endsWith(class(kid), "Patch"), continue; end
        kid.ButtonDownFcn = @(src, evt) myDiagButtonPress(src, evt, pars, row);
    end % for kid
end % for ax
end

function myDiagButtonPress(src, evt, pars, pInfo)
ax = src.Parent; % Axis of what was clicked on
depth = num2ruler(evt.IntersectionPoint(2), ax.YAxis); % Depth of bin clicked
mkDiagnosticPlots(pars, pInfo, depth);
end % myDiagButtonPress

function h = mkDiagnosticPlots(pars, pInfo, depth)
arguments (Input)
    pars struct
    pInfo (1,:) table
    depth double
end % arguments (Input)
arguments (Output)
    h (:,1) % Array of axes from nexttile
end % arguments Output

[h0, depthVertices] = mkDissPlots(pars, pInfo, depth);
h1 = mkProfilePlots(pars, pInfo, depthVertices);

h = vertcat(h0, h1);
end % mkDiagnosticPlots

function [h, depthVertices] = mkDissPlots(pars, pInfo, depth)
arguments (Input)
    pars struct
    pInfo (1,:) table
    depth double
end % arguments (Input)
arguments (Output)
    h (:,1) % Array of axes from nexttile
    depthVertices (4,1) double % Vertices of depth rectangle
end % arguments Output

persistent fnDiss df iProfile tiles % Long lived variables so we're not reloading unless needed

fn = fullfile(pars.diss_root, append(pInfo.name, ".mat"));
if ~isequal(fnDiss, fn)
    df = load(fn);
    fnDiss = fn;
end

qRedraw = ~isequal(pInfo.index, iProfile);

iProfile = pInfo.index;
dInfo = df.info(iProfile,:);
profile = df.profiles{iProfile};

[~, iMin] = min(abs(profile.depth - depth));
if profile.depth(iMin) > depth, iMin = max(iMin  - 1, 1); end

depthm1 = profile.depth(max(iMin - 1, 1));
depth0  = profile.depth(iMin);
depthp1 = profile.depth(min(iMin + 1, length(profile.depth)));
depthTop = (depthm1 + depth0) / 2;
depthBot = (depthp1 + depth0) / 2;
depthVertices = [depthTop, depthTop, depthBot, depthBot];

if qRedraw
    figure(pars.figure+1);
    % clf;
    t = tiledlayout(1,6);
    h = cell(prod(t.GridSize),1);

    h{1} = nexttile();
    plot(log10(profile.e), profile.depth, ".-", ...
        log10(profile.epsilonMean), profile.depth, "o-");
    axis ij;
    grid on;
    ylabel ("Depth (m)");
    xlabel("log_{10}(\epsilon) (W kg^{-1})");
    axis tight;
    drawDepthBar(depthVertices); % After axis tight

    items = [ ...
        "FM", "FM", "."; ...
        "method", "Method", "-"; ...
        "speed", "Speed (m/s)", "-"; ...
        "nu", "\nu (m^2/s)", "-"; ...
        "T", "T (C)", "-"; ...
        ];

    for i = 1:size(items,1)
        item = items(i,:);
        h{i+1} = nexttile();
        plot(profile.(item(1)), profile.depth, item(3));
        axis ij;
        grid on;
        xlabel(item(2));
        axis tight;
        drawDepthBar(depthVertices); % After axis tight
    end

    sgtitle(sprintf("%s profile %d, %s to %s", pInfo.name, iProfile, dInfo.t0, dInfo.t1), ...
        "Interpreter", "none");

    h = vertcat(h{:});
    tiles = h;
else
    h = tiles;
    for ax = h'
        for kid = ax.Children'
            if ~endsWith(class(kid), "Patch"), continue; end
            kid.YData = depthVertices;
            break;
        end
    end % for ax
end % if qRedraw

mkSpectralPlot(pars, profile(iMin,:), dInfo);
end % mkDissPlots

function drawDepthBar(depthVertices)
arguments (Input)
    depthVertices(4,1) double
end % arguments (Input)

lhs = min(xlim);
rhs = max(xlim);

alpha = 0.25;

hold on;
fill([lhs, rhs, rhs, lhs], depthVertices, ...
    [0, 0, 0], ...
    "FaceAlpha", alpha, ...
    "EdgeAlpha", alpha);
hold off;
end % drawDepthBar

function mkSpectralPlot(pars, row, pInfo)
arguments (Input)
    pars struct
    row (1,:) table
    pInfo (1,:) table
end % arguments Input

K = row.K;
shClean = squeeze(row.sh_clean);
shDirty = squeeze(row.sh);
Nasmyth_spec = squeeze(row.Nasmyth_spec);
epsilon = row.e;
Kmax = row.K_max;

figure(pars.figure+2);
% clf;
colors = get(gca, "ColorOrder");

tits = strings(4, numel(Kmax));
nasymthMin = nan;
for i = 1:numel(Kmax)
    tits(1, i) = sprintf("\\Delta u_%d clean", i);
    tits(2, i) = sprintf("\\Delta u_%d", i);
    tits(3, i) = sprintf("\\epsilon_%d = %.2g W kg^-1", i, epsilon(i));
    tits(4, i) = sprintf("K_{max} U_%d=%.0fcpm", i, Kmax(i));

    col = colors(i,:);
    semilogx(K, log10(squeeze(shClean(i,i,:))), "-", "Color", col, "LineWidth", 2);
    hold on;
    semilogx(K, log10(squeeze(shDirty(i,i,:))), "-", "Color", col);

    nasymth = log10(squeeze(Nasmyth_spec(i, :)));
    nasymthMin = min(nasymthMin, nasymth(end));
    semilogx(K, nasymth, "-", "Color", col);

    shMax = interp1(K, squeeze(shClean(i,i,:)), Kmax(i), "linear", "extrap");
    semilogx(Kmax(i), log10(shMax), "v", "MarkerFaceColor", col, "MarkerSize", 10);
end

hold off;
axis tight;
ylim([nasymthMin, max(-1, max(ylim))]);
legend(tits, "Location", "best")
grid on;
ylabel("\Phi(k) (s^{-2} cpm^{-1})");
xlabel("k (cpm)");

title([ ...
    sprintf("%s %s profile %d", texstr(pInfo.name), pInfo.t0, pInfo.index), ...
    sprintf("Depth=%.1f m FM=[%s] method=[%s] $$log_{10}(\\epsilon) = %.2f\\pm%.2f$$", ...
    row.depth, ...
    num2str(row.FM, 2), ...
    num2str(row.method), ...
    log10(row.epsilonMean), ...
    log10(exp(row.epsilonLnSigma))) ...
    ], ...
    "interpreter", "latex");
end % mkSpectralPlot

function h = mkProfilePlots(pars, dInfo, depthVertices)
arguments (Input)
    pars struct
    dInfo (1,:) table
    depthVertices (4,1) double
end
arguments (Output)
    h (:,1) % Array of axis from next tile
end

persistent fnProf df iProfile tiles

fn = fullfile(pars.profile_root, append(dInfo.name, ".mat"));

if ~isequal(fnProf, fn)
    df = load(fn);
    fnProf = fn;
end

qRedraw = ~isequal(iProfile, dInfo.index);

iProfile = dInfo.index;
pInfo = df.pInfo(iProfile,:);

if qRedraw
    profile = df.profiles{iProfile};
    slow = profile.slow;
    fast = profile.fast;

    qFast = true(size(fast, 1), 1);
    qSlow = true(size(slow, 1), 1);

    pNames = string(pInfo.Properties.VariableNames);
    if ismember("trim_depth", pNames)
        qFast = fast.depth >= pInfo.trim_depth;
        qSlow = slow.depth >= pInfo.trim_depth;
    end % if ismember

    if ismember("bottom_depth", pNames)
        qFast = qFast & fast.depth <= pInfo.bottom_depth;
        qSlow = qSlow & slow.depth <= pInfo.bottom_depth;
    end

    figure(pars.figure+3);
    t = tiledlayout(1,6);
    h = cell(prod(t.GridSize), 1);

    h{1} = nexttile();
    plot(slow.JAC_T, slow.depth, "-", ...
        fast.T1_fast, fast.depth, "-", ...
        fast.T2_fast, fast.depth, "-", ...
        slow.JAC_T(qSlow), slow.depth(qSlow), "-", ...
        fast.T1_fast(qFast), fast.depth(qFast), "-", ...
        fast.T2_fast(qFast), fast.depth(qFast), "-");
    axis ij;
    grid on;
    ylabel("Depth (m)");
    xlabel ("T (C)");
    axis tight;
    drawDepthBar(depthVertices); % After axis tight

    h{2} = nexttile();
    dT1 = interp1(fast.t_fast, fast.T1_fast, slow.t_slow, "linear", "extrap") - slow.JAC_T;
    dT2 = interp1(fast.t_fast, fast.T2_fast, slow.t_slow, "linear", "extrap") - slow.JAC_T;

    plot(dT1, slow.depth, "-", ...
        dT2, slow.depth, "-", ...
        dT1(qSlow), slow.depth(qSlow), "-", ...
        dT2(qSlow), slow.depth(qSlow), "-");
    axis ij;
    grid on;
    xlabel ("\delta T (C)");
    axis tight;
    drawDepthBar(depthVertices); % After axis tight

    h{3} = nexttile();
    plot(slow.JAC_C, slow.depth, "-", slow.JAC_C(qSlow), slow.depth(qSlow), "-");
    axis ij;
    grid on;
    xlabel("Cond");
    axis tight;
    drawDepthBar(depthVertices); % After axis tight

    h{4} = nexttile();
    plot(slow.Incl_X, slow.depth, "-", ...
        slow.Incl_Y, slow.depth, "-", ...
        slow.Incl_X(qSlow), slow.depth(qSlow), "-", ...
        slow.Incl_Y(qSlow), slow.depth(qSlow), "-");
    axis ij;
    grid on;
    xlabel("Incl");
    axis tight;
    drawDepthBar(depthVertices); % After axis tight

    h{5} = nexttile();
    plot(fast.Ax, fast.depth, "-", ...
        fast.Ay, fast.depth, "-", ...
        fast.Ax(qFast), fast.depth(qFast), "-", ...
        fast.Ay(qFast), fast.depth(qFast), "-");
    axis ij;
    grid on;
    xlabel("Ax/Ay");
    axis tight;
    drawDepthBar(depthVertices); % After axis tight

    h{6} = nexttile();
    plot(fast.sh1, fast.depth, "-", ...
        fast.sh2, fast.depth, "-", ...
        fast.sh1(qFast), fast.depth(qFast), "-", ...
        fast.sh2(qFast), fast.depth(qFast), "-");
    axis ij;
    grid on;
    xlabel("sh1/sh2");
    axis tight;
    drawDepthBar(depthVertices); % After axis tight


    sgtitle(sprintf("%s profile %d, %s to %s", pInfo.name, pInfo.index, pInfo.t0, pInfo.t1), ...
        "Interpreter", "none");

    h = vertcat(h{:});
    tiles = h;
else % if qRedraw
    h = tiles;
    for ax = tiles'
        for kid = ax.Children'
            if ~endsWith(class(kid), "Patch"), continue; end
            kid.YData = depthVertices;
            break;
        end
    end
end % if qRedraw
end % mkProfilePlots