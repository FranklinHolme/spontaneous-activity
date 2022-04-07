%% Initital processing of raw data 
% Enter the name of the spreadsheet you have built to describe the data and
% point to the data locations  
data_guide_name = '2020 cultured neuron imaging.xlsx';
%data_guide_path = 'C:\Users\Feller Lab\Google Drive\9 - collaboration\2020 analysis pipeline\summary spreadsheets\';
data_guide_path = 'E:\Villy collaboration\2020 analysis pipeline\summary spreadsheets\';

% Get filename of data guide 
[~, name, ext] = fileparts(data_guide_name);

% Get DF/F traces from movies 
warning('off','all'); % Gets rid of some warning associated with tiff tags
%processMoviesFixedBaseline([data_guide_path, data_guide_name]); 
processMovies([data_guide_path, data_guide_name]); 
warning('on','all');   

%% Measure population events
% Enter parameters for measuring events 
measure_params.min_event_activity = 0.005; % DF/F prominence for a cell to be considered active  
measure_params.min_event_participation = 0.2; % proportion of cells 
measure_params.min_event_length = 0.25; % s 
measure_params.level = 0.5; % fraction of prominence
measure_params.auc_level = 0.80; % fraction of prominence to include in AUC measurement for single neuron events 
measure_params.min_event_sep = 2; % seconds. Minimum delay after previous event acceptable for measuring amplitude. Also minimum time to next event for measuring duration and AUC
measure_params.min_prom_ratio = 0.5; % Ratio between peak prominence and absolute amplitude 

% Measure event statistics from background subtracted DF/F traces 
measureEventStatistics_v2([data_guide_path, name, '_updated', ext], measure_params);

% Compile event statistics into the spreadsheet 
data_guide = compileEventSummaryStatistics([data_guide_path, name, '_updated_added events', ext]);

%% Build a table of population events
p = buildPopulationEventTable('2020 cultured neuron imaging_updated_added events_event summary_updated.xlsx');
writetable(p, 'population event table.xlsx', 'WriteMode', 'replacefile'); 

%% Build a table of neurons 
max_frames = 2000; 
max_events = 500; 
max_neuron_per_fov = 40; 

% Build the neuron table 
d = buildNeuronTable('2020 cultured neuron imaging_updated_added events_event summary_updated.xlsx', max_frames, max_neuron_per_fov);

% In each neuron, measure event amplitudes, durations, AUCs, and the frequency of events. Store
% the results in NaN-padded arrays 
show_plot = false; 
interp_factor = 20; 

d = measureSingleNeuronEvents(d, max_events, show_plot, interp_factor, measure_params); 
%measureSingleNeuronEvents(d(strcmp(d.genotype, 'Tsc1 ko'), :), max_events, show_plot, interp_factor, level); 


%% Organize the neuron table according to experimental groups ('distributions')

% Sort the table by distribution so that they end up plotted in the correct
% order
d = sortrows(d, {'distribution'}, {'ascend'}); 

% save neuron table 
save('neuron table.mat', 'd');


%% Copy and reformat the neuron table to save it as an excel sheet 
d_excel = d;
d_excel = removevars(d_excel, {'neuron_object', 'trace', 'filt_trace'});
d_excel.amplitude = nanmean(d_excel.amplitude, 2);
d_excel.duration = nanmean(d_excel.duration, 2); 
d_excel.auc = nanmean(d_excel.auc, 2); 
writetable(d_excel, 'neuron table.xlsx', 'WriteMode', 'replacefile'); 
%clear('d_excel'); 


%% Visualize heatmaps of traces 
distributions = {'1. wt main', '1. wt supp', '2. het', '3. ko', '4. ko; Rptor het', ...
    '5. wt; EtOH', '6. wt; Rapamycin', '7. ko EtOH', '8. ko; Rapamycin',...
    '9. wt; shCtrl', '91. wt; ShRptor', '92. ko; shCtrl', '93. ko; shRptor'};

for i = 1:length(distributions)
    cur_d = d(strcmp(d.distribution, distributions{i}), :); 
    figure;
    imagesc(cur_d.trace);
    title(distributions{i}); 
    caxis([0 .1])
    xticklabels(xticks / cur_d.framerate(1));
    xlabel('T (sec.)');
    ylabel('Cells'); 
end 


%% Build a table of events (each row is a bout of activity in one neuron) 
e = buildEventTable(d); 
writetable(e, 'event table.xlsx'); 