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
addParameter(p, "diss_combo_root", [], @isfolder);
addParameter(p, "diss_root", [], @isfolder);
addParameter(p, "profile_root", [], @isfolder);
addParameter(p, "dtMax", minutes(10), @isduration); % Maximum time between casts to consider consecutive
addParameter(p, "CT_T_name", [], @isstring);
addParameter(p, "CT_C_name", [], @isstring);

parse(p, varargin{:});
a = p.Results(1);

pars = a.pars;

for name = setdiff(string(fieldnames(a))', "pars")
    if ismember(name, p.UsingDefaults) && ~ismember(name, ["figure", "dtMax"]), continue; end
    pars.(name) = a.(name);
end % for name

required = ["diss_combo_root", "diss_root", "profile_root", "CT_T_name", "CT_C_name"];
q = ismember(required, fieldnames(pars));
if all(q), return; end

if sum(~q) == 1
    error("%s is required to be specified", required(~q));
else
    error("%s are required to be specified", strjoin(required(~q), ", "));
end % if sum
end % parse_arguments

function mkPlot(pars)
arguments (Input)
    pars struct % paths to where output of process_P_files is stored
end % arguments Input

combo = load(fullfile(pars.diss_combo_root, "combo.mat")); % Combined and binned dissipation estimates

ud = struct();
ud.pInfo = combo.info;
ud.tbl = combo.tbl;
ud.pars = pars;
ud.tMid = combo.info.t0 + (combo.info.t1 - combo.info.t0) / 2; % Mid point of time bin

fig = figure(pars.figure);

t = tiledlayout(1, 3, "TileSpacing", "tight", "Padding", "tight");
gInfo = cell(prod(t.GridSize), 1);

gInfo{1} = mkEpsilonPlot(combo, "epsilonMean", pars.dtMax);
ylabel("Depth (meters)");
gInfo{2} = mkEpsilonPlot(combo, "e_1", pars.dtMax);
gInfo{3} = mkEpsilonPlot(combo, "e_2", pars.dtMax, true);

gInfo = vertcat(gInfo{:});

ud.gInfo = gInfo;

cb = colorbar("EastOutside");
cb.Label.String = "log_{10}(\epsilon) (W kg^-1)";
sgtitle(pars.diss_combo_root, "Interpreter", "none");

linkaxes(gInfo.tile, "y"); % We'll use y linkage on many plots so split out from linkprop
ud.hLink = linkprop(gInfo.tile, ["CLim", "XLim"]); % hLink needs to be persistent

if isfield(pars, "xLim") && ~isempty(pars.xLim), xlim(pars.xLim); end
if isfield(pars, "yLim") && ~isempty(pars.yLim), ylim(pars.yLim); end
if isfield(pars, "cLim") && ~isempty(pars.cLim)
    clim(pars.cLim);
else
    clim(quantile(log10(combo.tbl.epsilonMean(:)), [0.01, 0.99]));
end

fig.UserData = ud; % Before assignment of callbacks

set(gInfo.tile(2:end-1).YAxis, "Visible", "off");
set(gInfo.pcolor, "ButtonDownFcn", @myButtonPress);
set(fig, "KeyPressFcn", @myKeyPress)
end % mkPlot

function gInfo = mkEpsilonPlot(combo, name, dtMax, qRHS)
arguments (Input)
    combo struct % binned dissipation information
    name string  % Dissipation column to plot
    dtMax duration % Maximum time between casts to consider together
    qRHS logical = false % Use RHS axis
end % arguments Input
arguments (Output)
    gInfo (1,4) table; % Graphics objects
end % arguments Output

gInfo = table();
gInfo.tile = nexttile();
gInfo.pcolor = osgl_vmp_plot(combo.info.t0, combo.info.t1, combo.tbl.bin, log10(combo.tbl.(name)), dtMax);

hold on;
p = plot(...
    [combo.info.t0(1), combo.info.t0(1)], [combo.tbl.bin(1), combo.tbl.bin(end)], "-k", ...
    [combo.info.t0(1), combo.info.t1(end)], [combo.tbl.bin(1), combo.tbl.bin(1)], "-k", ...
    "visible", "off");
gInfo.xHair = p(1);
gInfo.yHair = p(2);
hold off;
xlabel("Time (UTC)");
title(name, "Interpreter", "none");

if qRHS
    set(gca, "YaxisLocation", "right");
end
end % mkEpsilonPlot

function myButtonPress(src, evt)
arguments (Input)
    src         % Source object of callback, surface
    evt         % Callback hit event
end

ax = src.Parent; % Axis of pcolor plot
fig = ax.Parent.Parent; % Figure holding all the panels
ud = fig.UserData; % Data from figure's UserData

pt = evt.IntersectionPoint; % where button was pressed
tPt = num2ruler(pt(1), ax.XAxis); % datetime of point clicked
yPt = num2ruler(pt(2), ax.YAxis); % depth of point clicked

[~, ud.iProfile] = min(abs(ud.tMid - tPt));
[~, ud.iDepth] = min(abs(ud.tbl.bin - yPt));
ud.tPt = ud.tMid(ud.iProfile);
ud.yPt = ud.tbl.bin(ud.iDepth);

adjustCrosshair(ud);

dInfo = mkDissPlots(ud);
ud.depthVertices = dInfo.depthVertices;
pInfo = mkProfilePlots(ud, yPt + ud.depthVertices);

ud.dBars = dInfo.tbl.depthBar;
ud.pBars = pInfo.tbl.depthBar;

adjustDepthBar(ud.yPt, ud.depthVertices, ud.dBars, ud.pBars);

for name = ["iProfile", "iDepth", "tPt", "yPt", "depthVertices", "dBars", "pBars"] % Only what was updated for speed
    fig.UserData.(name) = ud.(name);
end

figure(fig); % Bring focus back to me
end % myButtonPress

function myKeyPress(src, evt)
arguments (Input)
    src         % Source object of callback, surface
    evt         % Callback hit event
end % arguments Input

ud = src.UserData; % UserData from the figure

if ~isfield(ud, "iProfile"), return; end % Not initialized yet

iProfile = ud.iProfile;
iDepth = ud.iDepth;

switch evt.Key
    case "leftarrow"
        iProfile = max(iProfile - 1, 1);
    case "rightarrow"
        iProfile = min(iProfile + 1, numel(ud.tMid));
    case "uparrow"
        iDepth = max(iDepth - 1, 1);
    case "downarrow"
        iDepth = min(iDepth + 1, size(ud.tbl,1));
end

ud.tPt = ud.tMid(iProfile);
ud.yPt = ud.tbl.bin(iDepth);

ud.iProfile = iProfile;
ud.iDepth = iDepth;

dInfo = mkDissPlots(ud);
ud.depthVertices = dInfo.depthVertices;
pInfo = mkProfilePlots(ud, ud.yPt + ud.depthVertices);

ud.dBars = dInfo.tbl.depthBar;
ud.pBars = pInfo.tbl.depthBar;

adjustCrosshair(ud);
adjustDepthBar(ud.yPt, ud.depthVertices, ud.dBars, ud.pBars);

for name = ["iProfile", "iDepth", "tPt", "yPt", "depthVertices", "dBars", "pBars"] % Only updated fields to save time
    src.UserData.(name) = ud.(name);
end

figure(src); % Bring focus back to me
end % myKeyPress

function adjustCrosshair(ud)
arguments (Input)
    ud struct % UserData from fig with updated yPt and tPt
end % arguments Input

set(ud.gInfo.xHair, "XData", [ud.tPt, ud.tPt], "Visible", "on");
set(ud.gInfo.yHair, "YData", [ud.yPt, ud.yPt], "Visible", "on");
end % adjustCrosshair

function adjustDepthBar(depth0, depthVertices, dBars, pBars)
arguments (Input)
    depth0 double
    depthVertices (4,1) double
    dBars (:,1)
    pBars (:,1)
end % arguments Input

vertices = depth0 + depthVertices;

for item = dBars'
    if isgraphics(item) && ~isequal(item.Vertices(:,2), vertices)
        item.Vertices(:,2) = vertices;
    end
end % for

for item = pBars'
    if isgraphics(item) && ~isequal(item.Vertices(:,2), vertices)
        item.Vertices(:,2) = vertices;
    end
end % for
end

function myDiagButtonPress(src, evt)
arguments (Input)
    src % Source object clicked on
    evt % Event
end

if ~isequal(get(src, "type"), "axes")
    src = src.Parent;
end

myUD = src.Parent.Parent.UserData;
fig = figure(myUD.figMaster);
ud = fig.UserData; % Master figure's UserData

yPt = num2ruler(evt.IntersectionPoint(2), src.YAxis); % depth of point clicked

[~, ud.iDepth] = min(abs(ud.tbl.bin - yPt));
ud.yPt = ud.tbl.bin(ud.iDepth);

mkDissPlots(ud);

adjustCrosshair(ud);
adjustDepthBar(ud.yPt, ud.depthVertices, ud.dBars, ud.pBars);

for name = ["iDepth", "yPt"] % Only updated fields to save time
    fig.UserData.(name) = ud.(name);
end
end % myDiagButtonPress

function myDiagKeyPress(src, evt)
arguments (Input)
    src         % Source object of callback, surface
    evt         % Callback hit event
end % arguments Input

fig = figure(src.UserData.figMaster);
ud = fig.UserData; % Master figure's UserData

iDepth = ud.iDepth;

switch evt.Key
    case "uparrow"
        iDepth = max(iDepth - 1, 1);
    case "downarrow"
        iDepth = min(iDepth + 1, size(ud.tbl,1));
end

ud.yPt = ud.tbl.bin(iDepth);
ud.iDepth = iDepth;

dInfo = mkDissPlots(ud);

adjustCrosshair(ud);
adjustDepthBar(ud.yPt, ud.depthVertices, ud.dBars, ud.pBars);

for name = ["iDepth", "yPt"] % Only updated fields to save time
    fig.UserData.(name) = ud.(name);
end
figure(src); % Bring focus back to me
end % myDiagKeyPress

function gInfo = mkDissPlots(ud)
arguments (Input)
    ud struct % UserData from main figure
end % arguments (Input)
arguments (Output)
    gInfo struct % Information for dissipation related plots
end % arguments Output

fig = figure(ud.pars.figure + 1); % Dissipation plots figure

if isstruct(fig.UserData)
    gInfo = fig.UserData;
else
    gInfo = struct();
end

qProfile = isfield(gInfo, "iProfile") && isequal(gInfo.iProfile, ud.iProfile);
qDepth = isfield(gInfo, "iDepth") && isequal(gInfo.iDepth, ud.iDepth);

if qProfile && qDepth, return; end % Nothing changed

row = ud.pInfo(ud.iProfile,:);

if ~isfield(gInfo, "name") || ~isequal(gInfo.name, row.name)
    fn = fullfile(ud.pars.diss_root, append(row.name, ".mat"));
    gInfo.data = load(fn);
    gInfo.name = row.name;
    fprintf("Loaded %s\n", fn);
end

gInfo.iProfile = ud.iProfile;
gInfo.iDepth = ud.iDepth;
gInfo.figMaster = ud.pars.figure;

pInfo = gInfo.data.info(row.index,:);
profile = gInfo.data.profiles{row.index};

depth0 = ud.tbl.bin(ud.iDepth);
[~, iProfileMin] = min(abs(profile.depth - depth0));
halfWidth = 0.5 * pInfo.diss_length * profile.speed(iProfileMin) / pInfo.fs_fast;
gInfo.depthVertices = halfWidth * [-1, -1, 1, 1];

if qProfile % Profile didn't change, only the depth, no need to redraw profile figures
    mkSpectralPlot(ud, gInfo, row, profile(iProfileMin,:));
    return;
end

figure(fig);
t = tiledlayout(1,6);
tbl = table();
tbl.tile = gobjects(prod(t.GridSize), 1);
tbl.depthBar = gobjects(size(tbl,1), 1);

tbl.tile(1) = nexttile();
plot(log10(profile.e), profile.depth, ".-", ...
    log10(profile.epsilonMean), profile.depth, "o-", ...
    "ButtonDownFcn", @myDiagButtonPress);
axis ij;
grid on;
ylabel ("Depth (m)");
xlabel("log_{10}(\epsilon) (W kg^{-1})");
axis tight;
tbl.depthBar(1) = drawDepthBar(depth0 + gInfo.depthVertices); % After axis tight

items = [ ...
    "FM", "FM", "."; ...
    "method", "Method", "-"; ...
    "speed", "Speed (m/s)", "-"; ...
    "nu", "\nu (m^2/s)", "-"; ...
    "T", "T (C)", "-"; ...
    ];

for i = 1:size(items,1)
    item = items(i,:);
    tbl.tile(i+1) = nexttile();
    plot(profile.(item(1)), profile.depth, item(3), ...
        "ButtonDownFcn", @myDiagButtonPress);
    axis ij;
    grid on;
    xlabel(item(2));
    axis tight;
    tbl.depthBar(i+1) = drawDepthBar(depth0 + gInfo.depthVertices); % After axis tight
end

sgtitle(sprintf("%s profile %d, %s to %s", gInfo.name, row.index, row.t0, row.t1), ...
    "Interpreter", "none");

gInfo.tbl = tbl;
set(fig, "UserData", gInfo);

mkSpectralPlot(ud, gInfo, row, profile(iProfileMin,:));

set(tbl.tile, "ButtonDownFcn", @myDiagButtonPress);
set(fig, "KeyPressFcn", @myDiagKeyPress)
end % mkDissPlots

function h = drawDepthBar(depthVertices)
arguments (Input)
    depthVertices(4,1) double
end % arguments Input
arguments (Output)
    h % Output of fill
end % arguments Output

lhs = min(xlim);
rhs = max(xlim);

alpha = 0.25;

hold on;
h = fill([lhs, rhs, rhs, lhs], depthVertices, ...
    [0, 0, 0], ...
    "FaceAlpha", alpha, ...
    "EdgeAlpha", alpha);
hold off;
end % drawDepthBar

function mkSpectralPlot(ud, gInfo, pInfo, row)
arguments (Input)
    ud struct % Main figure UserData
    gInfo struct % Dissipation info
    pInfo (1,:) table % Profile information
    row (1,:) table % pInfo to plot data for
end % arguments Input

K = row.K;
shClean = squeeze(row.sh_clean);
shDirty = squeeze(row.sh);
Nasmyth_spec = squeeze(row.Nasmyth_spec);
epsilon = row.e;
Kmax = row.K_max;

figure(ud.pars.figure+2);
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
    sprintf("%s %s profile %d", texstr(gInfo.name), pInfo.t0, pInfo.index), ...
    sprintf("Depth=%.1f m FM=[%s] method=[%s] $$log_{10}(\\epsilon) = %.2f\\pm%.2f$$", ...
    row.depth, ...
    num2str(row.FM, 2), ...
    num2str(row.method), ...
    log10(row.epsilonMean), ...
    log10(exp(row.epsilonLnSigma))) ...
    ], ...
    "interpreter", "latex");
