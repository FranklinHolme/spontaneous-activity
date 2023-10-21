function [event_frames] = findEventFrames(y, pk_frame, pk_prom, pk, level, show_plot)

    
    N = length(y);
    prom_thresh = pk - pk_prom*level;
    i = pk_frame-1;
    while sign(y(i)-prom_thresh) == sign(y(i-1)-prom_thresh)
        i = i-1;
        if i <= 1 
            first = NaN;
            if show_plot; disp('Step-Like Pulse, no first edge'); end
            break; 
        end
    end                                   %first crossing
    
    if i > 1
        first = i+1;
    end
    
    i = pk_frame+1;                    %start search for next crossing at center
    while ((sign(y(i)-prom_thresh) == sign(y(i-1)-prom_thresh)) && (i <= N-1))
        i = i+1;
    end
    
    if i ~= N
        last = i-1;
    else
        if show_plot; disp('Step-Like Pulse, no second edge'); end
        last = NaN;
    end
    
    event_frames = first:last;
    %disp([num2str(first), ':', num2str(last)]); 
end