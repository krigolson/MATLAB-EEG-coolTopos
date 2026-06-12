# coolTopos

EEGLAB-independent EEG topography plotting tools that project channel values
onto the same cortical surface style used by the sLORETA Figure 1 plots.

The main subject-level function is:

```matlab
doBrainTopo
```

The main group-level function is:

```matlab
doGroupBrainTopo
```

The default plots use a five-view BrainNet ICBM152 cortical brain surface and an adaptive
brain-neutral colormap:

- blue/cyan: lower end of the current map
- neutral cortex color: middle range of the current map
- red/yellow: higher end of the current map

By default, subject maps and group mean maps autoscale from their projected
minimum to maximum. The middle of that range is left brain-colored so the map
does not turn into a solid red, green, or blue brain.

## Quick Start

In MATLAB:

```matlab
cd('/path/to/coolTopos')
exampleUsage
```

This loads `exampleSubjectData.mat`, selects condition 1 at sample 317, and
saves a five-view brain-surface EEG topography, a channel CSV file, and a
`.mat` output.

## Data Shape

The expected full data shape is:

```text
channels x time x conditions x subjects
```

For a single extracted subject, the data can be:

```text
channels x time x conditions
```

For one already-selected condition, the data can be:

```text
channels x time
```

The example subject file contains:

```text
exampleData
```

with size:

```text
63 channels x 400 time points x 2 conditions
```

## Subject-Level Condition Topography

```matlab
load('exampleSubjectData.mat', 'exampleData')

outputs = doBrainTopo(exampleData, ...
    'ConditionIdx', 1, ...
    'TimeIndex', 317, ...
    'OutputDir', 'outputs', ...
    'OutputPrefix', 'subject01_condition01_t317');
```

## Subject-Level Contrast Topography

Contrasts are always:

```text
condition 1 - condition 2
```

The code does not care what the conditions mean. Arrange your data so
condition 1 is the positive side of the contrast.

```matlab
outputs = doBrainTopo(exampleData, ...
    'Analysis', 'contrast', ...
    'Condition1Idx', 1, ...
    'Condition2Idx', 2, ...
    'TimeIndex', 317, ...
    'OutputDir', 'outputs', ...
    'OutputPrefix', 'subject01_condition01minus02_t317');
```

## Group-Level Topography And Statistics

`doGroupBrainTopo` saves two brain-surface figures:

- `*_mean_topo.png`
  - group mean amplitude or contrast projected onto the cortical surface
- `*_stats_topo.png`
  - t-map projected onto the cortical surface where statistically significant
    channels are shown

It also saves:

- `*_channel_stats.csv`
  - all channels and their statistics
- `*_group_topo.mat`
  - values and metadata for later use

Example:

```matlab
outputs = doGroupBrainTopo('rewpGrandERP.mat', ...
    'DataVariable', 'grandERP', ...
    'Analysis', 'contrast', ...
    'Condition1Idx', 1, ...
    'Condition2Idx', 2, ...
    'TimeIndex', 317, ...
    'OutputDir', fullfile('outputs', 'group_contrast'), ...
    'OutputPrefix', 'group_condition01minus02_t317', ...
    'Alpha', 0.05, ...
    'Correction', 'fdr', ...
    'Tail', 'both');
```

## Useful Options

Use one condition:

```matlab
'Analysis', 'condition'
'ConditionIdx', 1
```

Use a contrast:

```matlab
'Analysis', 'contrast'
'Condition1Idx', 1
'Condition2Idx', 2
```

Set the time point:

```matlab
'TimeIndex', 317
```

Set color scaling:

```matlab
'ColorLimit', 5
'StatsColorLimit', 4
```

When `ColorLimit` is empty, the subject and group mean maps use adaptive
minimum-to-maximum scaling. When `ColorLimit` is set, the range is fixed to
`-ColorLimit` to `+ColorLimit`.

Set the width of the neutral middle band:

```matlab
'NeutralWidth', 0.12
```

Larger values leave more of the brain surface in the natural cortex color.

Choose the brain surface:

```matlab
'BrainTemplate', 'brainnet'           % default, prettier ICBM152 surface
'BrainTemplate', 'brainnet_smoothed'  % smoother BrainNet surface
'BrainTemplate', 'brainstorm'         % older low-resolution surface
```

Use a custom surface file:

```matlab
'SurfaceFile', '/path/to/my_surface.nv'
```

Custom surfaces can be BrainNet `.nv` files or MATLAB `.mat` files with
`Vertices`/`Faces` or FieldTrip-style `mesh.pos`/`mesh.tri`.

Use the older blue-green-red color range:

```matlab
'ColorMode', 'blueGreenRed'
```

Use the old flat scalp disk instead of the brain surface:

```matlab
'PlotStyle', 'scalp'
```

Close figures automatically for batch processing:

```matlab
'CloseFigures', true
```

## Required Files

- `matlocs.mat`
  - channel locations
- `exampleSubjectData.mat`
  - small subject-level example
- `rewpGrandERP.mat`
  - group-level example data currently used by `exampleGroup.m`
- `templates/cortex/brainnet_icbm152.nv`
  - default BrainNet ICBM152 cortical surface
- `templates/cortex/brainstorm_icbm152_cortex_pial_low.mat`
  - fallback low-resolution Brainstorm cortical surface

## Notes

These functions do not call EEGLAB. By default, channel values are projected
from the 3D electrode directions in `matlocs.mat` onto the included
BrainNet ICBM152 cortical surface. A flat scalp disk is still available
with `'PlotStyle', 'scalp'`.
