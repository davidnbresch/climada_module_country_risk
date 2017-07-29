function [legend_str,legend_handle]=emdat_barplot(em_data,damage_symbol,damage_orig_symbol,legend_tag,legend_str,legend_handle,legend_location)
% climada template
% MODULE:
%   country_risk
% NAME:
%   emdat_barplot
% PURPOSE:
%   adds kind of error bars based upon EM-DAT, to a DFC plot, see emdat_read first.
%   Just plots the range between em_data.DFC.damage and
%   em_data.DFC_orig.damage as a range. Call this last, as it adds two
%   legend items (and since the connecting bars are plots, adding legend
%   items later is tricky).
%
%   Hint: to show legend 'translucent', call legend('boxoff')
%
%   previous call: emdat_read
%   next call: many
% CALLING SEQUENCE:
%   legend_str=emdat_barplot(em_data,damage_symbol,damage_orig_symbol,legend_tag,legend_str,legend_handle,legend_location)
% EXAMPLE:
%   em_data=emdat_read('','GBR','-WS',1,1);
%   emdat_barplot(em_data);
% INPUTS:
%   em_data: output of emdat_read, see there, needs to contain em_data.DFC
% OPTIONAL INPUT PARAMETERS:
%   damage_symbol: the plot symbol and color for inflated damage, default 'db'
%   damage_orig_symbol: the plot symbol and color for original damage, default 'ob'
%   legend_tag: the legend entry for EM-DAT, default ='EM-DAT indexed'
%       for the original EM-DAT data, ' orig' is added.
%   legend_str: the legend items so far, since the routine adds two items
%   legend_handle: the handle(s) to all plots with legend items so far
%       see e.g. [~,~,legend_str,legend_handle]=climada_EDS_DFC(...)
%   legend_location: the position of the legend, default ='SouthEast'
% OUTPUTS:
%   legend_str: all legend items, two added
%   legend_handle: the handle of all plots 'that matter', i.e. the ones with legends
%   plot
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20170727, initial
% David N. Bresch, david.bresch@gmail.com, 20170729, defaults improved
%-

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('em_data','var'),em_data=[];end
if ~exist('damage_symbol','var'),damage_symbol='';end
if ~exist('damage_orig_symbol','var'),damage_orig_symbol='';end
if ~exist('legend_tag','var'),legend_tag='';end
legend_tag_orig=[strrep(legend_tag,' indexed','') ' orig'];
if ~exist('legend_str','var'),legend_str={};end
if ~exist('legend_handle','var'),legend_handle=[];end
if ~exist('legend_location','var'),legend_location='';end

if isempty(em_data),return;end

% PARAMETERS
%
% define defaults
if isempty(damage_symbol),damage_symbol           = 'db';end
if isempty(damage_orig_symbol),damage_orig_symbol = 'ob';end
if isempty(legend_tag),legend_tag                 = 'EM-DAT';end
if isempty(legend_location),legend_location       = 'SouthEast';end


hold on
legend_handle(end+1)= plot(em_data.DFC.return_period,em_data.DFC.damage,damage_symbol);
legend_str{end+1}   = legend_tag;
if isfield(em_data,'DFC_orig')
    legend_handle(end+1)= plot(em_data.DFC_orig.return_period,em_data.DFC_orig.damage,damage_orig_symbol);
    legend_str{end+1}   = legend_tag_orig;
    for bar_i=1:length(em_data.DFC_orig.return_period)
        plot([em_data.DFC_orig.return_period(bar_i) em_data.DFC.return_period(bar_i)],...       % no handle
            [em_data.DFC_orig.damage(bar_i) em_data.DFC.damage(bar_i)],[':' damage_symbol(2)]);
    end % bar_i
end
legend(legend_handle,legend_str,'Location',legend_location);

end % emdat_barplot