%% exampleUsage.m
% Simple subject-level EEG topography example.

clear;
clc;

thisDir = fileparts(mfilename('fullpath'));
cd(thisDir);

load('exampleSubjectData.mat', 'exampleData');

subjectIdx = 1;
conditionIdx = 1;
timeIndex = 317;
outputDir = 'outputs';
outputPrefix = 'subject01_condition01_t317';

outputs = doBrainTopo(exampleData, ...
    'SubjectIdx', subjectIdx, ...
    'ConditionIdx', conditionIdx, ...
    'TimeIndex', timeIndex, ...
    'OutputDir', outputDir, ...
    'OutputPrefix', outputPrefix);

fprintf('\nDone.\n');
fprintf('Topo image:\n%s\n\n', outputs.imageFile);
fprintf('Channel CSV:\n%s\n\n', outputs.csvFile);
fprintf('MAT file:\n%s\n\n', outputs.matFile);
