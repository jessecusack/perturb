% Diagnostic plots for dissipation spectra from profiles
%
% The first argument is a profile mat filename
% Optional arguments are:
%  profiles a vector of profiles to plot, if not specified, all profiles are ploted
%  minDepth a scalar minimum depth
%  maxDepth a scalar maximum depth
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function a = diss_spectra_diagnostic_plots(varargin)
p = inputParser();
addRequired(p, "fn", @isfile);
addParameter(p, "profiles", [], @(x) ~isempty(x));
addParameter(p, "minDepth", nan, @isreal);
addParameter(p, "maxDepth", nan, @isreal);
parse(p, varargin{:});

pars = p.Results;
fn = pars.fn;
profiles = pars.profiles;

a = load(fn);

if isempty(profiles)
    profiles = 1:numel(a.profiles);
end % if isempty

pInfo = a.info;

for i = profiles
    profile = a.profiles{i};
    row = pInfo(i,:);
    if ~isnan(pars.minDepth)
        profile = profile(profile.depth >= pars.minDepth,:);
    end % if min
    if ~isnan(pars.maxDepth)
        profile = profile(profile.depth <= pars.maxDepth,:);
    end % if max
    if isempty(profile), continue; end;
    profile = sortrows(profile, "depth");
    for j = 1:size(profile,1)
        clf;
        plotSpectra(i, row, profile(j,:));
        waitforbuttonpress();
    end % for j
end % for i
end % diss_insitu_diagnostic_plots

function plotSpectra(iProfile, row, profile)
profile
K = profile.K;
shClean = squeeze(profile.sh_clean);
shDirty = squeeze(profile.sh);
Nasmyth_spec = squeeze(profile.Nasmyth_spec);
epsilon = profile.e;

Kmax = profile.K_max;

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
    sprintf("%s %s profile %d", texstr(row.name), profile.t, iProfile), ...
    sprintf("Depth=%.1f m method=[%s] $$log_{10}(\\epsilon) = %.2f\\pm%.2f$$", ...
    profile.depth, num2str(squeeze(profile.method)), ...
    log10(profile.epsilonMean), ...
    log10(exp(profile.epsilonLnSigma))) ...
    ], ...
    "interpreter", "latex");
end % plotSpectra