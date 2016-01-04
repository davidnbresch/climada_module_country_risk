function matrix_buffer = climada_mask_buffer_hollow(matrix, no_pixel_buffer, no_pixel_hollow, border_mask, ...
                                                    check_figure, check_printplot, printname, cbar_label, no_wbar)
% create buffer around country (matrix masking 1 for onland (or higher 
% values if more than one country), 0 for sea, max value for bufferzone)
% NAME:
%   climada_bufferzone
% PURPOSE:
%   create buffer around country
%   previous: diverse
%   next: climada_mask_hollowout, climada_matrix2centroid
% CALLING SEQUENCE:
%   matrix_buffer = climada_bufferzone(matrix, no_pixel, border_mask,
%   check_figure, check_printplot, printname, cbar_label)
% EXAMPLE:
%   matrix_buffer = climada_bufferzone(matrix, 5)
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   matrix          : matrix masking 1 for on land, and zero for sea
%                     (e.g.border_mask.mask{1}), max value for buffer
%   no_pixel_buffer : no of pixel that mask the bufferzone around the
%                     country/countries
%   no_pixel_hollow : no of pixel that mask the bufferzone around the
%                     country/countries. Set to 0 if no hollowout is needed.
%   border_mask     : structure containg all country masks, including field
%                     .world_mask (1 for on land, and 0 for sea)
%   check_figure    : set to 1 to show figure distributed GDP
%   check_printplot : set to 1 to save figure
%   printname       : string for title and for filename if saved
%   cbar_label      : label for colorbar (ISO3 codes for country names)
%   no_wbar         : 1 for not waitbar, otherwise waitbar will show up
% OUTPUTS:
%   matrix_buffer   : matrix masking 1 for on land, zero for on sea, and
%                     max value for bufferzone
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20120730
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

if ~exist('matrix'          , 'var'), matrix_buffer   = []; return; end
if ~exist('no_pixel_buffer' , 'var'), no_pixel_buffer = []; end
if ~exist('no_pixel_hollow' , 'var'), no_pixel_hollow = []; end
if ~exist('border_mask'     , 'var'), border_mask     = []; end
if ~exist('check_figure'    , 'var'), check_figure    = 1 ; end
if ~exist('check_printplot' , 'var'), check_printplot = []; end
if ~exist('printname'       , 'var'), printname       = ''; end
if ~exist('cbar_label'      , 'var'), cbar_label      = ''; end
if ~exist('no_wbar'         , 'var'), no_wbar         = ~climada_global.waitbar; end

% set modul data directory
modul_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];


if isempty(no_pixel_buffer)
    no_pixel_buffer = 3;
end

if isempty(no_pixel_hollow)
    no_pixel_hollow = no_pixel_buffer*3;
end

% % copy original matrix 
% matrix_ori    = matrix;
% matrix_ori(matrix_ori>1) = 1;

if isempty(border_mask)
    border_mask_file = [modul_data_dir filesep 'border_mask_10km.mat'];
    if exist(border_mask_file,'file')
        load(border_mask_file)
    else
        fprintf('No border mask found, can"t find sea borders.\n')
    end
end
if ~isempty(border_mask)
    if isfield(border_mask,'world_mask')
        world_mask = border_mask.world_mask;
    else
        fprintf('\t\tCreating world mask to identify sea borders...')
        world_mask = zeros(size(border_mask.mask{1}));
        for co_i = 1:length(border_mask.mask)
            world_mask = world_mask + border_mask.mask{co_i};
        end
        world_mask(world_mask>1) = 1;
        
        % add to border_mask structure and save in globalGDP data directory
        border_mask.world_mask   = world_mask;
        border_mask_file         = [modul_data_dir filesep 'border_mask_10km.mat'];
        save(border_mask_file, 'border_mask');
        fprintf('and saved\n')
    end
    % downscale resolution of world mask to be in line with input matrix
    res_x       = sum(abs(border_mask.lon_range))/size(matrix,2);
    res_x_km    = round(climada_geo_distance(0,0,res_x,0)/1000);
    world_struct.values    = world_mask;
    world_struct.lon_range = border_mask.lon_range;
    world_struct.lat_range = border_mask.lat_range;
    world_struct           = climada_resolution_downscale(world_struct, res_x_km, 'unique');
    world_mask             = world_struct.values;
end

if iscell(cbar_label)
    bufferzone_value = length(cbar_label)+1;
else
    bufferzone_value = max(matrix(:))+1;
end

% -----1) find pixel at coast----------
nonzero_index = matrix>0;
matrix_ = matrix;
matrix_(matrix_>0) = 1;

% find pixel on the border
p_i   = 1;
right = [matrix_(:,p_i+1:end) zeros(size(nonzero_index,1),p_i)];
top   = [matrix_(p_i+1:end,:); zeros(p_i,size(nonzero_index,2))];

