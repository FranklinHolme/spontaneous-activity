function [d] = compileEventSummaryStatistics(data_guide_name)

    % Detect import options for the data guide spreadsheet
    opts = detectImportOptions(data_guide_name);

    % Load the data guide spreadsheet as a table 
    d = readtable(data_guide_name, opts);

    % Iterate over the movies referenced in each row of the data guide
    for i = 1:size(d,1)
        
        % Tell the user what's happening
        disp(['Compiling event statistics from ', d.data_name{i}, ' into the spreadsheet']); 

        % Load the event_stats object
        if ~isempty(d.event_stats_name{i})
            event_stats = load([d.path{i}, '\', d.event_stats_name{i}, '.mat']);
            event_stats = event_stats.event_stats; 
            
            % Inter-event interval...
            d.iei_mean(i) = nanmean(event_stats.iei); % mean
            d.iei_std(i) = nanstd(event_stats.iei); % standard deviation 

            % proportion of cells that are active in at least one event 
            d.proportion_active_cells(i) = event_stats.proportion_active; % updated 20200917

            % Store event frequency in the data guide 
            d.frequency(i) = event_stats.frequency; 
            
            % Store mean event amplitude (e.g. mean of event amplitudes, where event amplitude is mean response across neurons) 
            d.amplitude_mean(i) = nanmean(cellfun(@nanmean, event_stats.amplitude));
            
            % Store event amplitude (summary statistic measurement of event
            % amplitude distribution)
            d.amplitude_median(i) = nanmedian(cellfun(@nanmean, event_stats.amplitude));
            
            % Max amplitude 
            d.amplitude_max(i) = nanmax(cellfun(@nanmean, event_stats.amplitude));
            
            % Variance of the amplitudes
            d.amplitude_var(i) = nanvar(cellfun(@nanmean, event_stats.amplitude));
            
            % Store AUC measurements in the data guide
            d.AUC_median(i) = nanmedian(cellfun(@nanmean, event_stats.AUC)); 
            d.AUC_mean(i) = nanmean(cellfun(@nanmean, event_stats.AUC)); 

            % Store mean response duration in the data guide 
            d.duration_median(i) = nanmedian(cellfun(@nanmean, event_stats.duration)); 
            d.duration_mean(i) = nanmean(cellfun(@nanmean, event_stats.duration)); 

            % Store mean proportion participation in the data guide
            d.participation_median(i) = median(event_stats.proportion_participation); 
            d.participation_mean(i) = mean(event_stats.proportion_participation); 
            
            % Store percent of time that the population is active 
            d.pct_of_time_active(i) = sum(event_stats.event_frames) / length(event_stats.event_frames) * 100; 

        end
        
    end 

    % Get the parts of the data guide spreadsheet's filename
    [filepath,name,ext] = fileparts(data_guide_name);
    
    % Go to the path 
    cd(filepath); 

    % Save the new spreadsheet in the same path with the same extension
    writetable(d, [name, '_event summary', ext]);
    
    % Then add the event_stats struct to d (this is done after saving the
    % spreadsheet because you can't have columns of structs in excel! 
    % Iterate over the movies referenced in each row of the data guide
    for i = 1:size(d,1)
        
        % Tell the user what's happening
        disp(['Compiling event statistics from ', d.data_name{i}, ' into the spreadsheet']); 

        % Load the event_stats object
        if ~isempty(d.event_stats_name{i})
            event_stats = load([d.path{i}, '\', d.event_stats_name{i}, '.mat']);
            event_stats = event_stats.event_stats; 
            
            d.event_stats(i) = event_stats;
        end
    end

end 


    