function [d] = measureSingleNeuronEvents(d, max_events, show_plot, interp_factor, measure_params)

    % Parameters
    prom_thresh = 0.005;
    diff_thresh = 0.01; % For finding boundaries of events based on second derivative 
    font_size = 18;

    % Pre-allocate space in NaN-padded arrays for for storing measurements
    % of event amplitudes, duration, and frequency. 
    d.amplitude = NaN * ones(size(d,1), max_events);
    d.duration = NaN * ones(size(d,1), max_events);
    d.auc = NaN * ones(size(d,1), max_events); 
    d.pk_frames = NaN * ones(size(d,1), max_events); 

    % Iterate over the traces 
    for i = 1:size(d, 1)
          
        % render figures as vector graphics  
        allfigs = findall(groot, 'type', 'figure');
        set(allfigs, 'Renderer', 'painters');
        
        % Close the open plots 
        close all 
        
        % Measure events. Use a moving mean on the trace for peak
        % detection. 
        trace = d.trace(i,:); 
        filt_trace = movmean(trace, 4); 
        filt_trace = filt_trace - prctile(filt_trace, 10); % shift baseline back to zero
        [amplitude, pk_frames, frame_durations, ~] = findpeaks(filt_trace, 'MinPeakProminence', prom_thresh);
        
        if show_plot && mod(i, 20) == 0
             h_peaks = figure;
             time = (1:length(filt_trace)) / d.framerate(1);
             %findpeaks(filt_trace, d.framerate(i), 'MinPeakProminence', prom_thresh, 'Annotate', 'extent');
             plot(time, filt_trace);
             xlabel('Time (s)');
             ylabel('DF/F');
             %set(gcf, 'Position', [-1915         714        1913         307]);
             xlim([min(time) max(time)]); 
             hold on 
             set(gca,'TickDir','out', 'FontSize', font_size);
        end 
        
        % Compute the leftward prominence 
        prominences = NaN(1, length(pk_frames)); 
        min_frames = NaN(1, length(pk_frames));
         for p = 1:length(pk_frames)
            
            if p ~= 1 
                prev_peak = pk_frames(p-1);
            else
                prev_peak = 1;
            end 
            prominence = amplitude(p) - min(filt_trace((prev_peak+1):(pk_frames(p)-1)));
            if ~isempty(prominence); prominences(p) = prominence; end
         end
         
        % measure event frequency and inter-event-intervals before rejecting events that are riding
        % on top of decays of preceding events (see below) 
        freq = length(prominences) / (length(trace) / d.framerate(i));
        ieis = diff(pk_frames) ./ d.framerate(i);
        d.mean_iei(i) = nanmean(ieis);
        d.median_iei(i) = nanmedian(ieis);
        d.std_iei(i) = nanstd(ieis);
        
        % Reject peaks with small prominence relative to their absolute
        % amplitude - these are riding on the decay of preceding events
        p = 1;
        while p <= length(pk_frames)   
            if ~isnan(prominences(p)) && prominences(p) / amplitude(p) < measure_params.min_prom_ratio 
               pk_frames(p) = []; 
               prominences(p) = [];
               amplitude(p) = [];
            else
                p = p + 1;
            end
        end
        
        % Determine which events were very close to earlier or later events
        % (below, some measurements are rejected based on this)
        close_to_prev = logical([0, (diff(pk_frames) ./ d.framerate(1)) < measure_params.min_event_sep]);
        close_to_next = logical([(diff(pk_frames) ./ d.framerate(1)) < measure_params.min_event_sep, 0]);
        
        
        for p = 1:length(pk_frames)
            if p > 1
                prev_peak = pk_frames(p-1);
            else
                prev_peak = 1;
            end 
            [~, min_frame] = min(filt_trace(prev_peak:(pk_frames(p)-1)));
            min_frame = min_frame - 1 + prev_peak;
            min_frames(p) = min_frame;
            
            %if show_plot && mod(i, 20) == 0 && ~close_to_prev(p) % shows
            %which events were excluded 
            if show_plot && mod(i, 20) == 0
                % plot the prominence measurements
                min_time = min_frame / d.framerate(1);
                plot([min_time, pk_frames(p) / d.framerate(1)], [filt_trace(pk_frames(p)) filt_trace(pk_frames(p))], '--r'); % Horizontal line
                plot([min_time, min_time], [filt_trace(min_frame) filt_trace(pk_frames(p))], '--r'); % Vertical line
                %set(gcf, 'Position', [-1915         689        1913         307]);
                set(gca,'TickDir','out', 'FontSize', font_size);
                title([d.genotype{i}, ' ', d.data_name{i}]);
            end
            
        end
        
              
        % Store measurements
        d.amplitude(i,1:length(prominences)) = prominences;
        d.freq(i) = freq; 
        d.pk_frames(i, 1:length(pk_frames)) = pk_frames;

        % Show a plot every X loop iterations 
        if show_plot && mod(i, 20) == 0
            show_plot_now = true;
        else
            show_plot_now = false;
        end
        
        % Calculate the AUCs and durations 
        [aucs, durations, activity_monitor] = calcSingleEventAUCs(filt_trace, ...
            pk_frames, prominences, ...
            amplitude, d.framerate(i), show_plot_now, measure_params.auc_level, prom_thresh, diff_thresh, min_frames, close_to_prev, close_to_next); 
        
        % Store AUCs and durations
        d.auc(i, 1:length(aucs)) = aucs;  
        d.duration(i, 1:length(durations)) = durations;
        
        
        % Remove amplitude measurements for events occurring too soon after
        % another event. Remove AUC and duration measurements for the
        % previous reason, and if another event follows too soon after. 
        d.amplitude(close_to_prev) = NaN;
        d.auc(close_to_prev | close_to_next) = NaN;
        d.duration(close_to_prev | close_to_next) = NaN;
        
        
