function [low_resolution_matrix, X, Y, resolution_km] = climada_resolution_downscale(high_resolution_matrix, resolution_km, specification)
% downscale resolution of input matrix to requested resolution in km
% sum up the data, or take the mean, or take the maximum occurence of
% values
% NAME:
%   climada_resolution_downscale
% PURPOSE:
%   downscale resolution of input matrix to requested resolution in km
%   previous: climada_GDP_distribute
%   next: diverse
% CALLING SEQUENCE:
%   [low_resolution_matrix, X, Y, resolution_km] = climada_resolution_downscale(high_resolution_matrix, resolution_km, specification)
% EXAMPLE:
%   [low_resolution_matrix, X, Y, resolution_km] = climada_resolution_downscale
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   high_resolution_matrix: structure mat-file with the following fields
%                           e.g. values_distributed
%         .values         : distributed values per pixel
%         .lon_range      : range of Longitude
%         .lat_range      : range of Latitude
%         .resolution_x   : resolution in x-direction
%         .resolution_y   : resolution in y-direction
%   resolution_km         : requested resolution in km, if empty, set to 50km
%   specification         : specificy way to determine value for downscaled
%                           resolution, sum up all values with keyword 'sum', 
%                           take average with keyword 'average', take most 
%                           counted value with keyword 'unique', if not
%                           given 'sum' is taken
% OUTPUTS:
%   low_resolution_matrix : structure with same fields as
%                           high_resolution_matrix
%         .values         : values per pixel
%         .lon_range      : range of Longitude
%         .lat_range      : range of Latitude
%         .resolution_x   : resolution in x-direction
%         .resolution_y   : resolution in y-direction
%         .comment        : information 
%  X                      : helper matrix containing Longitude information for
%                           plotting matrix
%  Y                      : helper matrix containing Latitude information for
%                           plotting matrix
%  resolution_km          : requested resolution in km
%
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20120730
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

if ~exist('high_resolution_matrix' , 'var'), high_resolution_matrix  = []; end
if ~exist('resolution_km'          , 'var'), resolution_km           = []; end
if ~exist('specification'          , 'var'), specification           = ''; end

% set modul data directory
modul_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% prompt for high resolution matrix if not given
if isempty(high_resolution_matrix) % local GUI
    high_resolution_matrix         = [modul_data_dir filesep '*.mat'];
    high_resolution_matrix_default = [modul_data_dir filesep 'Choose high resolution matrix .mat'];
    [filename, pathname]           = uigetfile(high_resolution_matrix,  'Choose high resolution matrix .mat:',high_resolution_matrix_default);
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        high_resolution_matrix = fullfile(pathname,filename);
    end
end

if ~isstruct(high_resolution_matrix)
    if ischar(high_resolution_matrix)
        if exist(high_resolution_matrix,'file')
            load(high_resolution_matrix)
        else
            fprintf('Mat file does not exist %s\n', high_resolution_matrix)
            return
        end
    end
    vars = whos('-file', high_resolution_matrix);
    if ~strcmp(vars.name,'high_resolution_matrix')
        high_resolution_matrix = eval(vars.name);
        clear (vars.name)
    end
end

if isempty(resolution_km)
    resolution_km = 50;
end

if isfield(high_resolution_matrix, 'comment')
    comm = high_resolution_matrix.comment;
else
    comm = '';
end

if ~isfield(high_resolution_matrix, 'values')
    low_resolution_matrix = [];
    resolution_km         = [];
    X = []; Y = []; 
    fprintf('Structure does not contain a field "values". Unable to proceed.\n')
    return
end


resolution_x    = sum(abs(high_resolution_matrix.lon_range))/size(high_resolution_matrix.values,2);
resolution_y    = sum(abs(high_resolution_matrix.lat_range))/size(high_resolution_matrix.values,1);
resolution_x_km = climada_geo_distance(0,0,resolution_x,0)/1000;
res_factor      = round(resolution_km/resolution_x_km);
resolution_km   = round(res_factor*resolution_x_km);

[X, Y ] = meshgrid(high_resolution_matrix.lon_range(1)+resolution_x*res_factor/2: resolution_x*res_factor: high_resolution_matrix.lon_range(2)-resolution_x*res_factor/2, ...
                   high_resolution_matrix.lat_range(1)+resolution_y*res_factor/2: resolution_y*res_factor: high_resolution_matrix.lat_range(2)-resolution_y*res_factor/2 );
               
if res_factor == 1
    fprintf('requested resolution (%d km) corresponds already to input matrix (%4.2f km)\n', resolution_km, resolution_x_km)
    low_resolution_matrix = high_resolution_matrix;
    return
end


