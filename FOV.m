classdef FOV < handle
    
    properties (SetAccess = private)
        name % name of the field of view
        date % date the experiment happened
        neurons % neurons in the field of view
    end
    
    methods
        function obj = FOV(name, date)
            if nargin > 0
                if ischar(name)
                    obj.name = name;
                    obj.date = date;
                    obj.neurons = containers.Map('KeyType', 'single', 'ValueType', 'any');
                else
                    error('name must be a string')
                end
            end
        end
        
        function [movie_list] = getFullMovieList(obj)
            movie_list = {};
            ids = obj.getNeuronIDList();
            for i = 1:size(ids,2)
                id = ids{i};
                n = obj.getNeuron(id);
                movie_list_temp = n.getMovieList();
                if max(size(movie_list_temp)) > max(size(movie_list))
                    movie_list = movie_list_temp;
                end
            end
        end
        
        function exists = neuronExists(obj, id)
            exists = obj.neurons.isKey(id);
        end
        
        function [] = addNeuron(obj, neuron)
            if ~isa(neuron, 'neuron')
                error('The neuron has to be an object from the neuron class.');
            end
            if ~neuronExists(obj, neuron)
                obj.neurons(neuron.getID()) = neuron;
            else
                error('The neuron is already present in this piece of retina. Update its attributes instead.');
            end
        end
        
        function neuron = getNeuron(obj, id)
            if neuronExists(obj, id)
                neuron = obj.neurons(id);
            else
                error('This neuron is not yet present. Add it with addNeuron.');
            end
        end
        
        function idlist = getNeuronIDList(obj)
            idlist = keys(obj.neurons);
        end
        
        function h = plotTraces(obj, ids, movie_names, jit, marker, framerate, plot_filtered)
            traces_fig = figure;
            hold on
            trace_colors = {'k', 'r', 'g'};
            for i = 1:size(ids, 2)
                n = obj.getNeuron(ids{i});
                for j = 1:max(size(movie_names))
                    movie_name = movie_names{j};
                    trace_color = trace_colors{j};
                    if n.movieExists(movie_name)
                        
                        cur_trace = n.getTrace(movie_name);
                        time = (1:max(size(cur_trace))) ./ framerate;
                        last_val = cur_trace(max(size(cur_trace)));
                        if plot_filtered
                            cur_filt_trace = n.getFilteredTrace(movie_name);
                            if ~isempty(cur_filt_trace)
                                plot(time, cur_filt_trace - i * jit -last_val, trace_color, 'LineWidth', 0.5);
                            end
                        else
                            h = plot(time, cur_trace - i * jit -last_val, trace_color, 'LineWidth', 0.25);
                        end
                        label_text = num2str(ids{i});
                        if strcmp(marker, n.getMarkerID())
                            label_text = [label_text, ' ', n.getMarkerID()];
                        end
                        
                        % select the traces figure
                        figure(traces_fig);
                        text(size(cur_trace, 1)/framerate + jit, -i * jit,label_text);
                    else
                        warning('This neuron has no entry for the movie');
                    end
                end
            end
            %set(gca, 'visible', 'off');
            box off;
            set(gca,'xcolor',get(gcf,'color'));
            set(gca,'xtick',[]);
            set(gca,'ycolor',get(gcf,'color'));
            set(gca,'ytick',[]);
            
            % scalebar (100% dF/F, 60 s):
            plot([0,60],[0,0],'k');
            plot([0,0],[0,1],'k');
            hold off
            
        end
        
        % Plot the traces for all the neurons from one movie
        function h = plotTracesSimple(obj, framerate, offset, active_thresh)
            
            % Keep track of where I'm plotting
            cur_position = 0;
            
            % Get all the ids
            ids = obj.getNeuronIDList();
            
            traces_fig = figure;
            hold on
            
            for i = 1:size(ids, 2)
                n = obj.getNeuron(ids{i});
                movie_names = n.getMovieList();
                movie_name = movie_names{1};
                
                if n.movieExists(movie_name)
                    cur_trace = n.getTrace(movie_name);
                    
                    % Offset for the trace
                    %offset = -i*fixed_offset - max(cur_trace);
                    cur_position = cur_position - offset;
                    
                    time = (1:max(size(cur_trace))) ./ framerate;
                    h = plot(time, cur_trace + cur_position, 'k', 'LineWidth', 0.25);
                    
                    % Plot trace in red for times when the cell is active
                    active_trace = cur_trace;
                    active_trace(active_trace < active_thresh) = NaN;
                    plot(time, active_trace + cur_position, 'r', 'LineWidth', 0.25);
                    
                    label_text = num2str(ids{i});
                    figure(traces_fig);
                    text(size(cur_trace, 1)/framerate + offset, cur_position ,label_text);
                else
                    warning('This neuron has no entry for the movie');
                end
            end
            
            %set(gca, 'visible', 'off');
            box off;
            set(gca,'xcolor',get(gcf,'color'));
            set(gca,'xtick',[]);
            set(gca,'ycolor',get(gcf,'color'));
            set(gca,'ytick',[]);
            
            % scalebar (1% dF/F, 60 s):
            plot([0,60],[0,0],'k');
            plot([0,0],[0,0.01],'k');
            hold off
            
        end
        
        function img = viewRois(obj, movie_name, resolution)
           img = zeros(resolution);
           ids = obj.getNeuronIDList();
           for i = 1:size(ids,2)
               id = ids{i};
               if obj.neuronExists(id)
                    cur_neuron = obj.getNeuron(id);
                    if cur_neuron.movieExists(movie_name)
                        img(cur_neuron.getROI(movie_name)) = id;
                    else
                        warning(['the neuron with the following id did not have an roi for the following movie: ',...
                            movie_name]);
                    end 
                   
               else
                   warning(['the neuron with the following id was not present: ', num2str(id)]);
               end 
           end
           figure 
           imagesc(img); 
       end
       
       % return the traces as an array
       function traces = getTraces(obj, ids, movie_name)
           n_frames = NaN;
           
           for i=1:size(ids, 2)
               n = obj.getNeuron(ids{i});
               if n.movieExists(movie_name)
                   n_frames = nanmax([max(size(n.getTrace(movie_name))), n_frames]);
                   break
               end
           end
           if isnan(n_frames)
               warning('no traces to return');
               traces = NaN; 
           else
               traces = NaN * ones(size(ids, 2), n_frames);
               for i=1:size(ids, 2)
                   n = obj.getNeuron(ids{i});
                   if n.movieExists(movie_name)
                       traces(i, :) = n.getTrace(movie_name);
                   end
               end
           end
       end
       
       % return the filtered traces as an array
       function traces = getFilteredTraces(obj, ids, movie_name)
           n_frames = NaN;
           
           for i=1:size(ids, 2)
               n = obj.getNeuron(ids{i});
               if n.movieExists(movie_name)
                   n_frames = nanmax([max(size(n.getFilteredTrace(movie_name))), n_frames]);
                   break
               end
           end
           if isnan(n_frames)
               warning('no traces to return');
               traces = NaN; 
           else
               traces = NaN * ones(size(ids, 2), n_frames);
               for i=1:size(ids, 2)
                   n = obj.getNeuron(ids{i});
                   if n.movieExists(movie_name)
                       traces(i, :) = n.getFilteredTrace(movie_name);
                   end
               end
           end
       end
   
       
   end % methods
   
end % class 