end % mkSpectralPlot

function gInfo = mkProfilePlots(ud, depthVertices)
arguments (Input)
    ud struct % Userdata from main figure
    depthVertices (4,1) double % Corners of depth box
end
arguments (Output)
    gInfo struct % struct of graphics objects
end

fig = figure(ud.pars.figure+3);

if isstruct(fig.UserData)
    gInfo = fig.UserData;
else
    gInfo = struct();
end

if isfield(gInfo, "iProfile") && isequal(gInfo.iProfile, ud.iProfile)
    return;
end % No need to do anything

row = ud.pInfo(ud.iProfile,:);
gInfo.iProfile = ud.iProfile;
gInfo.figMaster = ud.pars.figure;

if ~isfield(gInfo, "name") || ~isequal(gInfo.name, row.name) % We need to load new data
    fn = fullfile(ud.pars.profile_root, append(row.name, ".mat"));
    gInfo.data = load(fn);
end

pInfo = gInfo.data.pInfo(row.index,:);
profile = gInfo.data.profiles{row.index};
slow = profile.slow;
fast = profile.fast;

qFast = true(size(fast, 1), 1);
qSlow = true(size(slow, 1), 1);

pNames = string(pInfo.Properties.VariableNames);

if ismember("trim_depth", pNames)
    qFast = fast.depth >= pInfo.trim_depth;
    qSlow = slow.depth >= pInfo.trim_depth;
