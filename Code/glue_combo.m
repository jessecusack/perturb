%
% Glue together multiple combo files
%
% This is analogous to glue_widthwise, but with a sort of times
%
% Dec-2023, Pat Welch, pat@mousebrains.com

function [pInfo, binned] = glue_combo(pars, outdir, comboRoot, key)
arguments (Input)
    pars (:,1) cell % Cell array of output of process_P_files    
    outdir string   % directory to save to
    comboRoot string="diss_combo_root"
    key string="bin"
end % arguments Input
arguments (Output)
    pInfo table % Glued together info
    binned table % Glued together tbl
end % arguments Output

profiles = cell(size(pars));
pInfo = cell(size(pars));

for index = 1:numel(pars)
    par = pars{index};
    fn = fullfile(par.(comboRoot), "combo.mat");
    profiles{index} = load(fn);
    pInfo{index} = profiles{index}.info;
end % for index

binned = glue_widthwise(key, profiles, strings(0), "tbl");

pInfo = vertcat(pInfo{:});
[~, ix] = sort(pInfo.t0);
pInfo = pInfo(ix,:);
nWide = size(pInfo,1);

for name = string(binned.Properties.VariableNames)
    if size(binned.(name),2) ~= nWide, continue; end
    binned.(name) = binned.(name)(:,ix);
end % for name

combo = struct("info", pInfo, "tbl", binned);
ofn = fullfile(outdir, "combo.mat");
my_mk_directory(ofn);
save(ofn, "-struct", "combo");
fprintf("Saved %s\n", ofn);
end % glue_combo
