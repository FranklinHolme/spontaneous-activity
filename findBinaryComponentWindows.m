function [windows] = findBinaryComponentWindows(in_vector)

% For a binary input vector, returns a new vector with the start and end 
% indeces of each component. 
% in: [1 0 1 1 0 1 1 1] 
% out: [1 1; 3 4; 6 8]

    % Measure the length of the components 
    component_lengths = measureBinaryComponents(in_vector);

    component_idx = 0; 
    measuring_component = false; 
    windows = NaN * ones(length(component_lengths), 2); 
    for i = 1:length(in_vector) 
        
        % In a component 
        if in_vector(i) == 1 
            
            % If not already measuring this component 
            if ~measuring_component 
                
                component_idx = component_idx + 1; 
                measuring_component = true; 
                
                % Record the start and end index
                windows(component_idx, 1) = i; 
                windows(component_idx, 2) = i + component_lengths(component_idx) - 1; 

            end 
            
        else
            
            measuring_component = false; 
            
        end 
        
    end 
    
end 