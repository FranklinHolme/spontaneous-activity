% Extracts filtered traces from all the neurons in the first movie at the field of
% view
function [traces] = getFirstMovieTraces(fov, trace_type)

    movie_list = fov.getFullMovieList();
    movie = movie_list{1};
    
    switch trace_type 
        
        case 'traces'
            
              traces = fov.getTraces(fov.getNeuronIDList(), movie);
            
        case 'filt_traces'
    
              traces = fov.getFilteredTraces(fov.getNeuronIDList(), movie);
              
        otherwise 
            
            warning(['Unknown trace type String: ', cast(trace_type, 'String')]); 
                  
    end 
    
end 