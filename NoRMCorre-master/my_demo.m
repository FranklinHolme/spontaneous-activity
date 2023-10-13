clear
gcp;

name = '200123002.tif';

tic; Y = read_file(name); toc; % read the file (optional, you can also pass the path in the function instead of Y)
Y = single(Y);                 % convert to single precision 
T = size(Y,ndims(Y));
Y = Y - min(Y(:));

% Guide to parameters here: https://github.com/flatironinstitute/NoRMCorre/blob/master/README.md

%% rigid motion correction
options_rigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'bin_width',400,'max_shift',10,'us_fac',50,'init_batch',400);
tic; [M1,shifts1,template1,options_rigid] = normcorre(Y,options_rigid); toc

%% non-rigid motion correction
% options_nonrigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'grid_size',[64,64],'mot_uf',4,'bin_width',400,'max_shift',15,'max_dev',3,'us_fac',50,'init_batch',400);
% tic; [M2,shifts2,template2,options_nonrigid] = normcorre_batch(Y,options_nonrigid); toc

%% Save nonrigid registration 
[file_path, file_name, file_extension] = fileparts(name);
saveastiff(M1, [file_name, '_reg_', file_extension]); 
