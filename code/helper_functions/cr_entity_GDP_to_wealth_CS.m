function [entity, ratio]=cr_entity_GDP_to_wealth_CS(entity,admin0_ISO3,value_mode,wealth_from_xls)
% NAME: cr_entity_GDP_to_wealth_CS
% MODULE: country_risk
% PURPOSE:
%   Given a climada exposure entity with GDP sitributed to assets in a
%   country, multiply asset values by a country specific factor to obtain
%   an estimation of asset values based on (non financial) wealth.
%   Factors based on Credit Suisse Wealth Databook 2017, Table 2-4, mid-2017, p.101ff.
% CALLING SEQUENCE:
%  entity = climada_LitPop_GDP_entity(admin0_ISO3);
%  [entity, ratio]=cr_entity_GDP_to_wealth_CS(entity,admin0_ISO3);
% EXAMPLES:
%     [~,ratio]=cr_entity_GDP_to_wealth_CS([],'USA',3,1);
%
%     entity_GDP = climada_LitPop_GDP_entity('VNM');
%     [entity_NFW, ratio]=cr_entity_GDP_to_wealth_CS(entity_GDP,'VNM');
%
% INPUTS:
%     entity: climada entity struct with a share of country GDP distributed
%       as asset values
%     admin0_ISO3: ISO3 code of country, i.e. USA or VNM etc.
% OPTIONAL INPUTS:
%     wealth_from_xls (default = 0): read conersion factors from xls file (1) or from mat file (0), 0 adviced on cluster
%     value_mode (default = 2): which multiplication factor to use
%         1: distributed GDP (World Bank)
%         2: distributed non-financial-wealth (World Bank * CS) <-- default
%         3: distributed total wealth (World Bank * CS)
% OUTPUT:
%   entity: same entity as input but with changed asset value (multiplied by CS factor)
%   ratio: scaling factor for the given country (GDP to wealth)
% REQUIREMENTS:
% file asset2GDPConversion_GLB.xls or asset2GDPConversion_GLB.mat in module country_risk/data/
%
% MODIFICATION HISTORY:
% Samuel Eberenz, eberenz@posteo.eu, 20180904, init
%-
global climada_global
if ~climada_init_vars,return;end % init/import global variables

if ~exist('admin0_ISO3','var'), return;end
if ~exist('entity','var'), entity=[];end
if ~exist('value_mode','var'), value_mode=[];end
if ~exist('wealth_from_xls','var'), wealth_from_xls=[];end

if isempty(value_mode),value_mode=2;end
if isempty(wealth_from_xls),wealth_from_xls=1;end

Input_path = [climada_global.modules_dir filesep 'country_risk' filesep 'data'];

wealth_file_xls = [Input_path filesep 'asset2GDPConversion_GLB.xls'];
wealth_file_mat = [Input_path filesep 'asset2GDPConversion_GLB.mat'];

% load table with conversation factors (Credit Suisse Wealth Databook 2017,
% Table 2-4, mid-2017, p.101ff.)
if wealth_from_xls
    try
        wealth_ratios = climada_xlsread(0,wealth_file_xls,'Sheet1',0);
        save(wealth_file_mat,'wealth_ratios','-v7.3');
    catch
        wealth_from_xls = 0
    end
end
if ~wealth_from_xls
    load(wealth_file_mat);
end

% extract factor of country and multiply asset values with the factor
switch value_mode
    case 1 % no change
        ratio = 1;
    case 2 % convert total asset value from GDP to non-financial wealth:
        ratio = wealth_ratios.AssettoGDPRatio(find(...
            ~cellfun('isempty',strfind(wealth_ratios.Climada_Country_Code,admin0_ISO3))==1));
        if isempty(ratio) || isnan(ratio) || ratio<=0
            ratio = nanmean(wealth_ratios.AssettoGDPRatio);
        end
        
    case 3 % convert total asset value from GDP to total financial wealth:
        ratio = wealth_ratios.WealthtoGDPration(find(...
            ~cellfun('isempty',strfind(wealth_ratios.Climada_Country_Code,admin0_ISO3))==1));
        if isempty(ratio) || isnan(ratio) || ratio<=0
            ratio = nanmean(wealth_ratios.WealthtoGDPration);
        end
end
if ~isempty(entity)
    entity.assets.Value = entity.assets.Value*ratio;
end
end