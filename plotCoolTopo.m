function outputs = plotCoolTopo(channelValues, chanlocs, varargin)
%PLOTCOOLTOPO Plot an EEGLAB-independent scalp topography.
%
%   outputs = plotCoolTopo(channelValues, chanlocs)
%   outputs = plotCoolTopo(channelValues, chanlocs, 'Name', value, ...)

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'channelValues', @(x) isnumeric(x) && isvector(x));
addRequired(parser, 'chanlocs', @(x) isstruct(x));
addParameter(parser, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputPng', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ColorLimit', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
addParameter(parser, 'ShowElectrodes', true, @(x) islogical(x) || isnumeric(x));
addParameter(parser, 'HighlightMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
addParameter(parser, 'Resolution', 220, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(parser, channelValues, chanlocs, varargin{:});
opts = parser.Results;

values = channelValues(:);
if numel(values) ~= numel(chanlocs)
    error([mfilename ':ChannelMismatch'], ...
        'channelValues has %d channels but chanlocs has %d channels.', ...
        numel(values), numel(chanlocs));
end

[x, y, labels] = project_chanlocs(chanlocs);
gridN = 220;
gridAxis = linspace(-1.05, 1.05, gridN);
[gridX, gridY] = meshgrid(gridAxis, gridAxis);
headMask = sqrt(gridX .^ 2 + gridY .^ 2) <= 1;

topo = griddata(x, y, values, gridX, gridY, 'linear');
nearestTopo = griddata(x, y, values, gridX, gridY, 'nearest');
topo(isnan(topo)) = nearestTopo(isnan(topo));
topo(~headMask) = NaN;

colorLimit = opts.ColorLimit;
if isempty(colorLimit)
    finiteValues = values(isfinite(values));
    if isempty(finiteValues)
        colorLimit = 1;
    else
        colorLimit = max(abs(finiteValues));
        if colorLimit == 0
            colorLimit = 1;
        end
    end
end

fig = figure('Color', 'w', 'Name', char(opts.Title));
set(fig, 'Position', [100 100 760 680]);
ax = axes('Parent', fig);
cmap = blue_green_red(256);
topoRgb = topo_to_rgb(topo, cmap, colorLimit);
image(ax, gridAxis, gridAxis, topoRgb);
set(ax, 'YDir', 'normal');
set(ax, 'Color', 'w');
axis(ax, 'image');
axis(ax, 'off');
hold(ax, 'on');
colormap(ax, cmap);
caxis(ax, [-colorLimit colorLimit]);

draw_head(ax);
if logical(opts.ShowElectrodes)
    plot(ax, x, y, 'k.', 'MarkerSize', 9);
end

highlightMask = opts.HighlightMask;
if ~isempty(highlightMask)
    highlightMask = logical(highlightMask(:));
    if numel(highlightMask) ~= numel(values)
        error([mfilename ':BadHighlightMask'], ...
            'HighlightMask must have one value per channel.');
    end
    plot(ax, x(highlightMask), y(highlightMask), 'ko', ...
        'MarkerSize', 8, 'LineWidth', 1.4);
end

title(ax, char(opts.Title), 'FontWeight', 'normal', 'Interpreter', 'none');
cb = colorbar(ax);
try
    set(cb, 'Box', 'off');
catch
end

if ~isempty(char(opts.OutputPng))
    save_figure_png(fig, char(opts.OutputPng), opts.Resolution);
end

outputs = struct();
outputs.figure = fig;
outputs.outputPng = char(opts.OutputPng);
outputs.x = x;
outputs.y = y;
outputs.labels = labels;
outputs.colorLimit = colorLimit;
end

function [x, y, labels] = project_chanlocs(chanlocs)
nChannels = numel(chanlocs);
x = zeros(nChannels, 1);
y = zeros(nChannels, 1);
labels = cell(nChannels, 1);

for idx = 1:nChannels
    labels{idx} = chanlocs(idx).labels;
    if isfield(chanlocs, 'theta') && isfield(chanlocs, 'radius') && ...
            ~isempty(chanlocs(idx).theta) && ~isempty(chanlocs(idx).radius)
        theta = double(chanlocs(idx).theta);
        radius = double(chanlocs(idx).radius);
        x(idx) = radius * sind(theta);
        y(idx) = radius * cosd(theta);
    elseif isfield(chanlocs, 'X') && isfield(chanlocs, 'Y')
        x(idx) = double(chanlocs(idx).Y);
        y(idx) = double(chanlocs(idx).X);
    else
        error([mfilename ':BadChanlocs'], ...
            'chanlocs must contain theta/radius or X/Y fields.');
    end
end

scale = max(sqrt(x .^ 2 + y .^ 2));
if scale == 0
    scale = 1;
end
x = x ./ scale .* 0.92;
y = y ./ scale .* 0.92;
end

function draw_head(ax)
theta = linspace(0, 2 * pi, 360);
plot(ax, cos(theta), sin(theta), 'k-', 'LineWidth', 2);
plot(ax, [-0.18 0 0.18], [0.98 1.12 0.98], 'k-', 'LineWidth', 2);
plot(ax, [-1.00 -1.10 -1.00], [0.12 0 -0.12], 'k-', 'LineWidth', 2);
plot(ax, [1.00 1.10 1.00], [0.12 0 -0.12], 'k-', 'LineWidth', 2);
end

function rgb = topo_to_rgb(topo, cmap, colorLimit)
scaled = (topo + colorLimit) ./ (2 * colorLimit);
scaled = min(max(scaled, 0), 1);
idx = 1 + round((size(cmap, 1) - 1) * scaled);
idx(~isfinite(idx)) = 1;
rgb = ind2rgb(idx, cmap);
outside = ~isfinite(topo);
for channelIdx = 1:3
    plane = rgb(:, :, channelIdx);
    plane(outside) = 1;
    rgb(:, :, channelIdx) = plane;
end
end

function cmap = blue_green_red(n)
if nargin < 1
    n = 256;
end
half = floor(n / 2);
blueToGreen = [linspace(0, 0, half).', ...
    linspace(0.05, 0.85, half).', ...
    linspace(1, 0.05, half).'];
greenToRed = [linspace(0, 1, n - half).', ...
    linspace(0.85, 0.05, n - half).', ...
    linspace(0.05, 0, n - half).'];
cmap = [blueToGreen; greenToRed];
end

function save_figure_png(fig, outputPng, resolution)
parentDir = fileparts(outputPng);
if ~isempty(parentDir) && ~exist(parentDir, 'dir')
    mkdir(parentDir);
end
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, outputPng, 'Resolution', resolution, ...
        'BackgroundColor', 'white');
else
    print(fig, outputPng, '-dpng', sprintf('-r%d', resolution));
end
end