switch specification 
    case {'sum'; ''}
        % in y_direction and then in x_direction
        for i = 1:size(high_resolution_matrix.values,1)/res_factor
            for j = 1:size(high_resolution_matrix.values,2)/res_factor;               
                val_within_range = high_resolution_matrix.values( (i-1)*res_factor+1:i*res_factor, ...
                                                                  (j-1)*res_factor+1:j*res_factor);
                values_(i,j)     = nansum(val_within_range(:));
            end
        end    
        
    case 'average'
        % in y_direction and then in x_direction
        for i = 1:size(high_resolution_matrix.values,1)/res_factor
            for j = 1:size(high_resolution_matrix.values,2)/res_factor;               
                val_within_range = high_resolution_matrix.values( (i-1)*res_factor+1:i*res_factor, ...
                                                                  (j-1)*res_factor+1:j*res_factor);
                values_(i,j)     = nanmean(val_within_range(:));
            end
        end
        
    case 'unique'      
        % in y_direction and then in x_direction
        for i = 1:size(high_resolution_matrix.values,1)/res_factor
            for j = 1:size(high_resolution_matrix.values,2)/res_factor;
                %fprintf('y-index from %d to %d\n',(i-1)*res_factor+1, i*res_factor)
                %fprintf('x-index from %d to %d\n',(j-1)*res_factor+1, j*res_factor)
                %fprintf('matrix values\n')
                %disp(high_resolution_matrix.values((i-1)*res_factor+1:i*res_factor, (j-1)*res_factor+1:j*res_factor))
                
                val_within_range = high_resolution_matrix.values( (i-1)*res_factor+1:i*res_factor, ...
                                                                  (j-1)*res_factor+1:j*res_factor);
                val_counts   = accumarray(val_within_range(:)+1, 1);
                [max_c val]  = max(val_counts); 
                values_(i,j) = val-1;
            end
        end   
end

low_resolution_matrix              = [];
low_resolution_matrix.values       = values_;
low_resolution_matrix.lon_range    = high_resolution_matrix.lon_range;
low_resolution_matrix.lat_range    = high_resolution_matrix.lat_range;
low_resolution_matrix.resolution_x = resolution_x*res_factor;
low_resolution_matrix.resolution_y = resolution_y*res_factor;
low_resolution_matrix.comment      = [comm ', ' int2str(resolution_km) 'km, ' specification];



%% for sparse matrix
% [i j x]    = find(high_resolution_matrix.values);
% % new_size_y = floor(size(high_resolution_matrix.values,1)/res_factor);
% % new_size_x = floor(size(high_resolution_matrix.values,2)/res_factor);
% % max(i); max(j)
% i_round = floor((i-1)/res_factor)+1;
% j_round = floor((j-1)/res_factor)+1;
% counter = 0;
% i_new   = []; j_new = []; x_new = [];
% uni_i_round = unique(i_round);
% 
% h = waitbar(0,'waitbar');
% 
% for f = 1:length(uni_i_round)
%     l1 = uni_i_round(f) == i_round;
%     j_uni = unique(j_round(l1));
%     for g = 1:length(j_uni)
%         l2 = l1 & j_uni(g) == j_round;
%         %find(l2)
%         %i_ = find(i_round(l2),'first');
%         %j_ = find(j_round(l2),'first');
%         %j_round(l2)
%         counter = counter+1;
%         i_new = [i_new max(i_round(l2))];
%         j_new = [j_new max(j_round(l2))];
%         x_new = [x_new sum(x(l2))];
%     end 
%     h = waitbar(f/length(uni_i_round), h, sprintf('%d rows from %d processed',f, length(uni_i_round)));
% end
% 
% close(h)
% 
% low_resolution_matrix.values       = sparse(i_new,j_new,x_new);
% low_resolution_matrix.lon_range    = high_resolution_matrix.lon_range;
% low_resolution_matrix.lat_range    = high_resolution_matrix.lat_range;
% low_resolution_matrix.resolution_x = resolution_x*res_factor;
% low_resolution_matrix.resolution_y = resolution_y*res_factor;
% low_resolution_matrix.comment      = [comm ', ' int2str(resolution_km) 'km, ' specification];


% i_new = []; j_new = []; x_new = [];
% h = waitbar(0,'waitbar');
% for ii = 1:new_size_y
%     %(ii-1)*res_factor+1:ii*res_factor
%     for jj = 1:new_size_x
%         l1 = (  i >= (ii-1)*res_factor+1 & i <= ii*res_factor ...
%               & j >= (jj-1)*res_factor+1 & j <= jj*res_factor);
%         %i(l1)
%         %j(l1)
%         if any(l1)
%             i_new = [i_new ii];
%             j_new = [j_new jj];
%             x_new = [x_new sum(x(l1))];
%         end
%     end
%     h = waitbar(ii/new_size_y, h, sprintf('%d rows from %d processed',ii, new_size_y));
% end


               
     
               
               