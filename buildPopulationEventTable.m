function [p] = buildPopulationEventTable(guide_name)

    g = readtable(guide_name);
    
    % Initialize arrays of measurements for individual events
    AUC = [];
    amplitude = [];
    duration = [];
    proportion_participation = [];
    start_frame = [];
    end_frame = [];
    
    % Same as above, but for metadata 
    
    % Row index of population event table
    p_row = 1;
    
    % For each movie 
    for r = 1:size(g, 1)
        
        if g.include(r)
            event_stats = load([g.event_stats_name{r}, '.mat']);
            event_stats = event_stats.event_stats;

            % For each event 
            for e = 1:length(event_stats.amplitude)

                % Collect summary measurements of each event by averaging the measurement across cells
                AUC = [AUC, mean(event_stats.AUC{e})];
                amplitude = [amplitude, mean(event_stats.amplitude{e})];
                duration = [duration, mean(event_stats.duration{e})];
                proportion_participation = [proportion_participation, event_stats.proportion_participation(e)];
                start_frame = [start_frame, event_stats.event_windows(e,1)];
                end_frame = [end_frame, event_stats.event_windows(e,2)];

                % Collect metadata 
                data_name{p_row} = g.data_name{r};
                event_stats_name{p_row} = g.event_stats_name{r};
                distribution{p_row} = g.distribution{r};

                % Update the table row index
                p_row = p_row + 1;

            end 
        end
    end 
    
    % Build the population event table
    var_names = {'data_names', 'event_stats_name', 'distribution', ... % metadata
        'AUC', 'amplitude', 'duration', 'proportion_participation', ...
        'start_frame', 'end_frame'}; % event measurements
        
    var_types = {'string', 'string', 'string', ... % metadata 
        'double', 'double', 'double', 'double', ...
        'double', 'double'}; % event measurements
       
    sz = [length(AUC), length(var_types)];
    p = table('Size', sz, 'VariableTypes', var_types, 'VariableNames', var_names);
    
    p.AUC = AUC';
    p.amplitude = amplitude';
    p.duration = duration';
    p.proportion_participation = proportion_participation';
    p.start_frame = start_frame';
    p.end_frame = end_frame';
    p.data_names = data_name'; 
    p.event_stats_name = event_stats_name';
    p.distribution = distribution'; 
    
end    