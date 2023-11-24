% Diagnostic plots for dissipation estimates from profiles
%
% The first argument is a profile mat filename
% Optional arguments are:
%  profiles a vector of profiles to plot, if not specified, all profiles are ploted
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function a = diss_diagnostic_plots(varargin)
p = inputParser();
addRequired(p, "fn", @isfile);
addParameter(p, "profiles", [], @(x) ~isempty(x));
parse(p, varargin{:});

pars = p.Results;
fn = pars.fn;
profiles = pars.profiles;

a = load(fn);

if isempty(profiles)
    profiles = 1:numel(a.profiles);
end % if isempty

pInfo = a.info;

depthLimits = [ ...
    min(cellfun(@(x) min(x.depth, [], "omitnan"), a.profiles)), ...
    max(cellfun(@(x) max(x.depth, [], "omitnan"), a.profiles)) ...
    ];

for i = profiles
    row = pInfo(i,:);
    profile = a.profiles{i};
    head(profile)
    clf;
    t = tiledlayout(1, 2);
    h = cell(prod(t.GridSize), 1);
    h{1} = nexttile();
    plot(log10(profile.e), profile.depth, ".-", ...
        log10(profile.epsilonMean), profile.depth, "o-");
    axis ij;
    grid on;
    xlabel("log_{10}(\epsilon) (W/kg)");
    ylabel("Depth (m)");
    ylim(depthLimits);

    h{2} = nexttile();
    plot(profile.FM, profile.depth, ".-");
    axis ij;
    grid on;
    xlabel("Figure of Merit");

    linkaxes(vertcat(h{:}),  "y");
    sgtitle(sprintf("%s profile %d %s to %s", row.name, i, row.t0, row.t1));
    waitforbuttonpress();
end % for i
end % diss_insitu_diagnostic_plots