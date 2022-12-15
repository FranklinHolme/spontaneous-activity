% This function is designed for calcium imaging at cellular resolution. 
% The code reads in a data guide spreadsheet that lists fields of view and movies. 
% For movies that do not already have processed data associated with them, 
% this code will load the movie and generate a delta F/F. It will then load ROIs
% and extract fluorescence traces for individual cells. Data will be stored in 
% a set of 'fov' (field of view) objects that contain 'neuron' objects. 
% This function works with MATLAB 2018a and 2021a but has not been tested with earlier versions. 

function [d] = processMovies(data_guide_name)

    % Detect import options for the data guide spreadsheet
    opts = detectImportOptions(data_guide_name);
    
    % Ensure that the 'data_name' column of the table is a string array
    opts = setvartype(opts,{'data_name', 'event_stats_name'}, {'string', 'string'});

    % Load the data guide spreadsheet as a table 
    d = readtable(data_guide_name, opts); 
    
    % Name the experimental groups ('distribution column') 
    distribution = cell(size(d.genotype));
    distribution(:) = {'NA'};
    rapamycin = strcmp(d.drug, 'Rapamycin');
    etoh = strcmp(d.drug, 'EtOH');
    aav_ctrl = strcmp(d.drug, 'AAV9-shCntrol');
    aav = strcmp(d.drug, 'AAV9-shRptor');
    no_manip = strcmp(d.drug, '') | strcmp(d.drug, 'Rapamycin_control');
    wt_supp = strcmp(d.genotype, 'Tsc1 wt') & ~strcmp(d.figure, 'main');
    wt_main = strcmp(d.genotype, 'Tsc1 wt') & strcmp(d.figure, 'main');

    % For genotype-only comparisons
    distribution(wt_main & no_manip) = {'1. wt main'};
    distribution(wt_supp & no_manip) = {'1. wt supp'};
    distribution(strcmp(d.genotype, 'Tsc1 het') & no_manip) = {'2. het'};
    distribution(strcmp(d.genotype, 'Tsc1 ko') & no_manip) = {'3. ko'};
    distribution(strcmp(d.genotype, 'Tsc1 ko; Rptor het') & no_manip) = {'4. ko; Rptor het'};

    % Drug experiments
    distribution(strcmp(d.genotype, 'Tsc1 wt') & etoh) = {'5. wt; EtOH'};
    distribution(strcmp(d.genotype, 'Tsc1 ko') & etoh) = {'7. ko EtOH'};
    distribution(strcmp(d.genotype, 'Tsc1 wt') & rapamycin) = {'6. wt; Rapamycin'};
    distribution(strcmp(d.genotype, 'Tsc1 ko') & rapamycin) = {'8. ko; Rapamycin'};

    % Virus experiments
    distribution(strcmp(d.genotype, 'Tsc1 wt') & aav_ctrl) = {'9. wt; shCtrl'};
    distribution(strcmp(d.genotype, 'Tsc1 ko') & aav_ctrl) = {'92. ko; shCtrl'};
    distribution(strcmp(d.genotype, 'Tsc1 wt') & aav) = {'91. wt; ShRptor'};
    distribution(strcmp(d.genotype, 'Tsc1 ko') & aav) = {'93. ko; shRptor'};

    d.distribution = distribution;

    % Iterate over the movies referenced in each row of the data guide
    for i = 1:size(d,1)         

        % If there is not already a dataset for this movie and the data
        % should be included
        if ismissing(d.data_name(i)) && d.include(i)   
            
            % Let the user know
            disp(['Dataset not found for ', d.movie_name{i}, ', making a new one']); 
            
            % Go to the path 
            cd(d.path{i}); % getting rid of this could cause unintended effects if any of the movie
            %names are shared! 
            
            
            %% Preprocessing. 
            if ~d.preprocessed(i) 
                
                % Check if movie is interleaved 
                if tableHasColumn(d, 'interleaved') 
                    is_interleaved = d.interleaved(i);  
                else
                    is_interleaved = 0; 
                end
                
                % Load the movie
                tic;
                [fmovie, fmovie_c2] = loadMovie(d.movie_name{i}, is_interleaved); 
                disp([num2str(toc), ' sec to load the movie']); 

                % Crop the image. Used currently to remove the stimulus
                % artifact at the left and right edges of the movie frame.
                if tableHasColumn(d, 'crop_rect')
                    if ~isempty(d.crop_rect{i})
                        crop_rect = eval(d.crop_rect{i}); 
                        fmovie = cropMovie(fmovie, crop_rect); 
                    end 
                end 
                
                % Bleach correction is done on traces, never on the image.
                % Maybe it would be better to do it here on the image so we
                % can visualize the effects ourselves using the preprocessed
                % saved movie. 

                % Motion correction using NormCorre from https://github.com/flatironinstitute/NoRMCorre 
                options_nonrigid = NoRMCorreSetParms('d1',size(fmovie,1),'d2',...
                    size(fmovie,2),'grid_size',[64,64],'mot_uf',4,...
                    'bin_width',400,'max_shift',15,'max_dev',3,'us_fac',50,'init_batch',400);
                tic; [fmovie, shifts2, fmovie_template, motion_options] = normcorre_batch(fmovie,options_nonrigid); toc 

                % Save the preprocessed movie 
                [pathstr, name, ext] = fileparts(d.movie_name{i});
                fname = [pathstr, name, '_preprocessed', ext]; 
                if ~isfile(fname)
                    saveastiff(uint32(fmovie), fname);
                end 

                % Record that the movie has now been preprocessed 
                d.preprocessed(i) = 1; 

                % Save the template image 
                fname = [pathstr, name, '_template', ext]; 
                if ~isfile(fname)
                    saveastiff(uint32(fmovie_template), fname);
                end 

                % If there is a second channel with a static signal (e.g.
                % tdTomato), crop and register it in the same way as the
                % dynamic channel and save it. 
                if tableHasColumn(d, 'interleaved')
                    if d.interleaved(i)
                        
                        % Crop
                        if ~isempty(d.crop_rect{i})
                            fmovie_c2 = cropMovie(fmovie_c2, crop_rect);
                        end
                        
                        % Apply shifts from the motion correction of channnel 1
                        fmovie_c2 = apply_shifts(fmovie_c2, shifts2, motion_options);
                        
                        % Save the motion-corrected cropped stack
                        fname = [pathstr, name, '_channel_2', ext];
                        if ~isfile(fname)
                            saveastiff(uint32(fmovie_c2), fname);
                        end
                        
                        % Save a mean projection also
                        fname = [pathstr, name, '_channel_2_mean', ext];
                        if ~isfile(fname)
                            saveastiff(uint32(mean(fmovie_c2, 3)), fname);
                        end
                    end
                end                               
            end 
                
            % Process the movie to create the dataset if there are ROIs 
            if ~isempty(d.roi_name{i})
                
                % Loads the movie
                tic;
                [pathstr, name, ext] = fileparts(d.movie_name{i});
                full_movie_name = [pathstr, name, '_preprocessed', ext]; 
                [fmovie, ~] = loadMovie(full_movie_name, false); 
                disp([num2str(toc), ' sec to load movie: ', full_movie_name]); 
                
                dataset = processMovie(d, fmovie, i);

                % Update the table with the name of the dataset
                d.data_name(i) = nameDataset(d, i);

                % Save the dataset
                tic;
                saveDataset(dataset, d, i);
                disp(['Took ', num2str(toc), ' sec to save the dataset']); 
                
            else 
                warning(['ROI names not provided in data guide for movie: ', d.movie_name{i}]);
            end 
            
            % Save the updated spreadsheet as a new version within whatever
            % directory matlab is pointed to when this function is called.
            % The saving is more often than strictly necessary, but it
            % helps keep the spreadsheet updated in case one of the movies
            % crashes this program.
            saveSpreadsheet(d, data_guide_name);
            
        end
        
        saveSpreadsheet(d, data_guide_name); 
        
    end
    
