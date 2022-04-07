% Indicate which events in the event table coincide with network events
e = readtable('E:\Villy collaboration\2020 analysis pipeline\summary spreadsheets\event table.xlsx');
n = readtable('neuron table.xlsx');
framerate = 8.91; % Hz 

%p = readtable('population event table.xlsx');
disp('Annotating event table...');
for i = 1:size(e, 1)
    if mod(i, 1000) == 0; disp(['Working on event ', num2str(i), '/', num2str(size(e,1))]); end
    pkframe = e.pk_frame(i);
    [~, data_name, ext] = fileparts(e.data_name{i});
    events = load([data_name, ext, '_events.mat']);
    e.population_event(i) = events.event_stats.event_frames(pkframe);
    
    e.distribution(i) = n.distribution(e.neuron_id(i) == n.neuron_id);
end 

writetable(e, 'event table.xlsx');