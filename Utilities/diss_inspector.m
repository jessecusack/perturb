% 
% Plot a dissipation combo.mat file and present diagnostics
% plots based on where the user clicks on the pcolor plot of the dissipation.
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function [hLink, el] = diss_inspector(varargin)
arguments (Repeating)
    varargin % key/val arguments
end % arguments Repeating

pars = parse_arguments(varargin{:});
hLink = mkPlot(pars);
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

function hLink = mkPlot(pars)
arguments (Input)
    pars struct % paths to where output of process_P_files is stored
end % arguments Input

combo = load(fullfile(pars.diss_combo_root, "combo.mat"));

figure(pars.figure);
clf;
t = tiledlayout(1, 3, "TileSpacing", "tight", "Padding", "tight");
h = cell(prod(t.GridSize),1);
h{1} = mkEpsilonPlot(pars, combo, "epsilonMean");
ylabel("Depth (meters)");
h{2} = mkEpsilonPlot(pars, combo, "e_1");
h{3} = mkEpsilonPlot(pars, combo, "e_2", true);
cb = colorbar("EastOutside");
cb.Label.String = "log_{10}(\epsilon) (W kg^-1)";
sgtitle(pars.diss_combo_root, "Interpreter", "none");

h = vertcat(h{:});

hLink = linkprop(h, ["CLim", "XLim", "YLim"]);

for i = 2:(numel(h) - 1)
    h(i).YAxis(1).Visible = "off";
end % for i

if ~isempty(pars.xLim), xlim(pars.xLim); end
if ~isempty(pars.yLim), ylim(pars.yLim); end
if ~isempty(pars.cLim)
    clim(pars.cLim);
else
    clim(quantile(log10(combo.tbl.epsilonMean(:)), [0.05, 0.95]));
end
end % mkPlot

function h = mkEpsilonPlot(pars, combo, name, qRHS)
arguments (Input)
    pars struct
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
p.ButtonDownFcn = {@myOnMouse, pars, combo.info};
axis ij;
grid("on");
xlabel("Time (UTC)");
title(name, "Interpreter", "none");

if qRHS
    set(gca, "YaxisLocation", "right");
end
end % mkPlot

function myOnMouse(src, evt, pars, pInfo)
pt = evt.IntersectionPoint;
parent = src.Parent;
tPoint = num2ruler(pt(1), parent.XAxis);
yPoint = num2ruler(pt(2), parent.YAxis);

ix = interp1(pInfo.t0, 1:size(pInfo,1), tPoint, "previous", "extrap");
if isnan(ix), return; end % Before first point
mkDiagnosticPlots(pars, pInfo(ix,:), yPoint);
end

function myOnSpectral(src, evt, pInfo, profile, fig1, fig2)
pt = evt.IntersectionPoint;
parent = src.Parent;
yPoint = num2ruler(pt(2), parent.YAxis);

qDepth = interp1(profile.depth, 1:size(profile,1), yPoint, "previous", "extrap");
row = profile(qDepth,:);
mkSpectralPlot(fig2, row, pInfo);

children = get(get(fig1, "Children"), "Children"); % Children of the tiledlayout
for i = 1:length(children)
    child = children(i).Children;
    iMarker = nan(length(child), 1);
    x = nan(length(child), 1);
    for j = 1:length(child)
        kid = child(j);
        if numel(kid.XData) == 1
            iMarker(j) = j;
            kid.YData = yPoint;
        else
            [~, ix] = unique(kid.YData);
            x(j) = interp1(kid.YData(ix), kid.XData(ix), yPoint, "linear", "extrap");
        end
    end % for j
    iMarker = iMarker(~isnan(iMarker));
    x = x(~isnan(x));
    if numel(iMarker) == numel(x)
        for j = 1:numel(iMarker)
            child(iMarker(j)).XData = x(j);
        end
    end
end % for i
end % myOnSpectral

function mkDiagnosticPlots(pars, pInfo, yPoint)
arguments (Input)
    pars struct
    pInfo (1,:) table
    yPoint double
end % arguments (Input)

iProfile = pInfo.index;

