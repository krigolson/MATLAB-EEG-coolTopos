function outputs = plotBrainTopoSurface(channelValues, chanlocs, varargin)
%PLOTBRAINTOPOSURFACE Project EEG channel values onto a cortical surface.
%
%   outputs = plotBrainTopoSurface(channelValues, chanlocs)
%
% This uses the same Brainstorm ICBM152 pial cortex surface used by the
% sLORETA plotting tools, but projects EEG channel values by 3D electrode
% direction rather than source locations.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'channelValues', @(x) isnumeric(x) && isvector(x));
addRequired(parser, 'chanlocs', @(x) isstruct(x));
addParameter(parser, 'View', 'six', @(x) (ischar(x) || isstring(x)) || ...
    (isnumeric(x) && numel(x) == 2));
addParameter(parser, 'Title', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputPng', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ColorLimit', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
addParameter(parser, 'ColorMode', 'brainNeutral', @(x) ischar(x) || isstring(x));
addParameter(parser, 'NeutralWidth', 0.12, @(x) isnumeric(x) && isscalar(x) && ...
    isfinite(x) && x >= 0 && x < 1);
addParameter(parser, 'ProjectionSigma', 0.22, @(x) isnumeric(x) && isscalar(x) && ...
    isfinite(x) && x > 0);
addParameter(parser, 'SurfaceFile', '', @(x) ischar(x) || isstring(x));
addParameter(parser, 'HighlightMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
addParameter(parser, 'Resolution', 250, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(parser, channelValues, chanlocs, varargin{:});
opts = parser.Results;

values = channelValues(:);
if numel(values) ~= numel(chanlocs)
    error([mfilename ':ChannelMismatch'], ...
        'channelValues has %d channels but chanlocs has %d channels.', ...
        numel(values), numel(chanlocs));
end

[vertices, faces] = load_cortex_surface(char(opts.SurfaceFile));
electrodeDirections = chanlocs_to_mni_directions(chanlocs);
vertexDirections = vertices_to_directions(vertices);
vertexValues = project_channels_to_vertices(vertexDirections, electrodeDirections, ...
    values, opts.ProjectionSigma);
vertexValues = smooth_vertex_values(faces, vertexValues, 4);

highlightMask = opts.HighlightMask;
if ~isempty(highlightMask)
    highlightMask = logical(highlightMask(:));
    if numel(highlightMask) ~= numel(values)
        error([mfilename ':BadHighlightMask'], ...
            'HighlightMask must contain one value per channel.');
    end
    if any(highlightMask)
        highlightValues = project_channels_to_vertices(vertexDirections, electrodeDirections, ...
            double(highlightMask), opts.ProjectionSigma);
        vertexValues(highlightValues < 0.08) = 0;
    else
        vertexValues(:) = 0;
    end
end

colorRange = choose_color_range(vertexValues, opts.ColorLimit, ~isempty(highlightMask));

colors = brain_topo_colors(vertexValues, colorRange, char(opts.ColorMode), opts.NeutralWidth);

fig = figure('Color', 'k', 'Name', char(opts.Title));
set(fig, 'Renderer', 'opengl', 'InvertHardcopy', 'off');

viewSpec = opts.View;
if ischar(viewSpec) || isstring(viewSpec)
    isSixView = strcmpi(char(viewSpec), 'six');
else
    isSixView = false;
end

if isSixView
    set(fig, 'Position', [80 80 1500 900]);
    viewNames = {'left', 'top', 'right', 'front', 'back'};
    axesPositions = [0.05 0.54 0.28 0.36; ...
        0.36 0.54 0.28 0.36; ...
        0.67 0.54 0.28 0.36; ...
        0.20 0.10 0.28 0.36; ...
        0.52 0.10 0.28 0.36];
    for viewIdx = 1:numel(viewNames)
        ax = axes('Parent', fig, 'Position', axesPositions(viewIdx, :));
        render_cortex_axes(ax, vertices, faces, colors, viewNames{viewIdx}, 1.02);
        title(ax, viewNames{viewIdx}, 'Color', 'w', 'FontWeight', 'normal');
    end
    titleText = char(opts.Title);
    if ~isempty(titleText)
        annotation(fig, 'textbox', [0.02 0.955 0.96 0.04], ...
            'String', titleText, 'Color', 'w', 'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', 'FontSize', 14, ...
            'Interpreter', 'none');
    end
else
    set(fig, 'Position', [100 100 1100 820]);
    ax = axes('Parent', fig, 'Color', 'k');
    set(ax, 'Position', [0 0 1 1]);
    render_cortex_axes(ax, vertices, faces, colors, viewSpec, 1.12);
    titleText = char(opts.Title);
    if ~isempty(titleText)
        title(ax, titleText, 'Color', 'w', 'FontWeight', 'normal', ...
            'Interpreter', 'none');
    end
end

outputPng = char(opts.OutputPng);
if ~isempty(outputPng)
    save_figure_png(fig, outputPng, opts.Resolution);
end

outputs = struct();
outputs.figure = fig;
outputs.outputPng = outputPng;
outputs.vertexValues = vertexValues;
outputs.colorRange = colorRange;
outputs.colorLimit = max(abs(colorRange));
end

function [vertices, faces] = load_cortex_surface(surfaceFile)
if isempty(surfaceFile)
    surfaceFile = fullfile(fileparts(mfilename('fullpath')), ...
        'templates', 'cortex', 'brainstorm_icbm152_cortex_pial_low.mat');
end
if ~exist(surfaceFile, 'file')
    error([mfilename ':MissingSurface'], ...
        'Could not find cortex surface file: %s', surfaceFile);
end
cortex = load(surfaceFile, 'Vertices', 'Faces');
vertices = cortex.Vertices;
faces = cortex.Faces;
if max(abs(vertices(:))) < 1
    vertices = vertices * 1000;
end
end

function directions = chanlocs_to_mni_directions(chanlocs)
nChannels = numel(chanlocs);
directions = zeros(nChannels, 3);
for idx = 1:nChannels
    if ~isfield(chanlocs, 'X') || ~isfield(chanlocs, 'Y') || ~isfield(chanlocs, 'Z')
        error([mfilename ':BadChanlocs'], ...
            'chanlocs must contain X, Y, and Z fields.');
    end
    eegX = double(chanlocs(idx).X);
    eegY = double(chanlocs(idx).Y);
    eegZ = double(chanlocs(idx).Z);
    directions(idx, :) = [-eegY, eegX, eegZ];
end
directions = normalize_rows(directions);
end

function directions = vertices_to_directions(vertices)
center = mean(vertices, 1);
directions = bsxfun(@minus, vertices, center);
directions = normalize_rows(directions);
end

function normalized = normalize_rows(values)
norms = sqrt(sum(values .^ 2, 2));
norms(norms == 0) = 1;
normalized = bsxfun(@rdivide, values, norms);
end

function vertexValues = project_channels_to_vertices(vertexDirections, electrodeDirections, values, sigma)
dotProducts = vertexDirections * electrodeDirections.';
dotProducts = min(max(dotProducts, -1), 1);
angularDistance = acos(dotProducts);
weights = exp(-(angularDistance .^ 2) ./ (2 * sigma ^ 2));
weightSums = sum(weights, 2);
vertexValues = weights * values(:);
vertexValues = vertexValues ./ max(weightSums, eps);
end

function colorRange = choose_color_range(values, colorLimit, forceSymmetric)
finiteValues = values(isfinite(values));
if isempty(finiteValues)
    finiteValues = 0;
end

if ~isempty(colorLimit)
    limit = abs(colorLimit);
    colorRange = [-limit limit];
elseif forceSymmetric
    limit = max(abs(finiteValues));
    if limit <= 0
        limit = 1;
    end
    colorRange = [-limit limit];
else
    colorRange = [min(finiteValues) max(finiteValues)];
    if colorRange(1) == colorRange(2)
        delta = max(abs(colorRange(1)) * 0.05, 1);
        colorRange = colorRange + [-delta delta];
    end
end
end

function colors = brain_topo_colors(values, colorRange, colorMode, neutralWidth)
baseBrain = [0.58 0.56 0.50];
low = colorRange(1);
high = colorRange(2);
if high <= low
    high = low + 1;
end

switch lower(colorMode)
    case {'brainneutral', 'neutral', 'brain'}
        colors = repmat(baseBrain, numel(values), 1);
        [negative, positive, negStrength, posStrength] = adaptive_strengths(values, low, high, neutralWidth);

        if any(positive)
            posStrength = posStrength(positive);
            posMap = [baseBrain; ...
                0.92 0.78 0.34; ...
                1.00 0.57 0.16; ...
                0.92 0.23 0.06; ...
                0.55 0.02 0.02];
            colors(positive, :) = ramp_colors(posStrength, posMap);
        end

        if any(negative)
            negStrength = negStrength(negative);
            negMap = [baseBrain; ...
                0.44 0.74 0.88; ...
                0.05 0.55 1.00; ...
                0.02 0.18 0.88; ...
                0.00 0.00 0.42];
            colors(negative, :) = ramp_colors(negStrength, negMap);
        end

    case {'bluegreenred', 'bgr'}
        colorLimit = max(abs(colorRange));
        strength = min(abs(values) ./ max(colorLimit, eps), 1);
        strength = strength .^ 0.75;
        cmap = blue_green_red(256);
        scaled = (values + colorLimit) ./ (2 * colorLimit);
        scaled = min(max(scaled, 0), 1);
        idx = max(1, min(256, round(1 + scaled * 255)));
        colors = cmap(idx, :);
        colors = bsxfun(@times, colors, 0.35 + 0.65 * strength) + ...
            bsxfun(@times, baseBrain, 0.65 * (1 - strength));

    otherwise
        error([mfilename ':BadColorMode'], ...
            'ColorMode must be brainNeutral or blueGreenRed.');
end

colors = min(max(colors, 0), 1);
end

function [negative, positive, negStrength, posStrength] = adaptive_strengths(values, low, high, neutralWidth)
rangeWidth = high - low;
midpoint = low + rangeWidth / 2;
neutralHalfWidth = neutralWidth * rangeWidth / 2;
lowerNeutral = midpoint - neutralHalfWidth;
upperNeutral = midpoint + neutralHalfWidth;

negStrength = zeros(size(values));
posStrength = zeros(size(values));

negStrength = max(0, min(1, (lowerNeutral - values) ./ max(lowerNeutral - low, eps)));
posStrength = max(0, min(1, (values - upperNeutral) ./ max(high - upperNeutral, eps)));

negStrength = negStrength .^ 1.35;
posStrength = posStrength .^ 1.35;
negative = negStrength > 0;
positive = posStrength > 0;
end

function colors = ramp_colors(strength, anchors)
strength = min(max(strength(:), 0), 1);
nAnchors = size(anchors, 1);
positions = linspace(0, 1, nAnchors);
colors = zeros(numel(strength), 3);
for channelIdx = 1:3
    colors(:, channelIdx) = interp1(positions, anchors(:, channelIdx), ...
        strength, 'linear');
end
end

function blended = blend_colors(baseColor, targetColor, amount)
amount = min(max(amount(:), 0), 1);
base = repmat(baseColor, numel(amount), 1);
blended = bsxfun(@times, base, 1 - amount) + ...
    bsxfun(@times, targetColor, amount);
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

function render_cortex_axes(ax, vertices, faces, colors, viewSpec, zoomFactor)
set(ax, 'Color', 'k');
patch('Parent', ax, ...
    'Vertices', vertices, ...
    'Faces', faces, ...
    'FaceVertexCData', colors, ...
    'FaceColor', 'interp', ...
    'EdgeColor', 'none', ...
    'SpecularStrength', 0.10, ...
    'DiffuseStrength', 0.86, ...
    'AmbientStrength', 0.34);
axis(ax, 'equal');
axis(ax, 'off');
view(ax, view_to_az_el(viewSpec));
camlight(ax, 'headlight');
camlight(ax, -80, 20);
camlight(ax, 100, 25);
lighting(ax, 'gouraud');
material(ax, 'dull');
camzoom(ax, zoomFactor);
end

function azel = view_to_az_el(viewSpec)
if isnumeric(viewSpec)
    azel = viewSpec(:).';
    return;
end
switch lower(char(viewSpec))
    case 'right'
        azel = [0 0];
    case 'left'
        azel = [180 0];
    case 'front'
        azel = [90 0];
    case 'back'
        azel = [-90 0];
    case 'top'
        azel = [0 90];
    case 'bottom'
        azel = [0 -90];
    otherwise
        error([mfilename ':BadView'], 'Unknown view %s.', char(viewSpec));
end
end

function values = smooth_vertex_values(faces, values, nIter)
nVertices = numel(values);
edges = [faces(:, [1 2]); faces(:, [2 3]); faces(:, [3 1])];
edges = [edges; edges(:, [2 1])];
for iter = 1:nIter
    accum = accumarray(edges(:, 1), values(edges(:, 2)), [nVertices 1], @sum, 0);
    counts = accumarray(edges(:, 1), 1, [nVertices 1], @sum, 0);
    values = 0.55 * values + 0.45 * (accum ./ max(counts, 1));
end
end

function save_figure_png(fig, outputPng, resolution)
parentDir = fileparts(outputPng);
if ~isempty(parentDir) && ~exist(parentDir, 'dir')
    mkdir(parentDir);
end
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, outputPng, 'Resolution', resolution, ...
        'BackgroundColor', 'black');
else
    set(fig, 'InvertHardcopy', 'off');
    print(fig, outputPng, '-dpng', sprintf('-r%d', resolution));
end
end
