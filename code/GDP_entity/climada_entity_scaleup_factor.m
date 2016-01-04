function entity = climada_entity_scaleup_factor(entity, factor_)
% upscale a given entity with a specific factor
% MODULE:
%   GDP_entity
% NAME:
%   climada_entity_scaleup_factor
% PURPOSE:
%   Upscale entity assets with a specific factor 
% CALLING SEQUENCE:
%   entity = climada_entity_scaleup_factor(entity, factor_)
% EXAMPLE:
%   entity = climada_entity_scaleup_factor(entity, factor_)
% INPUTS:
%   entity: entity with entity.assets
%   factor_: factor to multiply entity.assets.Value with
% OPTIONAL INPUTS:
%   none
% OUTPUTS:
%   entity: assets upscaled with a specific factor
%   a structure, with
%       assets: a structure, with
%           Latitude: the latitude of the values
%           Longitude: the longitude of the values
%           Value: the total insurable value
%           Deductible: the deductible
%           Cover: the cover
%           DamageFunID: the damagefunction curve ID
%       damagefunctions: a structure, with
%           DamageFunID: the damagefunction curve ID
%           Intensity: the hazard intensity
%           MDD: the mean damage degree
% MODIFICATION HISTORY:
% Lea Mueller, 20130412
% david.bresch@gmail.com, 20140216, _2012 replaced by _today
% david.bresch@gmail.com, 20141024, entity.assets.comment introduced
% muellele@gmail.com, 20151105, add module name in documentation
%-

%global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('entity'    ,'var'), entity     = []; end
if ~exist('factor_'   ,'var'), factor_    = []; end

if isempty(entity)
    entity = climada_entity_load;
end

if isempty(factor_)
    fprintf('No scaleup factor given. Unable to proceed.\n')
    return
end

% scale up entity with given factor
if ~isfield(entity.assets,'comment'),entity.assets.comment='';end
entity.assets.comment = [entity.assets.comment sprintf(', entity scaled with factor %2.3f',factor_)]; % was entity.assets.filename= before
entity.assets.scaleup_factor  = factor_ ; % new, to have the factor at hand
entity.assets.Value           = factor_ * entity.assets.Value ;
entity.assets.Deductible      = factor_ * entity.assets.Deductible;
entity.assets.Cover           = factor_ * entity.assets.Cover;
if isfield(entity.assets,'Value_today')
    entity.assets.Value_today     = factor_ * entity.assets.Value_today;
end
if isfield(entity.assets,'MSP_Loss')
    entity.assets.MSP_Loss    = factor_ * entity.assets.MSP_Loss;
end
