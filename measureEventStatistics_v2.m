% This function measures statistics of the population activity events that occur in calcium imaging movies. The
% calcium imaging movies must already be processed into FOV objects by the processMovies function.
% This script will read a spreadsheet, load the FOV objects, measure statistics,
% and save structs containing the statistics as .mat files in the same directories as the FOV objects
% data_guide_name is the name of the spreadsheet with metadata about each
% movie.
% measure_params  is a struct that contains parameter values for making the
% event measurements.

% Handles the high-level organization of event measurements: loading the
% data guide spreadsheet, iterating over fields of view, calling the event
% measurement function, and saving the measurements
function [] = measureEventStatistics_v2(data_guide_name, measure_params)

% Detect import options for the data guide spreadsheet
opts = detectImportOptions(data_guide_name);

% Load the data guide spreadsheet as a table
d = readtable(data_guide_name, opts);

% Iterate over the movies referenced in each row of the data guide
for i = 1:size(d,1)
    
    % Check if the event statistics have been calculated yet for this
    % movie and the movie data exist
    if d.include(i) && ismissing(d.event_stats_name(i)) && ~ismissing(d.data_name(i))
        
        % Tell the user the event stats are being measured for this
        % movie
        disp(['Event statistics not found for ', d.movie_name{i}, ', now measuring them']);
        
        % Load the FOV object
        fov = load([d.path{i}, '\', d.movie_name{i}, '.mat']);
        
        % Extract the FOV object from the struct that it loads as (MATLAB
        % quirk)
        fov = fov.dataset;
        
        % Extract the traces from the FOV object
        traces = getFirstMovieTraces(fov, 'traces');        
        
        % Get the framerate
        framerate = d.framerate(i);
        
        % Find the movie frames during which events occurred
        [event_frames, traces_active, event_windows, cell_participation_frames] = findEvents(traces, measure_params, framerate);
        
        % Measure event statistics for this field of view
        event_stats = measureEventStatisticsFOV(traces, cell_participation_frames, event_frames, event_windows, framerate, measure_params);
        
        % Record the frames for which each neuron is active
        event_stats.active_frames = traces_active;
        
        % Record the data name within the event stats struct
        event_stats.data_name = d.data_name{i};
        
        % Save the event statistics file in the folder that the FOV is from
        event_stats_name = [d.movie_name{i}, '_events'];
        save(fullfile(d.path{i}, [event_stats_name, '.mat']), 'event_stats');
        
        % Update the data guide with the event statistics name
        d.event_stats_name{i} = event_stats_name;
        
        % Updates the spreadsheet with the names of the event statistics files
        saveSpreadsheet(d, data_guide_name);
        
    end
    
end

end

% Determine what frames of the movie had events and which cells
% were active during those frames
function [event_frames, traces_active, event_windows, cell_participation_frames] = findEvents(traces, measure_params, framerate)

% Find the frames that correspond to activity events. These are movie
% frames in which at least [measure_params.min_event_participation] of cells have
% activity greater than [measure_params.min_event_activity]
traces_active = findActiveTraces(traces, measure_params.min_event_activity, measure_params.level);
event_frames = sum(traces_active) > measure_params.min_event_participation * size(traces_active,1);

% Remove detected events that are too short. Leaves other events
% unaffected
event_frames = bwareaopen(event_frames, round(measure_params.min_event_length * framerate));

% Obtain event windows (n_events x 2 matrix of start and end frames)
event_windows = findBinaryComponentWindows(event_frames);

% Find the frames during which each cell was active during an event
cell_participation_frames = traces_active & event_frames;

end

% Binarizes each trace to indicate when the cell was active. Active time is
% the full width at half maximum about the peak
function [traces_active] = findActiveTraces(traces, min_event_activity, level)

traces_active = zeros(size(traces));

% Traces is a cells x frames array
for i = 1:size(traces, 1)
    
    % Filter the traces with a moving mean filter
    trace = traces(i,:);
    filt_trace = movmean(trace, 10);
    
    [pks, pk_frames, ~, pk_proms] = findpeaks(filt_trace, 'MinPeakProminence', min_event_activity);
    
    % Visualize peak detection
    if false && mod(i, 10) == 0
        h = figure;
        findpeaks(filt_trace, 'MinPeakProminence', min_event_activity, 'Annotate', 'extents');
        set(h, 'Position', [2         558        1918         420]);
        pause
        close(h);
    end
    
    trace_active = zeros(size(trace));
    
    for j = 1:length(pk_frames)
        event_frame_ns = findEventFrames(trace, pk_frames(j), pk_proms(j), pks(j), level, true); % last argument is whether to show a plot of event detection
        if sum(isnan(event_frame_ns)) == 0 && ~isempty(event_frame_ns)
            trace_active(event_frame_ns) = 1;
        end 
    end
    
    traces_active(i, :) = trace_active;
    
end
end

% Iterates over the events, generating an event struct that stores the
% measurements for each event. The event structs are then combined into a
% struct array in which the ordering preserves the temporal ordering of
% events.
function [event_stats] = measureEventStatisticsFOV(traces, cell_participation_frames, event_frames, event_windows, framerate, measure_params)

% Record the measure_params
event_stats.measure_params = measure_params;

% Record the event_frames
event_stats.event_frames = event_frames;

% Measure event frequency
movie_length = size(traces, 2) / framerate;
n_events = size(event_windows, 1);
event_stats.frequency = n_events / movie_length;

% Record event_windows
event_stats.event_windows = event_windows;

% Initialize event stats field. This makes sure the fields are defined
% even if there are no events
event_stats.amplitude = {};
event_stats.AUC = {};
event_stats.cell_participation = {};
event_stats.proportion_participation = [];
event_stats.iei = [];
event_stats.duration = {};

% For each event
for e = 1:n_events
    
    % Determine which cells participated in the event. Cell participation
    % is an array with 1s for cells that participated and 0s
    % elsewhere.
    this_event_frames = event_windows(e, 1):event_windows(e, 2);
    cell_participation = sum(cell_participation_frames(:, this_event_frames), 2) > 0;
    event_stats.cell_participation{e} = cell_participation;
    
    % Find the last frame of the previous event
    if e > 1
        inter_event_start = max([1, event_windows(e-1, 2)-1]);
    else
        inter_event_start = 1;
    end
    inter_event_end = max([(this_event_frames(1) - 1), 1]);
    inter_event_frames = inter_event_start:inter_event_end;
    
    
    % Measure the interevent interval (time between the previous event
    % and this one; NaN if this is the first event)
    if e > 1
        event_stats.iei(e) = (event_windows(e,1) - event_windows(e-1,2)) ./ framerate;
    else
        event_stats.iei(e) = NaN;
    end
    
    % Record the proportion of cells that participated in the event
    event_stats.proportion_participation(e) = sum(cell_participation) / length(cell_participation);
    
    % Record the maximum response amplitudes of cells that participated
    % in the event as leftward prominence: max during the event - min
    % during the preceding inter-event-interval
    traces_participating = traces(cell_participation, :);
    
    % Only measure amplitude, AUC, and duration if this event was sufficiently separated
    % from the previous event
    
    time_after_prev_event = event_stats.iei(e);
    if isnan(time_after_prev_event); time_after_prev_event = event_windows(e,1) / framerate; end % time since start of movie
    
    if e < n_events
        time_to_next_event = (event_windows(e+1, 2) - event_windows(e,2)) / framerate;
    else % it's the last event 
        time_to_next_event = movie_length - event_windows(e,2) / framerate; % Time to end of movie
    end 
    
    if time_after_prev_event >= measure_params.min_event_sep
        event_stats.amplitude{e} = max(traces_participating(:, this_event_frames), [], 2) - min(traces_participating(:, inter_event_frames), [], 2);
        
        % Only measure AUC and duration if the event was also not too
        % close to the next event
        
        if time_to_next_event >= measure_params.min_event_sep
            % Measure the area under the curve during the event for cells that participated in
            % this event, using trapezoidal numerical integration.
            event_stats.AUC{e} = trapz(1/framerate, traces_participating(:, this_event_frames), 2);
            
            % Record the duration of the event
            event_stats.duration{e} = length(this_event_frames) / framerate;
        else
            event_stats.AUC{e} = NaN;
            event_stats.duration{e} = NaN;
        end
    else
        event_stats.amplitude{e} = NaN;
        event_stats.AUC{e} = NaN;
        event_stats.duration{e} = NaN;
    end
    
end

% Record proportion of cells that are active in at least one event
participation_array = cell2mat(event_stats.cell_participation);
n_active = sum(sum(participation_array, 2) > 0);
n_cells = size(participation_array, 1);
event_stats.proportion_active = n_active / n_cells;


% Provide a warning if no acceptable events were found for characterizing
% amplitude, duration, and AUC
if sum(~isnan(cell2mat(event_stats.duration))) == 0
    warning('No suitable events found');
end 

end

% 4/16/2020 - retired this function and went with a simpler measure - the
% duration of the event...
% Record the durations of responses (in seconds) for cells that participated in
% the event. The duration of the response will be the full width at
% half max (FWHM)of the peak signal that occurred during the event.
% Note that the FWHM can stretch beyond the boundaries of the population event.
function [durations] = measureResponseDurationsFWHM(traces, event_frames, event_windows, framerate)

% Sets up the durations array
durations = zeros(size(traces, 1), 1);

% For each cell
for c = 1:size(traces, 1)
    
    durations(c) = measureResponseDuration(traces(c, :), ...
        event_frames, event_windows, framerate);
    
end

end

% Measures the response duration by finding the full width half max (FWHM)about the
% maximum response during a wave event. Note that the duration can extend
% outside the boundaries of the population response
function [duration] = measureResponseDuration(trace, event_frames, event_window, framerate)

% Extract trace during the event
event_trace = trace(event_frames);

% Find the maximum and the frame where the maximum occurs (with respect
% to the event window)
[maximum, event_max_frame] = max(event_trace);

% Find the frame where the maximum occurs with respect to the full
% trace
max_frame = event_max_frame + event_window(1) - 1;

% Calculate half maximum and determine what parts of the trace are
% above it
half_max = maximum / 2;
thresh_trace = trace > half_max;

% Count the number of frames above half max around the maximum frame
above_thresh = true;
fwhm = 1;

frame_n = max_frame + 1;
while above_thresh && frame_n <= length(trace) % Count frames above threshold after half max
    
    above_thresh = thresh_trace(frame_n);
    fwhm = fwhm + 1;
    frame_n = frame_n + 1;
    
end

frame_n = max_frame - 1;
while above_thresh && frame_n > 0 % Count frames above threshold after half max
    
    above_thresh = thresh_trace(frame_n);
    fwhm = fwhm + 1;
    frame_n = frame_n - 1;
    
end

% Convert FWHM to seconds
duration = fwhm / framerate;

end

% Saves an updated version of the data guide spreadsheet
function [] = saveSpreadsheet(d, data_guide_name)

% Get the parts of the data guide spreadsheet's filename
[filepath,name,ext] = fileparts(data_guide_name);

% Go to the path
cd(filepath);

% Save the new spreadsheet in the same path with the same extension
writetable(d, [name, '_added events', ext]);
end







