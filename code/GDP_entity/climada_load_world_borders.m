function borders = climada_load_world_borders
% load world borders and perform basic checks
% MODULE:
%   GDP_entity
% NAME:
%   climada_load_world_borders
%
%   An OLD code, please consider climada_shaperead
%   Kept for backward compatibility, only used by GDP_entity
%
% PURPOSE:
%   load world borders and perform basic checks
%
%   Please note that this is a backward-compatibility solution, as climada
%   switched to shapes-based country borders (20141212). Please consider
%   climada_country_name and inspect climada_plot_world_borders as well as
%   climada_shaperead.
%
%   map_border_file: filename and path to a *.gen or *.shp border file
%       if set to 'ASK', prompt for the .gen broder file
%
%       the *.gen file has to be of the following format
%       file content                        description (NOT in file)
%       -------------------------------------------------------------------
%       country_name                        Name of the country
%       -70.6,35.2                          longitude,latitude of first polygon point
%       -75.3,23.5                          longitude,latitude of second polygon point
%       -75.3,23.5                          longitude,latitude of next polygon point
%       END                                 marks end of one closed contour
%       -45.45,23-6                         next colsed polygon (eg island)
%       -67.3,23.7
%       END                                 marks end of one closed contour
%       country_name                        next country name
%       -70.6,35.2                          longitude,latitude of first polygon point
%       ...                                 etc...
%       END                                 marks end of one closed contour
%       END                                 last (double) end to close file (optional)
%   keep_boundary: if =1, keep axes boundaries, default =0, undefined
%   country_color: the RGB triple for country coloring (e.g. [255 236
%       139]/255). Default set in code (yellow)
%
%   See also climada module country_risk
% CALLING SEQUENCE:
%   borders = climada_load_world_borders(borders)
% EXAMPLE:
%   borders = climada_load_world_borders
% INPUTS:
%   none
% OPTIONAL INPUT PARAMETERS:
%   borders
% OUTPUTS:
%   borders
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20141016
% David N. Bresch, david.bresch@gmail.com, 20141126, for backward compatibility
%-

borders = []; % init

%global climada_global
if ~climada_init_vars,return;end % init/import global variables

module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% the .gen file with the whole world borders
map_border_file=[module_data_dir filesep 'world_50m.gen'];
%
% the raw text file with ISO3 country codes, groupID and region
country_ISO3_region_file=[module_data_dir filesep 'countryname_ISO3_groupID_region.txt'];

fprintf('%s called (backward compatibility), consider the new climada_shaperead\n',mfilename)

% check for .mat file to exist
[fP,fN,fE]=fileparts(map_border_file);
map_border_file_bin=[fP filesep fN '.mat'];

if climada_check_matfile(map_border_file)
    % load previously stored border data (faster)
    load(map_border_file_bin);
else
    % read the .gen border file (the first time)
    fid  = fopen(map_border_file);
    
    % read first line
    line = fgetl(fid);
    
    counter_country               = 1;
    borders.name{counter_country} = line;
    first_country                 = line;
    counter_poly                  = 0;
    
    % test that not end of file (keyword END)
    while not(feof(fid))
        
        % read next segment and plot it
        pts = fscanf(fid,'%f, %f',[2 inf]);
        if ~isempty(pts)
            %make struct
            if strcmp(line, 'END')==0
                if strcmp(line,first_country)==0 % was 'Canada', not general
                    counter_country               = counter_country+1;
                    borders.name{counter_country} = line;
                    counter_poly                  = 0;
                end
            end
            % store to structure
            counter_poly                                    = counter_poly+1;
            borders.poly{counter_country}.lon{counter_poly} = pts(1,:);
            borders.poly{counter_country}.lat{counter_poly} = pts(2,:);
        else
            line = fgetl(fid);
        end
    end % not(feof(fid))
    
    fclose(fid);
    
    % following code is not needed any more, as climada_plot_world_borders
    % switched to use of admin0.mat (see core system folder)
    %     % store also in one contiguous list (for plot speedup)
    %     whole_world_borders.lon = [];
    %     whole_world_borders.lat = [];
    %     for i=1:length(borders.poly)
    %         for  j=1:length(borders.poly{i}.lon)
    %             whole_world_borders.lon = [whole_world_borders.lon; borders.poly{i}.lon{j}'; NaN]; % separate with NaN
    %             whole_world_borders.lat = [whole_world_borders.lat; borders.poly{i}.lat{j}'; NaN];
    %         end
    %     end
    whole_world_borders=[]; 
    
    % add ISO3 country codes, groupID and region
    if exist(country_ISO3_region_file,'file')
        fid = fopen(country_ISO3_region_file);
        C   = textscan(fid, '%f %s %s %s', 'Delimiter','\t','headerLines',1);
        borders.ISO3    = cell (1,length(C{1}));
        borders.groupID = zeros(1,length(C{1}));
        borders.region  = cell (1,length(C{1}));
        
        for c_i = 1:length(borders.name)
            index = strcmp(borders.name{c_i},C{3});
            if ~isempty(C{1}(index))
                borders.ISO3{c_i}    = C{2}{index};
                if ~isnan(C{1}(index))
                    borders.groupID(c_i) = C{1}(index);
                end
                borders.region{c_i} = C{4}{index};
            else
                fprintf('No match found for country %s\n', borders.name{c_i})
            end
        end
    end
    
    % forward-compatibilty, i.e. replace all country names with the ones
    % used in core climada:
    [country_name,country_ISO3] = climada_country_name('all');
    
    match_count=0;
    for name_i=1:length(borders.ISO3)
        match_pos=strcmp(country_ISO3,borders.ISO3{name_i});
        if sum(match_pos)>0
            borders.name{name_i}=country_name{match_pos};
            match_count=match_count+1;
        else
            fprintf('%s (%s) not matched\n',borders.name{name_i},borders.ISO3{name_i})
        end
    end % name_i
    fprintf('%i of %i border names matched\n',match_count,length(borders.ISO3));
    
    fprintf('country (border) information saved as %s\n',map_border_file_bin)
    save(map_border_file_bin,'borders','whole_world_borders');
end

if isempty(borders)
    fprintf('ERROR: %s, border file not found (%s)\n',mfilename,map_border_file)
end

if ~isfield(borders,'region') || ~isfield(borders,'ISO3') || ~isfield(borders,'groupID')
    fprintf('ERROR: %s, No region, ISO3, or groupID information within border file available, aborted\n',mfilename)
end