end % trim_depth

if ismember("bottom_depth", pNames)
    qFast = qFast & fast.depth <= pInfo.bottom_depth;
    qSlow = qSlow & slow.depth <= pInfo.bottom_depth;
end % bottom_depth

T_name = ud.pars.CT_T_name;
C_name = ud.pars.CT_C_name;

figure(fig);
t = tiledlayout(1,6);
tbl = table();
tbl.tile = gobjects(prod(t.GridSize), 1);
tbl.depthBar = gobjects(size(tbl,1), 1);

tbl.tile(1) = nexttile();
plot(slow.(T_name), slow.depth, "-", ...
        fast.T1_fast, fast.depth, "-", ...
        fast.T2_fast, fast.depth, "-", ...
        slow.(T_name)(qSlow), slow.depth(qSlow), "-", ...
        fast.T1_fast(qFast), fast.depth(qFast), "-", ...
        fast.T2_fast(qFast), fast.depth(qFast), "-", ...
    "ButtonDownFcn", @myDiagButtonPress);
axis ij;
grid on;
ylabel("Depth (m)");
xlabel("T (C)");
axis tight;
tbl.depthBar(1) = drawDepthBar(depthVertices);

tbl.tile(2) = nexttile();
dT1 = interp1(fast.t_fast, fast.T1_fast, slow.t_slow, "linear", "extrap") - slow.(T_name);
dT2 = interp1(fast.t_fast, fast.T2_fast, slow.t_slow, "linear", "extrap") - slow.(T_name);

