function [out_vector] = measureBinaryComponents(in_vector)

% For a binary input vector, returns a new vector with measurements of the
% length of each connected component. 
% in: [1 0 1 1 0 1 1 1] 
% out: [1 2 3]

    component_idx = 0; 
    measuring_component = false; 
    out_vector = zeros(1, length(in_vector)); 
    for i = 1:size(in_vector, 2)
        
        % In a component 
        if in_vector(i) == 1 
            
            % If not already measuring this component 
            if ~measuring_component 
                
                component_idx = component_idx + 1; 
                measuring_component = true; 
                
            end 
            
            out_vector(component_idx) = out_vector(component_idx)+ 1; 
            
        else
            
            measuring_component = false; 
            
        end 
    end 
    out_vector = out_vector(1:component_idx); % only return the used portion
end 