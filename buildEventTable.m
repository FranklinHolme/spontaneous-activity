function [e] = buildEventTable(n)

    amps = [];
    durs = []; 
    aucs = []; 
    ieis = [];
    pkframes = [];
    genotype = {};
    drug = {};
    data_name = {}; 
    distribution = {}; 
    id = []; 
    date = []; 
    figure = {};

    % Aggregate the data for individual events into arrays
    for i = 1:size(n, 1)
        
        disp(['Adding ', n.data_name{i}, ' neuron ', num2str(n.neuron_id(i)), ' to event table']);
        
        % Get the event statistics for this neuron 
        [amp, missing_idxs] = rmmissing(n.amplitude(i, :));
        amps = [amps, amp];
        
        dur = n.duration(i, ~missing_idxs);
        durs = [durs, dur]; 
        
        auc = n.auc(i, ~missing_idxs);
        aucs = [aucs, auc]; 
        
        pkframe = n.pk_frames(i, ~missing_idxs);
        pkframes = [pkframes, pkframe]; 
        
        if length(pkframe) > 1
            iei = [NaN, diff(pkframe)] ./ n.framerate(i);
        elseif length(pkframe) == 1
            iei = [NaN];
        elseif isempty(pkframe)
            iei = [];
        end
        ieis =  [ieis, iei];
        
        if length(iei) ~= length(pkframe)
            disp('Length of IEI and peak frame arrays do not match!');
        end
        
        % Aggregate the metadata
        for j = 1:length(amp)
            genotype = [genotype, n.genotype(i)];
            drug = [drug, n.drug(i)];
            id = [id, n.neuron_id(i)]; 
            date = [date, n.date(i)];
            data_name = [data_name, n.data_name(i)]; 
            distribution = [distribution, n.distribution(i)];
            figure = [figure, n.figure(i)];
        end 
        
    end
    
    % Build the event table 
    var_names = {'date', 'genotype', 'drug',...
        'neuron_id', 'amplitude', 'duration', 'pk_frame', 'iei'}; 
    var_types = {'double', 'string', 'string',...
        'double', 'double', 'double', 'double', 'double'};
    sz = [length(amps) length(var_names)];
    e = table('Size', sz, 'VariableTypes', var_types, 'VariableNames', var_names);    
    e.date = date';
    e.genotype = genotype';
    e.drug = drug'; 
    e.neuron_id = id'; 
    e.amplitude = amps';
    e.duration = durs'; 
    e.pk_frame = pkframes';
    e.iei = ieis';
    e.auc = aucs'; 
    e.data_name = data_name';
    e.distribution = distribution';
    e.figure = figure';

end 