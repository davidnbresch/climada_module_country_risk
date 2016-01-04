function [EDS,climada2emdat_factor_weighted,em_data]=cr_EDS_emdat_adjust(EDS,verbose_mode)
% climada template
% MODULE:
%   country_risk
% NAME:
%   cr_EDS_emdat_adjust
% PURPOSE:
%   Given an event damge set (EDS), adjust results to best match EM-DAT
%   damage history of a given country for a given peril, see also
%   emdat_read (the raw damage from EM-DAT is scaled up for growth...)
%
%   previous call: climada_EDS_calc and country_risk_calc
%   See also: emdat_read and cr_plot_DFC
% CALLING SEQUENCE:
%   [EDS,climada2emdat_factor_weighted]=cr_EDS_emdat_adjust(EDS,verbose_mode)
% EXAMPLE:
%   EDS=cr_EDS_emdat_adjust(climada_EDS_calc)
% INPUTS:
%   EDS: an event damge set (EDS), as calculated by climada_EDS_calc
%       Only one EDS supported, e.g. use EDS(i) as input if EDS is an array
%       of structs
% OPTIONAL INPUT PARAMETERS:
%   verbose_mode: if =1, print list of countries and disaster subtypes that
%       are returned from EM-DAT. 
%       =2: also plot the damage frequency curve (DFC) before and after
%       adjustment as well as the EM-DAT information
%       Default=0 (silent)
% OUTPUTS:
%   EDS: the adjusted EDS
%   climada2emdat_factor_weighted: the weighted adjustment factor (i.e.
%       EDS.damage output = EDS.damage input * climada2emdat_factor_weighted
%   em_data: the EM-DAT data as used to adjust
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150127, initial
% David N. Bresch, david.bresch@gmail.com, 20150202, em_data as output
%-

climada2emdat_factor_weighted=[]; % init output
em_data=[]; % init output

%global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('EDS','var'),EDS=[];return;end
if ~exist('verbose_mode','var'),verbose_mode=0;end

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
%module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%

country_name=EDS.assets.admin0_name;
peril_ID    =char(EDS.peril_ID(1:2));

% use EM-DAT information to calibrate, if available
em_data=emdat_read('',country_name,peril_ID,1,verbose_mode);
if ~isempty(em_data)
    
    if sum(em_data.damage)>0
        
        if ~verbose_mode
            country_list=unique(em_data.country);
            disaster_subtype_list=unique(em_data.disaster_subtype);
            em_data_info=sprintf('(%s, %s)',char(country_list{1}),char(disaster_subtype_list{1}));
        else
            em_data_info=''; % no further info, as shon by emdat_read already
        end
        
        % calculate climada DFC on EM-DAT return periods
        DFC=climada_EDS2DFC(EDS,em_data.DFC.return_period);
        
        % figure adjustment factor for climada to match EM-DAT
        climada2emdat_factor=em_data.DFC.damage./DFC.damage;
        
        DFC_weight_pos=em_data.DFC.return_period>20 & DFC.damage>0; % we look into >20 years
                
        if ~isempty(DFC_weight_pos) && sum(DFC_weight_pos)>0
            
            % weight the factor, in order to only have one global
            climada2emdat_factor_weighted=climada2emdat_factor(DFC_weight_pos)*...
                em_data.DFC.return_period(DFC_weight_pos)'/sum(em_data.DFC.return_period(DFC_weight_pos));
            fprintf('EM-DAT: climada scaling factor %f %s\n',climada2emdat_factor_weighted,em_data_info);
            
        else
            climada2emdat_factor_weighted=1.0;
            fprintf('EM-DAT: no adjustment (not enough EM-DAT data)\n');
        end
        
        if verbose_mode==2
            DFC_orig=climada_EDS2DFC(EDS); % same return periods as comparison
        end
        
        % finally, adjust EDS
        EDS.damage=EDS.damage*climada2emdat_factor_weighted;
        
        if verbose_mode==2
            DFC=climada_EDS2DFC(EDS);
            plot(DFC.return_period,DFC.damage,'-b','LineWidth',2); hold on
            plot(DFC_orig.return_period,DFC_orig.damage,':b','LineWidth',1); hold on
            if isfield(em_data,'DFC_orig')
                plot(em_data.DFC.return_period,em_data.DFC.damage,'xg'); hold on
                plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og'); hold on
                legend('adjusted','orig',em_data.DFC.annotation_name,em_data.DFC_orig.annotation_name);
            else
                plot(em_data.DFC.return_period,em_data.DFC.damage,'og'); hold on
                legend('adjusted','orig',em_data.DFC.annotation_name);
            end
            title(strrep(EDS.annotation_name,'_',' '));
            set(gcf,'Color',[1 1 1])
            max_damage=max(max(DFC.damage(~isnan(DFC.damage))),max(DFC_orig.damage(~isnan(DFC_orig.damage))));
            max_RO=max(max(DFC.return_period(~isnan(DFC.damage))),max(DFC_orig.return_period(~isnan(DFC_orig.damage))));
            axis([0 max_RO 0 max_damage]);
            drawnow
        end % verbose_mode==2
        
    else
        fprintf('EDS unadjusted, EM-DAT damage zero for %s %s\n',country_name,peril_ID)
    end
    
else
    fprintf('EDS unadjusted, no EM-DAT information for %s %s\n',country_name,peril_ID)
end % em_data

end % cr_EDS_emdat_adjust