plot(dT1, slow.depth, "-", ...
    dT2, slow.depth, "-", ...
    dT1(qSlow), slow.depth(qSlow), "-", ...
    dT2(qSlow), slow.depth(qSlow), "-", ...
    "ButtonDownFcn", @myDiagButtonPress);
axis ij;
grid on;
xlabel ("\delta T (C)");
axis tight;
tbl.depthBar(2) = drawDepthBar(depthVertices); % After axis tight

tbl.tile(3) = nexttile();
plot(slow.(C_name), slow.depth, "-", ...
    slow.(C_name)(qSlow), slow.depth(qSlow), "-", ...
    "ButtonDownFcn", @myDiagButtonPress);
axis ij;
grid on;
xlabel("Cond");
axis tight;
tbl.depthBar(3) = drawDepthBar(depthVertices); % After axis tight

tbl.tile(4) = nexttile();
plot(slow.Incl_X, slow.depth, "-", ...
    slow.Incl_Y, slow.depth, "-", ...
    slow.Incl_X(qSlow), slow.depth(qSlow), "-", ...
    slow.Incl_Y(qSlow), slow.depth(qSlow), "-", ...
    "ButtonDownFcn", @myDiagButtonPress);
axis ij;
grid on;
xlabel("Incl");
axis tight;
tbl.depthBar(4) = drawDepthBar(depthVertices); % After axis tight

