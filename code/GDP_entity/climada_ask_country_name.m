function [country_name,country_ISO3] = climada_ask_country_name(SelectionMode,PromptString)
% ask for a country name through a pop up gui
% NAME:
%   climada_ask_country_name
% PURPOSE:
%   ask for a country name through a pop up gui
% CALLING SEQUENCE:
%   country_name = climada_ask_country_name(SelectionMode,PromptString)
% EXAMPLE:
%   country_name = climada_ask_country_name
% INPUTS:
%   none
% OPTIONAL INPUT PARAMETERS:
%   SelectionMode: if set to 'multiple' allow for more than one country to
%       be selected, if ='single', allow for single selection only (default)
%   PromptString: the prompt string, default is set according to SelectionMode
% OUTPUTS:
%   country_name, a char if SelectionMode='single' (default)
%       a cell if SelectionMode='multiple'
%   country_ISO3: the ISO3 country code (unambiguous)
%       a cell if SelectionMode='multiple'
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20141016
% David N. Bresch, david.bresch@gmail.com, 20141126, SelectionMode added
% David N. Bresch, david.bresch@gmail.com, 20141209, ISO3 country code added
%-

%global climada_global
if ~climada_init_vars,return;end % init/import global variables

country_name = ''; % init
country_ISO3 = '';

if ~exist('SelectionMode','var'), SelectionMode = 'single';end
if ~exist('PromptString','var'), PromptString = '';end

borders              = climada_load_world_borders; % get list of country names
valid_countries_indx = ~strcmp(borders.ISO3,'-');
valid_countries      = borders.name(valid_countries_indx);
valid_ISO3           = borders.ISO3(valid_countries_indx);
[liststr,sort_index] = sort(valid_countries);
if isempty(PromptString)
    if strcmp(SelectionMode,'single')
        PromptString='Select exactly one country:';
    else
        PromptString='Select countries (or one):';
    end
end
[selection,ok] = listdlg('PromptString',PromptString,...
    'ListString',liststr,'SelectionMode',SelectionMode);
if ~ok,return;end
pause(0.1)
if ~isempty(selection)
    country_name = valid_countries(sort_index(selection));
    country_ISO3 = valid_ISO3(sort_index(selection));
    if strcmp(SelectionMode,'single')
        country_name=country_name{1};
        country_ISO3=country_ISO3{1};
    end
else
    fprintf('No country chosen\n')
    return
end

if length(country_name)==1,country_name=char(country_name);end % backward compatibility