fnDiss = fullfile(pars.diss_root, append(pInfo.name, ".mat"));
fnProf = fullfile(pars.profile_root, append(pInfo.name, ".mat"));

f3 = mkProfilePlots(fnProf, iProfile, pars.figure+3);

a = load(fnDiss);
dInfo = a.info(iProfile,:);
profile = a.profiles{iProfile};

qDepth = interp1(profile.depth, 1:size(profile,1), yPoint, "previous", "extrap");
row = profile(qDepth,:);

figBase = pars.figure;

f1 = figure(figBase+1);
clf;
t = tiledlayout(1,6);
h = cell(prod(t.GridSize),1);

h{1} = nexttile();
plot(log10(profile.e), profile.depth, ".-", ...
    log10(profile.epsilonMean), profile.depth, "o-", ...
    "ButtonDownFcn", {@myOnSpectral, dInfo, profile, f1, figBase+2});
hold on;
plot(log10(row.e), row.depth, "*k", ...
    log10(row.epsilonMean), row.depth, "pk", ...
    "MarkerSize", 10);
hold off;
axis ij;
grid on;
ylabel ("Depth (m)");
xlabel("log_{10}(\epsilon) (W kg^{-1})");
axis tight;

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
    plot(profile.(item(1)), profile.depth, item(3), ...
        "ButtonDownFcn", {@myOnSpectral, dInfo, profile, f1, figBase+2});
    hold on;
    plot(row.(item(1)), row.depth, "*k", "MarkerSize", 10);
    hold off;
    axis ij;
    grid on;
    xlabel(item(2));
    axis tight;
end

sgtitle(sprintf("%s profile %d, %s to %s", pInfo.name, iProfile, dInfo.t0, dInfo.t1), ...
    "Interpreter", "none");

linkaxes(vertcat(h{:}), "y");

mkSpectralPlot(figBase+2, row, dInfo);
end % mkDiagnosticPlots

function mkSpectralPlot(fig, row, pInfo)
arguments (Input)
    fig double
    row table
    pInfo (1,:) table
end % arguments Input

K = row.K;
shClean = squeeze(row.sh_clean);
shDirty = squeeze(row.sh);
Nasmyth_spec = squeeze(row.Nasmyth_spec);
epsilon = row.e;
Kmax = row.K_max;

figure(fig);
clf;
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
end % mkDiagnosticPlots

function f = mkProfilePlots(fn, iProfile, fig)
a = load(fn);
pInfo = a.pInfo(iProfile,:);

profile = a.profiles{iProfile};
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

f = figure(fig);
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

h{3} = nexttile();
plot(slow.JAC_C, slow.depth, "-", slow.JAC_C(qSlow), slow.depth(qSlow), "-");
axis ij;
grid on;
xlabel("Cond");
axis tight;

h{4} = nexttile();
plot(slow.Incl_X, slow.depth, "-", ...
    slow.Incl_Y, slow.depth, "-", ...
    slow.Incl_X(qSlow), slow.depth(qSlow), "-", ...
    slow.Incl_Y(qSlow), slow.depth(qSlow), "-");
axis ij;
grid on;
xlabel("Incl");
axis tight;

h{5} = nexttile();
plot(fast.Ax, fast.depth, "-", ...
    fast.Ay, fast.depth, "-", ...
    fast.Ax(qFast), fast.depth(qFast), "-", ...
    fast.Ay(qFast), fast.depth(qFast), "-");
axis ij;
grid on;
xlabel("Ax/Ay");
axis tight;

h{6} = nexttile();
plot(fast.sh1, fast.depth, "-", ...
    fast.sh2, fast.depth, "-", ...
    fast.sh1(qFast), fast.depth(qFast), "-", ...
    fast.sh2(qFast), fast.depth(qFast), "-");
axis ij;
grid on;
xlabel("sh1/sh2");
axis tight;

sgtitle(sprintf("%s profile %d, %s to %s", pInfo.name, pInfo.index, pInfo.t0, pInfo.t1), ...
    "Interpreter", "none");

linkaxes(vertcat(h{:}), "y");

head(slow)
head(fast)
end % mkProfilePlots