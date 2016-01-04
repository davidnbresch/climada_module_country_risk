function stru_new_res = climada_downscale(stru, downscale_factor, f_name)
% see code
%-

% init global variables
global climada_global
if ~climada_init_vars, return; end

% check inputs, and set default values
if ~exist('stru'            , 'var'), stru             = [] ; end
if ~exist('downscale_factor', 'var'), downscale_factor = 10 ; end
if ~exist('f_name'          , 'var'), f_name           = '' ; end

if isempty(f_name), f_name = 'Value' ; end

if ~(isfield(stru,'Longitude') & isfield(stru,'Latitude') & isfield(stru,f_name))
    fprintf('Input structure does not have fields "Longitude", "Latitude" and "%s". Unable to proceed.\n',f_name)
    return
end
    
% minimal resolution
res_x       = min(diff(unique(stru.lon)));
res_y       = min(diff(unique(stru.lat)));

new_min_lon = min(stru.lon) + res_x*downscale_factor/2 + res_x/2;
new_min_lat = min(stru.lat)  + res_y*downscale_factor/2 + res_x/2;
% new_max_lon = max(stru.lon) - res_x*downscale_factor/2 - res_x/2;
% lon         = new_min_lon: res_x*downscale_factor: new_max_lon;
% new_max_lat = max(stru.lat) - res_y*downscale_factor/2 - res_x/2;
% lat         = new_min_lat: res_x*downscale_factor: new_max_lat;

f           = round( (stru.lon - new_min_lon) / (res_x*downscale_factor) );
new_lon     = new_min_lon + f * (res_x*downscale_factor);
f           = round( (stru.lat  - new_min_lat) / (res_y*downscale_factor) );
new_lat     = new_min_lat + f * (res_y*downscale_factor);

% ismember(new_lon(1), lon)
% ismember(new_lat(1), lat)

counter = 0;
stru_new_res = [];
v = getfield(stru, f_name);
for i = 1:length(new_lon)
    l1 = (new_lon(i)==new_lon & new_lat(i)==new_lat);
    l1_ = find(l1);
    if all(l1_>=i)
        counter = counter+1;
        stru_new_res.lon(counter) = new_lon(i);
        stru_new_res.lat(counter)  = new_lat(l1_(1));
        v_new(counter)                  = sum(v(l1_));
        %stru_new_res.Values(counter)   = sum(stru.Values(l1_));
    end
end
stru_new_res = setfield(stru_new_res, f_name, v_new);


