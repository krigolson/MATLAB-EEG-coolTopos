function outputs = doGroupBrainTopo(dataInput, varargin)
%DOGROUPBRAINTOPO Plot group EEG topographies and channel-wise statistics.
%
%   outputs = doGroupBrainTopo(dataInput)
%   outputs = doGroupBrainTopo(dataInput, 'Analysis', 'contrast')
%
%   Data should be channels x time x conditions x subjects.

if nargin < 1 || isempty(dataInput)
    dataInput = 'rewpGrandERP.mat';
end

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'DataVariable', 'grandERP', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ChanlocsFile', 'matlocs.mat', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', 'outputs', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputPrefix', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'Analysis', 'contrast', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ConditionIdx', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'Condition1Idx', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'Condition2Idx', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'TimeIndex', 317, @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1));
addParameter(parser, 'Alpha', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(parser, 'Correction', 'fdr', @(x) ischar(x) || isstring(x));
addParameter(parser, 'Tail', 'both', @(x) ischar(x) || isstring(x));
addParameter(parser, 'PlotStyle', 'brain', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ColorLimit', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
addParameter(parser, 'StatsColorLimit', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
addParameter(parser, 'ColorMode', 'brainNeutral', @(x) ischar(x) || isstring(x));
addParameter(parser, 'NeutralWidth', 0.12, @(x) isnumeric(x) && isscalar(x) && ...
    isfinite(x) && x >= 0 && x < 1);
addParameter(parser, 'BrainTemplate', 'brainnet', @(x) ischar(x) || isstring(x));
addParameter(parser, 'SurfaceFile', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'CloseFigures', false, @(x) islogical(x) || isnumeric(x));
parse(parser, varargin{:});
opts = parser.Results;

rootDir = fileparts(mfilename('fullpath'));
outputDir = resolve_output_dir(char(opts.OutputDir), rootDir);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

[raw, dataInfo] = load_data(dataInput, opts);
chanlocs = load_chanlocs(resolve_path(char(opts.ChanlocsFile), rootDir));
if size(raw, 1) ~= numel(chanlocs)
    error([mfilename ':ChannelMismatch'], ...
        'Data has %d channels but chanlocs has %d channels.', ...
        size(raw, 1), numel(chanlocs));
end
if ndims(raw) < 4
    error([mfilename ':NeedSubjects'], ...
        'Group analysis needs channels x time x conditions x subjects data.');
end

timeIndex = opts.TimeIndex;
if isempty(timeIndex)
    timeIndex = choose_group_time_index(raw);
else
    timeIndex = round(timeIndex);
end

subjectValues = select_group_values(raw, opts, timeIndex);
nSubjects = size(subjectValues, 2);
meanValues = mean(subjectValues, 2);
stats = compute_channel_stats(subjectValues, char(opts.Tail));
stats.pCorrected = correct_pvalues(stats.p, char(opts.Correction));
stats.significant = stats.pCorrected <= opts.Alpha;

if isempty(char(opts.OutputPrefix))
    if strcmpi(char(opts.Analysis), 'contrast')
        outputPrefix = sprintf('groupBrainTopo_cond%02dminus%02d_t%03d', ...
            opts.Condition1Idx, opts.Condition2Idx, timeIndex);
    else
        outputPrefix = sprintf('groupBrainTopo_cond%02d_t%03d', ...
            opts.ConditionIdx, timeIndex);
    end
else
    outputPrefix = char(opts.OutputPrefix);
end

meanTopoFile = fullfile(outputDir, [outputPrefix '_mean_topo.png']);
statsTopoFile = fullfile(outputDir, [outputPrefix '_stats_topo.png']);
csvFile = fullfile(outputDir, [outputPrefix '_channel_stats.csv']);
matFile = fullfile(outputDir, [outputPrefix '_group_topo.mat']);

analysisLabel = make_analysis_label(opts);
meanTitle = sprintf('Group mean: %s, sample %d', analysisLabel, timeIndex);
switch lower(char(opts.PlotStyle))
    case {'brain', 'surface', 'cortex'}
        meanPlot = plotBrainTopoSurface(meanValues, chanlocs, ...
            'Title', meanTitle, ...
            'OutputPng', meanTopoFile, ...
            'ColorLimit', opts.ColorLimit, ...
            'ColorMode', opts.ColorMode, ...
            'NeutralWidth', opts.NeutralWidth, ...
            'BrainTemplate', opts.BrainTemplate, ...
            'SurfaceFile', opts.SurfaceFile);
    case {'scalp', 'topoplot', 'disk'}
        meanPlot = plotCoolTopo(meanValues, chanlocs, ...
            'Title', meanTitle, ...
            'OutputPng', meanTopoFile, ...
            'ColorLimit', opts.ColorLimit);
    otherwise
        error([mfilename ':BadPlotStyle'], ...
            'PlotStyle must be brain or scalp.');
end
if logical(opts.CloseFigures)
    close(meanPlot.figure);
end

statsValues = stats.t;
statsValues(~stats.significant) = 0;
statsTitle = sprintf('Significant channel t map, sample %d', timeIndex);
switch lower(char(opts.PlotStyle))
    case {'brain', 'surface', 'cortex'}
        statsPlot = plotBrainTopoSurface(statsValues, chanlocs, ...
            'Title', statsTitle, ...
            'OutputPng', statsTopoFile, ...
            'ColorLimit', opts.StatsColorLimit, ...
            'ColorMode', opts.ColorMode, ...
            'NeutralWidth', opts.NeutralWidth, ...
            'BrainTemplate', opts.BrainTemplate, ...
            'SurfaceFile', opts.SurfaceFile, ...
            'HighlightMask', stats.significant);
    case {'scalp', 'topoplot', 'disk'}
        statsPlot = plotCoolTopo(statsValues, chanlocs, ...
            'Title', statsTitle, ...
            'OutputPng', statsTopoFile, ...
            'ColorLimit', opts.StatsColorLimit, ...
            'HighlightMask', stats.significant);
end
if logical(opts.CloseFigures)
    close(statsPlot.figure);
end

channelLabels = chanlocs_labels(chanlocs);
write_group_csv(csvFile, channelLabels, meanValues, stats, nSubjects);

metadata = struct();
metadata.createdBy = mfilename;
metadata.dataInfo = dataInfo;
metadata.analysis = char(opts.Analysis);
metadata.conditionIdx = opts.ConditionIdx;
metadata.condition1Idx = opts.Condition1Idx;
metadata.condition2Idx = opts.Condition2Idx;
metadata.timeIndex = timeIndex;
metadata.nSubjects = nSubjects;
metadata.alpha = opts.Alpha;
metadata.correction = char(opts.Correction);
metadata.tail = char(opts.Tail);
metadata.outputPrefix = outputPrefix;

save(matFile, 'subjectValues', 'meanValues', 'stats', 'channelLabels', ...
    'chanlocs', 'metadata', '-v7');

outputs = struct();
outputs.meanTopoFile = meanTopoFile;
outputs.statsTopoFile = statsTopoFile;
outputs.csvFile = csvFile;
outputs.matFile = matFile;
outputs.subjectValues = subjectValues;
outputs.meanValues = meanValues;
outputs.stats = stats;
outputs.channelLabels = channelLabels;
outputs.timeIndex = timeIndex;
outputs.metadata = metadata;

fprintf('Group mean topo saved: %s\n', meanTopoFile);
fprintf('Group stats topo saved: %s\n', statsTopoFile);
fprintf('Group channel statistics CSV saved: %s\n', csvFile);
fprintf('Group topo MAT saved: %s\n', matFile);
fprintf('Significant channels: %d of %d\n', nnz(stats.significant), numel(stats.significant));
end

function [raw, info] = load_data(dataInput, opts)
info = struct();
if isnumeric(dataInput)
    raw = dataInput;
    info.source = 'numeric input';
else
    dataFile = char(dataInput);
    varName = char(opts.DataVariable);
    loaded = load(dataFile, varName);
    if ~isfield(loaded, varName)
        error([mfilename ':MissingVariable'], ...
            'Could not find variable %s in %s.', varName, dataFile);
    end
    raw = loaded.(varName);
    info.source = dataFile;
    info.variable = varName;
end
info.rawSize = size(raw);
end

function chanlocs = load_chanlocs(chanlocsFile)
loaded = load(chanlocsFile, 'chanlocs');
if ~isfield(loaded, 'chanlocs')
    error([mfilename ':MissingChanlocs'], ...
        '%s must contain a chanlocs variable.', chanlocsFile);
end
chanlocs = loaded.chanlocs;
end

function labels = chanlocs_labels(chanlocs)
labels = cell(numel(chanlocs), 1);
for idx = 1:numel(chanlocs)
    if isfield(chanlocs, 'labels') && ~isempty(chanlocs(idx).labels)
        labels{idx} = chanlocs(idx).labels;
    else
        labels{idx} = sprintf('Ch%d', idx);
    end
end
end

function values = select_group_values(raw, opts, timeIndex)
analysis = lower(char(opts.Analysis));
switch analysis
    case {'condition', 'single'}
        values = squeeze(raw(:, timeIndex, opts.ConditionIdx, :));
    case {'contrast', 'difference', 'diff'}
        condition1 = squeeze(raw(:, timeIndex, opts.Condition1Idx, :));
        condition2 = squeeze(raw(:, timeIndex, opts.Condition2Idx, :));
        values = condition1 - condition2;
    otherwise
        error([mfilename ':BadAnalysis'], ...
            'Analysis must be condition or contrast.');
end
if isvector(values)
    values = values(:);
end
end

function timeIndex = choose_group_time_index(raw)
reshaped = reshape(abs(raw), size(raw, 1), size(raw, 2), []);
collapsed = squeeze(mean(mean(reshaped, 1), 3));
[~, timeIndex] = max(collapsed(:));
end

function stats = compute_channel_stats(subjectValues, tail)
nSubjects = size(subjectValues, 2);
df = nSubjects - 1;
meanValues = mean(subjectValues, 2);
sdValues = std(subjectValues, 0, 2);
seValues = sdValues ./ sqrt(nSubjects);
tValues = meanValues ./ seValues;
tValues(~isfinite(tValues)) = 0;
pValues = t_to_p(tValues, df, tail);

stats = struct();
stats.mean = meanValues;
stats.sd = sdValues;
stats.se = seValues;
stats.t = tValues;
stats.df = repmat(df, size(tValues));
stats.p = pValues;
end

function p = t_to_p(tValues, df, tail)
if df <= 0
    p = ones(size(tValues));
    return;
end
x = df ./ (df + tValues .^ 2);
twoTailed = betainc(x, df / 2, 0.5);
switch lower(tail)
    case {'both', 'two', 'twotailed', 'two-tailed'}
        p = twoTailed;
    case {'right', 'positive', 'greater'}
        p = 0.5 * twoTailed;
        p(tValues < 0) = 1 - p(tValues < 0);
    case {'left', 'negative', 'less'}
        p = 0.5 * twoTailed;
        p(tValues > 0) = 1 - p(tValues > 0);
    otherwise
        error([mfilename ':BadTail'], ...
            'Tail must be both, right, or left.');
end
p = min(max(p, 0), 1);
end

function pCorrected = correct_pvalues(p, correction)
p = p(:);
switch lower(correction)
    case {'none', 'uncorrected'}
        pCorrected = p;
    case {'fdr', 'bh'}
        [sortedP, order] = sort(p, 'ascend');
        n = numel(p);
        adjusted = sortedP .* n ./ (1:n).';
        for idx = n-1:-1:1
            adjusted(idx) = min(adjusted(idx), adjusted(idx + 1));
        end
        pCorrected = zeros(size(p));
        pCorrected(order) = min(adjusted, 1);
    otherwise
        error([mfilename ':BadCorrection'], ...
            'Correction must be fdr or none.');
end
end

function label = make_analysis_label(opts)
if strcmpi(char(opts.Analysis), 'contrast')
    label = sprintf('condition %d - condition %d', ...
        opts.Condition1Idx, opts.Condition2Idx);
else
    label = sprintf('condition %d', opts.ConditionIdx);
end
end

function write_group_csv(csvFile, labels, meanValues, stats, nSubjects)
parentDir = fileparts(csvFile);
if ~isempty(parentDir) && ~exist(parentDir, 'dir')
    mkdir(parentDir);
end
fid = fopen(csvFile, 'w');
if fid == -1
    error([mfilename ':CannotWriteCSV'], 'Could not write %s.', csvFile);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'channel,n,mean,sd,se,t,df,p,p_corrected,significant\n');
for idx = 1:numel(meanValues)
    fprintf(fid, '%s,%d,%.12g,%.12g,%.12g,%.12g,%d,%.12g,%.12g,%d\n', ...
        labels{idx}, nSubjects, meanValues(idx), stats.sd(idx), stats.se(idx), ...
        stats.t(idx), stats.df(idx), stats.p(idx), stats.pCorrected(idx), ...
        stats.significant(idx));
end
end

function pathOut = resolve_path(pathIn, rootDir)
if is_absolute_path(pathIn) || exist(pathIn, 'file')
    pathOut = pathIn;
else
    pathOut = fullfile(rootDir, pathIn);
end
end

function outputDir = resolve_output_dir(outputDir, rootDir)
if is_absolute_path(outputDir)
    return;
end
outputDir = fullfile(rootDir, outputDir);
end

function tf = is_absolute_path(pathIn)
pathIn = char(pathIn);
tf = startsWith(pathIn, filesep) || ...
    (~isempty(regexp(pathIn, '^[A-Za-z]:[\\/]', 'once')));
end