diff_right = matrix_-right; diff_right(diff_right<0) = 1; 
diff_top   = matrix_-top  ; diff_top(diff_top<0)     = 1;
border_pix = diff_right + diff_top;
border_pix(border_pix>1) = 1; 
% imagesc(border_mask.lon_range-res_x/2, border_mask.lat_range-res_x/2, border_pix)
% climada_plot_world_borders



% -----2) initialize buffer matrix----------
buffer      = zeros(size(border_pix));
no_pixel    = no_pixel_buffer;
waitbar_tot = no_pixel*2+no_pixel^2*4;
if ~no_wbar
    h = waitbar(0, sprintf('Go through %i shift of masks', waitbar_tot),'Name', 'Create buffer around country mask');
end

%identify neighbouring pixel - horizontally and vertically
for p_i = 1:no_pixel
    buffer = buffer + [border_pix(:,p_i+1:end) zeros(size(nonzero_index,1),p_i)];
    buffer = buffer + [border_pix(p_i+1:end,:); zeros(p_i,size(nonzero_index,2))];
end
if ~no_wbar, waitbar(no_pixel/waitbar_tot,h), end
for p_i = 1:no_pixel
    buffer = buffer + [zeros(size(nonzero_index,1),p_i) border_pix(:,1:end-p_i)];
    buffer = buffer + [zeros(p_i,size(nonzero_index,2)); border_pix(1:end-p_i,:)];
end
if ~no_wbar, waitbar(2*no_pixel/waitbar_tot,h), end

% diagonal 1: top right
for p_i = 1:no_pixel  
    for p2_i = 1:no_pixel
        buffer = buffer + [zeros(p2_i,size(border_pix,2)); ...
                           zeros(size(border_pix,1)-p2_i,p_i) border_pix(1:end-p2_i, 1:end-p_i)];  
    end
end 
if ~no_wbar, waitbar((2*no_pixel+no_pixel^2)/waitbar_tot,h), end

% diagonal 2: top left
for p_i = 1:no_pixel    
    for p2_i = 1:no_pixel
        buffer = buffer + [zeros(p2_i,size(border_pix,2)); ...
                           border_pix(1:end-p2_i,1+p_i:end) zeros(size(border_pix,1)-p2_i,p_i) ];  
    end
end 
if ~no_wbar, waitbar((2*no_pixel+2*no_pixel^2)/waitbar_tot,h), end
% diagonal 3: bottom left 
for p_i = 1:no_pixel    
    for p2_i = 1:no_pixel
        buffer = buffer + [border_pix(p2_i+1:end,p_i+1:end) zeros(size(border_pix,1)-p2_i,p_i);...
                           zeros(p2_i,size(border_pix,2))];  
    end
end 
if ~no_wbar, waitbar((2*no_pixel+3*no_pixel^2)/waitbar_tot,h), end
% diagonal 4: bottom right   
for p_i = 1:no_pixel    
    for p2_i = 1:no_pixel
        buffer = buffer + [zeros(size(border_pix,1)-p2_i,p_i) border_pix(p2_i+1:end,1:end-p_i) ;...
                           zeros(p2_i,size(border_pix,2))];  
    end
end 
if ~no_wbar
    waitbar((2*no_pixel+4*no_pixel^2)/waitbar_tot,h)
    close(h) % close waitbar
end


% --- 3) fill buffer with bufferzone value-----
buffer(buffer>= 1) = bufferzone_value;
buffer_ori         = buffer;
% if not sea, take out of bufferzone
if exist('world_mask','var')
    buffer(logical(world_mask)) = 0;
end

if ~any(buffer(:))
    fprintf('\t\t %s not at coast, no coast buffer needed\n',char(cbar_label(:)))
    no_pixel_hollow = 0;
end


