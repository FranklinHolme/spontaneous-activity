% Builds a table of neurons that includes metadata from the experiment and
% the traces, along with the original neuron objects
function [d] = buildNeuronTable(guide_name, max_frames, max_neurons_per_fov)
    
    % Load the data guide spreadsheet
    g = readtable(guide_name); 
    
    % Manual exclusion of datasets 
    g = g(logical(g.include), :); 
    
    % Set up an array to hold the neurons and corresponding rows of the
    % data guide
    neurons = []; 
    g_rows = []; 
    
    % For each row of the data guide spreadsheet... 
    for r = 1:length(g.data_name)
        
        if iscell(g.data_name)
            
            if ~isempty(g.data_name{r})
        
                % Load the fov
                f = load([g.data_name{r}, '.mat']);
                f = f.dataset;

                % Iterate over the neuron objects
                ids = f.getNeuronIDList();
                for i = 1:min([length(ids), max_neurons_per_fov])

                      neurons = [neurons, f.getNeuron(ids{i})];
                      g_rows = [g_rows, r];
                     
                end
            end 
        end 
    end 
    
    % Pre allocate a table to hold all the neurons
    var_names = {'date', 'genotype', 'drug', 'data_name', 'event_stats_name',...
        'neuron_id', 'neuron_object', 'framerate', 'distribution'}; 
    var_types = {'double', 'string', 'string', 'string', 'string'...
        'double', 'neuron', 'double', 'string'};
    sz = [length(neurons) length(var_names)];
    d = table('Size', sz, 'VariableTypes', var_types, 'VariableNames', var_names);    
    
    % Pre-allocate arrays to hold traces, filtered traces, stimulus frames,
    % stimulus irradiance, peak amplitudes, and locations of those peaks
    d.trace = NaN * ones(length(neurons), max_frames);
    d.filt_trace = NaN * ones(length(neurons), max_frames);

    
    % For each neuron, fill in a row of the table
    for i = 1:length(neurons)
        
        n = neurons(i); 
        r = g_rows(i); 
        
        % Metadata from the data guide table
        d.date(i) = g.date(r);
        d.genotype{i} = g.genotype{r};
        d.drug{i} = g.drug{r};   
        d.data_name{i} = g.data_name{r};
        d.event_stats_name{i} = g.event_stats_name{r}; 
        d.framerate(i) = g.framerate(r);  
        d.distribution{i} = g.distribution{r};
        d.figure{i} = g.figure{r};
        
        % Give each neuron a new, unique identifier 
        d.neuron_id(i) = 100 * g.FOV_id(r) + i; 
        
        d.neuron_object{i} = n; 
        
        % Extract the neuron's data 
        trace = n.getTrace(g.movie_name{r});
        filt_trace = n.getFilteredTrace(g.movie_name{r});
        
        d.trace(i, 1:length(trace)) = trace;
        d.filt_trace(i, 1:length(filt_trace)) = filt_trace;
        d.f0(i) = n.getF0(g.movie_name{r}); 
        
    end 
    
end 



