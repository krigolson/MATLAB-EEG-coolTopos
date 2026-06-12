function outputs = doBrainTopo(dataInput, varargin)
%DOBRAINTOPO Plot a subject-level EEG scalp topography at one time point.
%
%   outputs = doBrainTopo(dataInput)
%   outputs = doBrainTopo(dataInput, 'Analysis', 'contrast')
%
%   Data can be channels x time, channels x time x conditions, or
%   channels x time x conditions x subjects.

if nargin < 1 || isempty(dataInput)
    dataInput = 'exampleSubjectData.mat';
end

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'DataVariable', 'exampleData', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ChanlocsFile', 'matlocs.mat', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', 'outputs', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputPrefix', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'Analysis', 'condition', @(x) ischar(x) || isstring(x));
addParameter(parser, 'SubjectIdx', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'ConditionIdx', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'Condition1Idx', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'Condition2Idx', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'TimeIndex', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1));
addParameter(parser, 'PlotStyle', 'brain', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ColorLimit', [], @(x) isempty(x) || ...
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
validate_channel_count(raw, chanlocs);

[channelValues, analysisLabel, timeIndex] = select_subject_values(raw, opts);

if isempty(char(opts.OutputPrefix))
    if strcmpi(char(opts.Analysis), 'contrast')
        outputPrefix = sprintf('brainTopo_sub%02d_cond%02dminus%02d_t%03d', ...
            opts.SubjectIdx, opts.Condition1Idx, opts.Condition2Idx, timeIndex);
    else
        outputPrefix = sprintf('brainTopo_sub%02d_cond%02d_t%03d', ...
            opts.SubjectIdx, opts.ConditionIdx, timeIndex);
    end
else
    outputPrefix = char(opts.OutputPrefix);
end

imageFile = fullfile(outputDir, [outputPrefix '_topo.png']);
csvFile = fullfile(outputDir, [outputPrefix '_channels.csv']);
matFile = fullfile(outputDir, [outputPrefix '_topo.mat']);

titleText = sprintf('%s, sample %d', analysisLabel, timeIndex);
switch lower(char(opts.PlotStyle))
    case {'brain', 'surface', 'cortex'}
        plotOut = plotBrainTopoSurface(channelValues, chanlocs, ...
            'Title', titleText, ...
            'OutputPng', imageFile, ...
            'ColorLimit', opts.ColorLimit, ...
            'ColorMode', opts.ColorMode, ...
            'NeutralWidth', opts.NeutralWidth, ...
            'BrainTemplate', opts.BrainTemplate, ...
            'SurfaceFile', opts.SurfaceFile);
    case {'scalp', 'topoplot', 'disk'}
        plotOut = plotCoolTopo(channelValues, chanlocs, ...
            'Title', titleText, ...
            'OutputPng', imageFile, ...
            'ColorLimit', opts.ColorLimit);
    otherwise
        error([mfilename ':BadPlotStyle'], ...
            'PlotStyle must be brain or scalp.');
end
if logical(opts.CloseFigures)
    close(plotOut.figure);
end

channelLabels = chanlocs_labels(chanlocs);
write_channel_csv(csvFile, channelLabels, channelValues);

metadata = struct();
metadata.createdBy = mfilename;
metadata.dataInfo = dataInfo;
metadata.analysis = char(opts.Analysis);
metadata.subjectIdx = opts.SubjectIdx;
metadata.conditionIdx = opts.ConditionIdx;
metadata.condition1Idx = opts.Condition1Idx;
metadata.condition2Idx = opts.Condition2Idx;
metadata.timeIndex = timeIndex;
metadata.outputPrefix = outputPrefix;

save(matFile, 'channelValues', 'channelLabels', 'chanlocs', 'metadata', '-v7');

outputs = struct();
outputs.imageFile = imageFile;
outputs.csvFile = csvFile;
outputs.matFile = matFile;
outputs.channelValues = channelValues;
outputs.channelLabels = channelLabels;
outputs.timeIndex = timeIndex;
outputs.metadata = metadata;

fprintf('Brain topo image saved: %s\n', imageFile);
fprintf('Channel CSV saved: %s\n', csvFile);
fprintf('Brain topo MAT saved: %s\n', matFile);
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

function validate_channel_count(raw, chanlocs)
if size(raw, 1) ~= numel(chanlocs)
    error([mfilename ':ChannelMismatch'], ...
        'Data has %d channels but chanlocs has %d channels.', ...
        size(raw, 1), numel(chanlocs));
end
end

function [values, label, timeIndex] = select_subject_values(raw, opts)
timeIndex = select_time_index(raw, opts.TimeIndex, []);
values = select_subject_values_at_time(raw, opts, timeIndex);
if strcmpi(char(opts.Analysis), 'contrast')
    label = sprintf('Condition %d - condition %d', ...
        opts.Condition1Idx, opts.Condition2Idx);
else
    label = sprintf('Condition %d', opts.ConditionIdx);
end
end

function values = select_subject_values_at_time(raw, opts, timeIndex)
analysis = lower(char(opts.Analysis));
switch analysis
    case {'condition', 'single'}
        values = squeeze(select_data_slice(raw, opts.ConditionIdx, opts.SubjectIdx));
    case {'contrast', 'difference', 'diff'}
        condition1 = squeeze(select_data_slice(raw, opts.Condition1Idx, opts.SubjectIdx));
        condition2 = squeeze(select_data_slice(raw, opts.Condition2Idx, opts.SubjectIdx));
        values = condition1 - condition2;
    otherwise
        error([mfilename ':BadAnalysis'], ...
            'Analysis must be condition or contrast.');
end

if isvector(values)
    values = values(:);
else
    values = values(:, timeIndex);
end
end

function data = select_data_slice(raw, conditionIdx, subjectIdx)
if ndims(raw) == 2
    data = raw;
elseif ndims(raw) == 3
    data = raw(:, :, conditionIdx);
else
    data = raw(:, :, conditionIdx, subjectIdx);
end
end

function timeIndex = select_time_index(raw, requestedTimeIndex, currentValues)
if ~isempty(requestedTimeIndex)
    timeIndex = round(requestedTimeIndex);
    return;
end
if ~isempty(currentValues) && isvector(currentValues)
    timeIndex = 1;
    return;
end
if size(raw, 2) == 1
    timeIndex = 1;
else
    reshaped = reshape(abs(raw), size(raw, 1), size(raw, 2), []);
    collapsed = squeeze(mean(mean(reshaped, 1), 3));
    [~, timeIndex] = max(collapsed(:));
end
end

function write_channel_csv(csvFile, labels, values)
parentDir = fileparts(csvFile);
if ~isempty(parentDir) && ~exist(parentDir, 'dir')
    mkdir(parentDir);
end
fid = fopen(csvFile, 'w');
if fid == -1
    error([mfilename ':CannotWriteCSV'], 'Could not write %s.', csvFile);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'channel,value\n');
for idx = 1:numel(values)
    fprintf(fid, '%s,%.12g\n', labels{idx}, values(idx));
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