% 4) ----HOLLOW OUT----
if no_pixel_hollow > 0
    % identify sea border
    no_pixel    = no_pixel_hollow;
    hollow      = zeros(size(buffer));
    waitbar_tot = no_pixel*2+no_pixel^2*4;
    if ~no_wbar
        h = waitbar(0, sprintf('Go through %i shift of masks', waitbar_tot),'Name', 'Hollow out country mask');
    end

    %identify neighbouring pixel - horizontally and vertically
    for p_i = 1:no_pixel
        hollow = hollow + [buffer(:,p_i+1:end)  zeros(size(nonzero_index,1),p_i)];
        hollow = hollow + [buffer(p_i+1:end,:); zeros(p_i,size(nonzero_index,2))];
    end
    if ~no_wbar, waitbar(no_pixel/waitbar_tot,h), end
    
    for p_i = 1:no_pixel
        hollow = hollow + [zeros(size(nonzero_index,1),p_i)  buffer(:,1:end-p_i)];
        hollow = hollow + [zeros(p_i,size(nonzero_index,2)); buffer(1:end-p_i,:)];
    end
    if ~no_wbar, waitbar(2*no_pixel/waitbar_tot,h), end

    % diagonal 1: top right
    for p_i = 1:no_pixel  
        for p2_i = 1:no_pixel
            hollow = hollow + [zeros(p2_i,size(buffer,2)); ...
                               zeros(size(buffer,1)-p2_i,p_i) buffer(1:end-p2_i, 1:end-p_i)];  
        end
    end 
    if ~no_wbar, waitbar((2*no_pixel+1*no_pixel^2)/waitbar_tot,h), end
    
    % diagonal 2: top left
    for p_i = 1:no_pixel    
        for p2_i = 1:no_pixel
            hollow = hollow + [zeros(p2_i,size(buffer,2)); ...
                               buffer(1:end-p2_i,1+p_i:end) zeros(size(buffer,1)-p2_i,p_i) ];  
        end
    end 
    if ~no_wbar, waitbar((2*no_pixel+2*no_pixel^2)/waitbar_tot,h), end
    
    % diagonal 3: bottom left 
    for p_i = 1:no_pixel    
        for p2_i = 1:no_pixel
            hollow = hollow + [buffer(p2_i+1:end,p_i+1:end) zeros(size(buffer,1)-p2_i,p_i);...
                               zeros(p2_i,size(buffer,2))];  
        end
    end 
    if ~no_wbar, waitbar((2*no_pixel+3*no_pixel^2)/waitbar_tot,h), end
    
    % diagonal 4: bottom right   
    for p_i = 1:no_pixel    
        for p2_i = 1:no_pixel
            hollow = hollow + [zeros(size(buffer,1)-p2_i,p_i) buffer(p2_i+1:end,1:end-p_i) ;...
                               zeros(p2_i,size(buffer,2))];  
        end
    end 
    if ~no_wbar
        waitbar((2*no_pixel+4*no_pixel^2)/waitbar_tot,h)
        close(h) % close waitbar
    end
 
    hollow(hollow>1) = 1;
    hollow_ori       = hollow;
    hollow(matrix<1) = 0; %take away all pixel that are not within country (original matrix)
    
    % within buffer but not on sea
    %hollow_ori = hollow_ori - matrix;     hollow_ori(hollow_ori<0) = 0;
    %buffer     = hollow_ori + buffer_ori; buffer(buffer<max(buffer(:))) = 0;
    % end buffer around sea pixel, corresponds to hollowout matrix
else
    hollow = logical(matrix); 
end


% put hollowout and buffer together into matrix_buffer
matrix_buffer = zeros(size(buffer));
matrix_buffer(logical(buffer)) = buffer(logical(buffer));
matrix_buffer(logical(hollow)) = matrix(logical(hollow));



if check_figure
    fig_width       = 162+180;
    fig_height      = 60+77;
    fig_relation    = fig_height/fig_width;
    fig_height_     = 1.2;
    fig             = climada_figuresize(fig_height_*fig_relation,fig_height_);

    % find minimum and maximum of longitude, latitude for axis limits  
    if ~exist('res_x','var'); res_x = border_mask.resolution_x; end
    [X, Y ]         = meshgrid(border_mask.lon_range(1)+res_x/2: res_x: border_mask.lon_range(2)-res_x/2, ...
                               border_mask.lat_range(1)+res_x/2: res_x: border_mask.lat_range(2)-res_x/2);              
    nonzero_index   = matrix_buffer>0;
    delta           = 2;
    axislim         = [min(X(nonzero_index))-delta  max(X(nonzero_index))+delta ...
                       min(Y(nonzero_index))-delta  max(Y(nonzero_index))+delta];
    
    set(gca,'ydir','normal','layer','top')
    hold on
    colormap([1 1 1;...
              jet(bufferzone_value-1);...
              [205 193 197 ]/255])
    %imagesc([min(X(:)) max(X(:))], [min(Y(:)) max(Y(:))], matrix_buffer)
    imagesc([min(X(:)) max(X(:))], [min(Y(:)) max(Y(:))], values_distributed.values)
    
    climada_plot_world_borders
    axis equal
    axis(axislim)
    %plot(X(nonzero_index), Y(nonzero_index), '.k','color',[234 234 234]/255)
    title(strrep(printname,'_',', '))
    if iscell(cbar_label)
        for i = 1:length(cbar_label)
            cbar_label_{i} = sprintf('%d: %s', i, cbar_label{i});
        end
        cbar_label_ = [cbar_label_ [int2str(bufferzone_value) ': Buffer']];
        caxis([0 bufferzone_value+1])
        t = colorbar('YTick',0.5:1:bufferzone_value+0.5,'yticklabel',['0: Sea' cbar_label_],'fontsize',7); %'ylim',[0 max()]
    else
        t = colorbar('YTick',0:1:bufferzone_value,'yticklabel',{'0: Sea','1: Land','2: Buffer'},'fontsize',12);
    end
    
    if check_printplot %(>=1)   
        foldername = [filesep 'results' filesep 'Buffer_' printname '.pdf'];
        print(fig,'-dpdf',[climada_global.data_dir foldername])
        %close
        cprintf([255 127 36 ]/255,'\t\t Save 1 FIGURE in folder ..%s \n', foldername);
    end
end