tbl.tile(5) = nexttile();
plot(fast.Ax, fast.depth, "-", ...
    fast.Ay, fast.depth, "-", ...
    fast.Ax(qFast), fast.depth(qFast), "-", ...
    fast.Ay(qFast), fast.depth(qFast), "-", ...
    "ButtonDownFcn", @myDiagButtonPress);
axis ij;
grid on;
xlabel("Ax/Ay");
axis tight;
tbl.depthBar(5) = drawDepthBar(depthVertices); % After axis tight

tbl.tile(6) = nexttile();
plot(fast.sh1, fast.depth, "-", ...
    fast.sh2, fast.depth, "-", ...
    fast.sh1(qFast), fast.depth(qFast), "-", ...
    fast.sh2(qFast), fast.depth(qFast), "-", ...
    "ButtonDownFcn", @myDiagButtonPress);
axis ij;
grid on;
xlabel("sh1/sh2");
axis tight;
tbl.depthBar(6) = drawDepthBar(depthVertices); % After axis tight

sgtitle(sprintf("%s profile %d, %s to %s", pInfo.name, pInfo.index, pInfo.t0, pInfo.t1), ...
    "Interpreter", "none");

set(tbl.tile, "ButtonDownFcn", @myDiagButtonPress);
set(fig, "KeyPressFcn", @myDiagKeyPress)
gInfo.tbl = tbl;
set(fig, "UserData", gInfo);
end % mkProfilePlots

%% This is a rewritten version of William's texstr code from ODAS

function result = texstr(input, escChars)
arguments (Input)
    input string {mustBeNonempty}
    escChars string = "_\"
end % arguments Input
arguments (Output)
    result string
end % arguments Output

pattern = append("[", strrep(escChars, "\", "\\"), "]");
result = regexprep(input, pattern, "\\$0");
end % texstr