function in=climada_inshape(lat,lon,shape,check_plot)
% climada template
% MODULE:
%   country_risk
% NAME:
%   climada_inshape
% PURPOSE:
%   wrapper for inpolygon to work with directly shapes (see ESRI shapefile (.shp))
%   The functions checks if points specified in latitude, longitude
%   coordinates are within polygons specified in variable shape (created
%   with climada_shaperead)
%
%   
% CALLING SEQUENCE:
%   shape_test = climada_shaperead([climada_global.modules_dir filesep 'country_risk' filesep 'data' filesep 'ne_10m_admin_0_countries' filesep 'ne_10m_admin_0_countries.shp']);
%   lat = 34.5 + rand(500,1)*26.5; lon = -12 + rand(500,1)*44.5;
%   check_plot = 1;
%   in=climada_inshape(lat,lon,shape_test,check_plot)
% EXAMPLE:
%   
% INPUTS:
%   lat: latitude coordinates of n points
%   lon: longitude coordinates of n points
%   shape: polygon 
% OPTIONAL INPUT PARAMETERS:
%   check_plot: =1 to show the result (default=0)
% OUTPUTS:
%   in: the indices of the points within the polygon (see help inpolygon)
% MODIFICATION HISTORY:
% Thomas Roeoesli, thomas.roeoesli@usys.ethz.ch, 20171023, initial
%-

in=[]; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('lat','var'),return;end
if ~exist('lon','var'),return;end
if ~exist('shape','var'),return;end
if ~exist('check_plot','var'),check_plot=0;end

% see if shape is a polygon according to standard (with BoundingBox Variable)
if ~isfield(shape,'BoundingBox')
    fprintf('ERROR: variable shape, does not have a field called BoundingBox, consider using climada_inpolygon.\n');
    return;
end
        

% PARAMETERS
number_of_shapes = numel(shape);
in = false(size(lat));
for i = 1:number_of_shapes
    check_if_in_box = any(any( (lon > shape(i).BoundingBox(1,1)) & (lon < shape(i).BoundingBox(2,1)) ...
        & (lat > shape(i).BoundingBox(1,2)) & (lat < shape(i).BoundingBox(2,2))));
    if check_if_in_box
        if sum(isnan(shape(i).X)) <= 1
            in = in | climada_inpolygon(lat,lon,shape(i).Y,shape(i).X);
        else
            positions_of_polygons = [0 find(isnan(shape(i).X))];
            if positions_of_polygons(end) ~= numel(shape(i).X)
                positions_of_polygons(end+1) = numel(shape(i).X);
            end
            for ii = 1:(numel(positions_of_polygons)-1)
                in = in | climada_inpolygon(lat,lon,shape(i).Y((positions_of_polygons(ii)+1):positions_of_polygons(ii+1)),shape(i).X((positions_of_polygons(ii)+1):positions_of_polygons(ii+1)));
            end
        end
    end
    % fprintf('I');
end

if check_plot
    figure;
    for ii = 1:number_of_shapes
        plot(shape(ii).X,shape(ii).Y,'-k','LineWidth',2) % polygon
        axis equal
        hold on
    end
    plot(lon,lat,'bo') % all points
    plot(lon(in),lat(in),'gx') % points inside
    legend({'target','all','inside'});
end % check_plot

end % climada_inshape

