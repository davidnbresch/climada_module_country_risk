function [c_y_calibration_vector,c_y_calibration_vector_emdat,c_y_calibration_vector_climada,country,years] = cr_c_y_calibration_vector(country,years,entity,hazard,em_data,peril_ID)

% country-year risk calibration vector
% NAME:
%   cr_c_y_calibration_vector
% PURPOSE:
%   Compute a vector with ones for each year with damages>0 in a given
%   country both in em-dat and YDS
% CALLING SEQUENCE:
%   [c_y_calibration_vector,country,years] = cr_c_y_calibration_vector(country,years,entity,hazard,em_data,peril_ID,reference_year)
% EXAMPLES:
%   c_y_calibration_vector = cr_c_y_calibration_vector('USA',1980:2015,entity,[],[],'TC');
%   
% country = 'Switzerland';
% years = 1990:2010;
% entity = climada_LitPop_GDP_entity(country);
% hazard_filename = '...'; % set file name
% hazard = climada_hazard_load(hazard_filename);
% entity = climada_assets_encode(entity,hazard);
% peril_ID = 'WS';
% [c_y_comb,c_y_emdat_c_y_climada,country,years] =  cr_c_y_calibration_vector('CHE',years,entity,hazard,[],peril_ID);
% INPUTS:
%   country: name or ISO3 code of country as char, e.g. 'USA'
% OPTIONAL INPUT PARAMETERS:
%   years: numerical vector with years considered, default: 1980:2015
%   entity: climada entity struct or file name
%   hazard: climada hazard struct or file name
%   em_data: em-data struct as produced by emdat_read()
%   peril_ID: char with climada peril-ID. default = 'TC'
% OUTPUTS:
%   c_y_calibration_vector: vector with ones for each year with damages>0 in the given
%       country, damages>0 both in em-dat and YDS. contains 0 otherwise
%   c_y_calibration_vector_emdat: 1 where there is damage in emdat
%   c_y_calibration_vector_climada: 1 where there is damage in YDS
%   country: country name 
%   years: as input
%
% MODIFICATION HISTORY:
% Samuel Eberenz, eberenz@posteo.eu, 20181008, initial
%-

global climada_global
if ~climada_init_vars,return;end

if ~exist('country','var'),return;end
if ~exist('years','var'),years=[];end
if ~exist('entity','var'),entity=[];end
if ~exist('hazard','var'),hazard=[];end
if ~exist('em_data','var'),em_data=[];end
if ~exist('peril_ID','var'),peril_ID=[];end
if ~exist('reference_year','var'),reference_year=[];end

if ~isempty(country) % check for valid name, othwerwise set to empty
    [country,country_code]=climada_country_name(country);
else
    return;
end
if isempty(years), years = 1980:2015;end
if isempty(peril_ID), peril_ID = 'TC';end
if isempty(reference_year), reference_year = 2005;end
if isempty(entity), entity = [country_code '_GDP_LitPop_BM2016_300arcsec_ry' num2str(reference_year)];end
if isempty(hazard), hazard = ['GLB_0360as_' peril_ID '_hist'];end

if ischar(entity)
    entity=climada_entity_load(entity);
end
if ischar(hazard)
    hazard=climada_hazard_load(hazard);
end
if isempty(em_data)
    em_data = emdat_read('',country_code,peril_ID,reference_year,0); % em_data=emdat_read('','USA','TC',2005,1)
end

if isequal(peril_ID,'TC')
    entity.damagefunctions = climada_tc_damagefun_emanuel2011([],20,30,1,1,[],[],0);
end
EDS = climada_EDS_calc(entity,hazard,[],[],1);
YDS = climada_EDS2YDS(EDS,hazard,[],[],1);
clear EDS

%%

c_y_calibration_vector_emdat = zeros(size(years));
c_y_calibration_vector_climada = c_y_calibration_vector_emdat;

for i = 1:length(c_y_calibration_vector_emdat)
    if ~isempty(YDS.damage(YDS.yyyy == years(i)))...
            && YDS.damage(YDS.yyyy == years(i))>0
        
        c_y_calibration_vector_climada(i) = 1;
    end
    if ~isempty(em_data.damage(em_data.year == years(i)))...
            && em_data.damage(em_data.year == years(i))>0
        c_y_calibration_vector_emdat(i) = 1;
    end
    
end
c_y_calibration_vector = c_y_calibration_vector_emdat & c_y_calibration_vector_climada;

end






