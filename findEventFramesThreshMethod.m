function [event_frames] = findEventFramesThreshMethod(y, pk_frame, prev_event_frame, show_plot, prom_thresh, diff_thresh, next_min_frame)

    N = length(y);
    i = pk_frame-1;
    if y(i) > prom_thresh && i > 1
        while sign(y(i)-prom_thresh) == sign(y(i-1)-prom_thresh) && i > prev_event_frame+1
            i = i-1;
            if i <= 1 
                first = NaN;
                if show_plot && i <= 1; disp('Step-Like Pulse, no first edge'); end
                break; 
            end
        end   
        %first crossing
    elseif i <= 1
        first = NaN;
        disp('First edge before start of movie'); 
    elseif y(i) < prom_thresh
        first = NaN;
        disp('Too few frames in rising edge');
        i = 0;
    end
    
    if i > 1
        first = i-1;
    end
    
    increase = 0; % not used. But can be useful for other event detection strategies. 
    
    i = pk_frame+1;                    %start search for next crossing at center. Also stop if you encounter the minimum that occurred before the next peak
    while sign(y(i)-prom_thresh) == sign(y(i-1)-prom_thresh) && i <= N-1 && i < next_min_frame
        i = i+1;
        if i ~= N && y(i) > y(i-1)
            increase = increase + (y(i) - y(i-1));
        else
            increase = 0;
        end
    end
    
    if i ~= N && y(pk_frame) > prom_thresh
        last = i;
    else
        if show_plot && i == N; disp('Step-Like Pulse, no second edge'); end
        if show_plot && y(pk_frame) < prom_thresh; disp('Peak value was under prominence threshold'); end
        last = NaN;
    end
    
    event_frames = first:last;
    %disp([num2str(first), ':', num2str(last)]); 
end