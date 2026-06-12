%% exampleContrast.m
% Subject-level EEG topography for condition 1 minus condition 2.

clear;
clc;

thisDir = fileparts(mfilename('fullpath'));
cd(thisDir);

subjectIdx = 1;
condition1Idx = 1;
condition2Idx = 2;
timeIndex = 317;
outputDir = fullfile('outputs', 'contrast_single_subject');
outputPrefix = 'subject01_condition01minus02_t317';

outputs = doBrainTopo('sampleGrandERP.mat', ...
    'DataVariable', 'sampleGrandERP', ...
    'ChanlocsFile', 'sampleGrandERP.mat', ...
    'Analysis', 'contrast', ...
    'SubjectIdx', subjectIdx, ...
    'Condition1Idx', condition1Idx, ...
    'Condition2Idx', condition2Idx, ...
    'TimeIndex', timeIndex, ...
    'OutputDir', outputDir, ...
    'OutputPrefix', outputPrefix);

fprintf('\nDone.\n');
fprintf('Contrast topo image:\n%s\n\n', outputs.imageFile);
fprintf('Channel CSV:\n%s\n\n', outputs.csvFile);
fprintf('MAT file:\n%s\n\n', outputs.matFile);