end 

% Saves an updated version of the data guide spreadsheet
function [] = saveSpreadsheet(d, data_guide_name)

    % Get the parts of the data guide spreadsheet's filename
    [filepath,name,ext] = fileparts(data_guide_name);
    
    % Go to the path
    cd(filepath); 
    
    % Save the new spreadsheet in the same path with the same extension
    writetable(d, [name, '_updated', ext]); 
end

% Processes a movie to generate a fov dataset. For now, fields of view and
% movies are equivalent. The implication of this is that the analysis
% pipeline currently allows for only one movie per field of view, so no
% registration of the same neurons between multiple movies. 
function [fov] = processMovie(d, fmovie, i)

    % Create a new field of view object with the required information:
    % date and acquisition number
    fov = FOV(num2str(d.acq_n(i)), d.date(i));

    % Loads imageJ ROIs for the Neurons in the FOV
    rois = loadROIs(d, i);

    % Adds neurons to the FOV object
    tic;
    fov = addNeurons(d.movie_name{i}, fov, rois, fmovie);
    disp([num2str(toc), ' sec to generate Neuron objects']);

end

% Adds neurons to a FOV 
function [fov] = addNeurons(movie_name, fov, rois, fmovie)

    % Get traces (what are the dimensions of the array?) and a mask of the rois 
    [dfoverf0s, corrected_dfoverf0s, f0s, rois_mask] = getRoiTraces_Cultured(fmovie, rois); 
    
    % Neuron IDs will be their numbering in the ROI mask
    ids = unique(rois_mask);
    
    % The background of the mask has 0, don't use this as an ID
    ids = ids(ids~= 0); 
    
    % For each ID
    for i = 1:length(ids)
        id = ids(i);
        
        % Find the linear indices of the ROI 
        roi_lin_indeces = find(rois_mask == id); 
        
        % Create the neuron object  
        n = neuron(id);
        
        % Add a movie to the neuron object 
        n.addMovie(movie_name, roi_lin_indeces, dfoverf0s{i}, corrected_dfoverf0s{i}, f0s(i));
        
        % Add the neuron to the field of view object
        fov.addNeuron(n);
    end
        
