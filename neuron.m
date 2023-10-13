
classdef neuron < handle 
    properties (SetAccess = private) 
       id  
       rois % coordinates of all the pixels in the rois 
       traces
       f0 % mean baseline value inside neuron's ROI
       filtered_traces 
       trace_stats % summary statistics of individual traces 
       markers % fluorescent markers: identity and mean intensity 
    end   
    
    methods 
        function obj = neuron(id)
            if nargin > 0
                obj.id = id;
                obj.rois = containers.Map;
                obj.traces = containers.Map;
                obj.f0 = containers.Map; 
                obj.filtered_traces = containers.Map;
                obj.trace_stats = containers.Map; 
                obj.markers = containers.Map; 
            else
                error('The neuron id must be numeric');
            end
        end
        
        function movie_exists = movieExists(obj, movie_name)
             movie_exists = obj.rois.isKey(movie_name);
         end
        
        function [] = addMovie(obj, movie_name, roi, trace, filt_trace, f0)
            if ~movieExists(obj, movie_name)
                obj.rois(movie_name) = roi;  
                obj.traces(movie_name) = trace;
                obj.f0(movie_name) = f0; 
                obj.filtered_traces(movie_name) = filt_trace; 
            else
                error('The data entries for this movie already exist. To update the entries, use the set methods: setROI, setTrace, etc.'); 
            end 
        end
        
        function overwrite = checkOverWrite(obj, movie_name, prop)
            switch prop
                case 'roi'
                    overwrite = isKey(obj.rois, movie_name);
                case 'trace'
                    overwrite = isKey(obj.traces, movie_name);
                case 'f0'
                    overwrite = isKey(obj.fo, movie_name); 
                case 'filtered trace'
                    overwrite = isKey(obj.filtered_traces, movie_name) && ~isempty(obj.filtered_traces(movie_name));
                case 'trace_stat'
                    overwrite = isKey(obj.trace_stats, movie_name);
                case 'marker'
                    overwrite = isKey(obj.markers, movie_name);
            end
            if overwrite
                warning(['you are resetting an existing ', prop, ' for this movie']);
            end 
        end
        
        function roi = getROI(obj, movie_name)
            % an ROI is a list of indices for all pixels in the image that
            % belong to this neuron 
            if movieExists(obj, movie_name)
                roi = obj.rois(movie_name);
            else
                %warning('There is no movie of that name for this neuron');
                roi = [NaN];
            end
        end
        
        function [] = setROI(obj, movie_name, roi)
            checkOverWrite(obj, movie_name, 'roi');
            obj.rois(movie_name) = roi;
        end
        
        function trace = getTrace(obj, movie_name)
            if movieExists(obj, movie_name)
                trace = obj.traces(movie_name);
            else
                error('There is no movie of that name for this neuron'); 
            end
        end
        
        function f0 = getF0(obj, movie_name)
            if movieExists(obj, movie_name)
                f0 = obj.f0(movie_name);
            else
                error('There is no movie of that name for this neuron'); 
            end
        end
        
        function [] = setTrace(obj, movie_name, trace)
            checkOverWrite(obj, movie_name, 'trace');
            obj.traces(movie_name) = trace;
        end
        
        function filtered_trace = getFilteredTrace(obj, movie_name)
            if movieExists(obj, movie_name)
                filtered_trace = obj.filtered_traces(movie_name);
            else 
                error('There is no ovie of that name for this neuron');
            end 
        end
        
        function [] = setFilteredTrace(obj, movie_name, filtered_trace)
            checkOverWrite(obj, movie_name, 'filtered trace');
            obj.filtered_traces(movie_name) = filtered_trace;
        end 
        
        function trace_stat_result = getTraceStat(obj, movie_name, key)
            if movieExists(obj, movie_name) && isKey(obj.trace_stats, movie_name)
               trace_stat = obj.trace_stats(movie_name); 
               if isa(trace_stat, 'containers.Map')
                   if isKey(trace_stat, key)
                       trace_stat_result = trace_stat(key);
                   else
                       trace_stat_result = NaN; 
                       warning('the specified trace statistic type did not exist');
                   end
               else
                    if size(trace_stat, 1) == 0
                        warning('The neuron has no trace stats for this movie');
                        trace_stat_result = NaN;
                    else
                        trace_stat_result = trace_stat;
                    end 
               end
            else
                trace_stat_result = NaN;
                warning('There is no movie of that name for this neuron'); 
            end
        end
        
        function [] = setTraceStat(obj, movie_name, key, trace_stat)
            acceptable_key = max(cell2mat(strfind({'amplitude', 'fwhm'}, key)));
            if  (max(size(acceptable_key)) == 0) || (acceptable_key ~= 1)
                warning([key, ' is  not an acceptable trace statistic name']);
            else
                if checkOverWrite(obj, movie_name, 'trace_stat')
                    trace_stats_temp = obj.trace_stats(movie_name);
                else
                    trace_stats_temp = containers.Map;
                end
                if trace_stats_temp.isKey(key)
                    warning('you are overwriting some existing trace statistics');
                end
                trace_stats_temp(key) = trace_stat;
                obj.trace_stats(movie_name) = trace_stats_temp;
            end
        end
        
        function marker = getMarker(obj, movie_name)
            if movieExists(obj, movie_name) && isKey(obj.markers, movie_name)
                marker = obj.markers(movie_name);
            else
                empty_struct.marker_id = '';
                empty_struct.marker_intensity = NaN; 
                marker = empty_struct; 
                warning('There is no marker for this neuron'); 
            end
        end
         
        function marker = getMarkerID(obj)
           all_markers = values(obj.markers);
           marker = '';
           if ~isempty(all_markers)
               for i = 1:max(size(all_markers))
                  cur_marker = all_markers{i};
                  if isstruct(cur_marker) && max(size(cur_marker.marker_id)) > max(size(marker))
                    marker = cur_marker.marker_id; 
                  end 
               end
           end 
        end
        
       function intensity = getMarkerIntensity(obj)
           all_markers = values(obj.markers);
           intensity = 0;
           if ~isempty(all_markers)
               for i = 1:max(size(all_markers))
                  cur_marker = all_markers{i};
                  if isstruct(cur_marker)
                    if ~isnan(cur_marker.marker_intensity) && cur_marker.marker_intensity > intensity
                        intensity = cur_marker.marker_intensity;
                    end
                  end 
               end
           end 
        end
         
        function [] = setMarker(obj, movie_name, marker_id, marker_intensity)
            checkOverWrite(obj, movie_name, 'marker');
            marker.marker_id = marker_id;
            marker.marker_intensity = marker_intensity;
            obj.markers(movie_name) = marker; 
        end
        
        function id = getID(obj)
             id = obj.id; 
        end 
         
        function movie_list = getMovieList(obj)
            movie_list = keys(obj.traces);
        end
    end
end

    
    
    
    
    
    
    