%         if show_plot_now
%             figure
%             plot(time, activity_monitor);
%             set(gca,'TickDir','out', 'FontSize', font_size);
%             pause();
%         end
        
        % Update the filtered trace for the neuron object 
        n = d.neuron_object{i};
        n.setFilteredTrace(d.data_name{i}, filt_trace); 
        d.neuron_object{i} = n; 
        d.filt_trace(i,:) = filt_trace;
        
    end  
    
   
end 

function [aucs, durations, activity_monitor] = calcSingleEventAUCs(trace, pk_frames, pk_proms, magnitudes, framerate, show_plot, measure_params, prom_thresh, diff_thresh, min_frames, close_to_prev, close_to_next)

    durations = zeros(1, length(pk_frames));
    activity_monitor = zeros(size(trace));
    
    % Correct drifting baselines to improve performance of threshold method
    trace_baseline_corrected = msbackadj((1:length(trace))' ./ framerate, trace', 'WINDOWSIZE', 15, ...
            'STEPSIZE',15, 'QUANTILEVALUE', 0.01, 'SHOWPLOT', show_plot); 
    if show_plot
        hold on; 
        plot((1:length(trace_baseline_corrected)) / framerate, trace_baseline_corrected);
        %set(gcf, 'Position', [-1915         384        1913         307]);
        set(gca,'TickDir','out', 'FontSize', 16);
        xlabel('Time (s)');
        ylabel('DF/F');
        grid off
    end

    if show_plot
        time = (1:length(trace_baseline_corrected)) / framerate;
        disp('Finding event frames'); 
        h = figure;
        plot(time, trace_baseline_corrected, 'k');
        hold on 
        %xticklabels(xticks / interp_factor); 
        xlabel('Time (s)');
        ylabel('DF/F');
        
        %set(gcf, 'Position', [-1915          29        1913         307]);
        set(gca,'TickDir','out', 'FontSize', 16);
        xlim([min(time) max(time)]); 
        hline(prom_thresh); 
        hline(0);
    end 
    
    aucs = NaN * ones(size(pk_frames));
    
    colors = distinguishable_colors(length(pk_frames)); 
    
    prev_event_frame = 0;

    for i = 1:length(pk_frames)
        
        if i == length(pk_frames)
            next_min_frame = length(trace_baseline_corrected); % THere is no next peak
        else
            next_min_frame = min_frames(i+1); 
        end 
                
        %this_event_frames = findEventFrames(trace, pk_frames(i), pk_proms(i), magnitudes(i), measure_params.auc_level, show_plot); 
        this_event_frames = findEventFramesThreshMethod(trace_baseline_corrected, pk_frames(i), prev_event_frame, show_plot, prom_thresh, diff_thresh, next_min_frame); 
        %this_event_frames = findEventFramesDiffMethod(trace, i, pk_frames, diff_thresh);
        
        % Update the activity monitor
        if sum(isnan(this_event_frames)) == 0
            activity_monitor(this_event_frames) = 1;
        end 
       
        
        % Update the previous event frame
        prev_event_frame = max(this_event_frames);
        if isnan(prev_event_frame); prev_event_frame = 0; end
        
        
        % Measure duration and AUC 
        if sum(isnan(this_event_frames)) == 0
            
            durations(i) = length(this_event_frames) ./ framerate;
            
            % Calculates the AUC just during the event, relative to
            % baseline defined as minimum F during the event 
            aucs(i) = trapz(1/framerate, trace(this_event_frames));
            if show_plot
                figure(h);
                if ~close_to_prev(i) && ~close_to_next(i)
                    y_fill = [0, trace_baseline_corrected(this_event_frames)', 0];
                    fill([this_event_frames(1), this_event_frames, this_event_frames(end)] / framerate, y_fill, colors(i, :));
                end
                set(gca,'TickDir','out');
            end
        else
            aucs(i) = NaN; 
            durations(i) = NaN;
        
        end 
    end
    
    
   if show_plot
        pause();
        %close(h);
    end

end