end

% Loads a calcium imaging movie 
function [fmovie, fmovie_c2] = loadMovie(filename, interleaved)
    
    fmovie = readTifStack(filename); 
    
    % If the movie has more than 4 dimensions, the script will break later
    % on. Try to squeeze out the extra dimension and provide a warning. 
    if length(size(fmovie)) > 3 
        fmovie = squeeze(fmovie); 
        warning('Movie had more than 3 dimensions! Squeezing attempted.');
    end 
    
    % Separate the two channels of an interleaved stack. Right now, it 
    % does not save the second channel. 
    if interleaved
        [fmovie, fmovie_c2] = deinterleave(fmovie); 
    else
        fmovie_c2 = NaN;
    end 
    
end

% Loads a set of ROIs from imageJ, then return a mask
function [rois] = loadROIs(d, i)
    
    % Call a function that reads imageJ's circular ROIs and generates a
    % mask
    rois = ReadImageJROI(d.roi_name{i});
    
end

% Saves a dataset within the path specified in the data guide table 
function [] = saveDataset(dataset, d, i)

    % Go to the data path
    cd(d.path{i}); 

    % Save the dataset
    save(strcat(d.movie_name{i}, '.mat'), 'dataset'); 
end

% Names a dataset according to the date and acquisition number associated
% with the dataset in the table. 
function [name] = nameDataset(d, i)
    name = d.movie_name{i};
end 
    
% Crops each frame of a movie 
function [out_movie] = cropMovie(in_movie, crop_rect)

    % Crop the first frame
    out_frame = imcrop(in_movie(:,:,1), crop_rect);
    
    out_movie = NaN * ones(size(out_frame, 1), size(out_frame, 2), size(in_movie, 3)); 
    for i = 1:size(in_movie, 3)
        out_movie(:,:,i) = imcrop(in_movie(:,:,i), crop_rect); 
    end 
end












