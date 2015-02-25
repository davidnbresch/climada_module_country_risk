function cr_DFC_plot(country_risk,country_i,hazard_i,CAGR,show_plot)
% climada template
% MODULE:
%   country_risk
% NAME:
%   cr_DFC_plot
% PURPOSE:
%   Plot the country damage frequency curves (DFC)
%
%   Note that the countries and perils selected in EM-DAT are written to
%   stdout for check (as a country might have no EM-DAT data and hence
%   comparison with EM-DAT might be misleading - as it should anyway be
%   taken with a pinch of salt...)
%
%   Previous call: country_risk_calc or country_risk_EDS_combine
%   See also: cr_DFC_plot_aggregate (aggregate results for peril regions)
% CALLING SEQUENCE:
%   cr_DFC_plot(country_risk,country_i,hazard_i,CAGR,show_plot)
% EXAMPLE:
%   % let's assume country_risk_calc has been run for this list with
%   % method=-3 (create hazard event sets) already, then:
%   country_list={'Colombia','Costa Rica','Dominican Republic'};
%   country_risk=country_risk_calc(country_list,-7,0,0,['atl_TC';'atl_TS']); % calc EDS
%   [country_risk,EDC]=country_risk_EDS_combine(country_risk); % combine TC and TS and calculate EDC
%   cr_DFC_plot(country_risk)
%   cr_DFC_plot(country_risk,1,2,[],1) % 1st country, 2nd hazard only
% INPUTS:
%   country_risk: the output of country_risk_EDS_combine, see there
%       note that country_risk_EDS_combine is just called after
%       country_risk_calc to combine sub-peril EDSs. Present code runs also
%       if country_risk_EDS_combine has not been called, but then shows
%       e.g. TC and TS separately.
% OPTIONAL INPUT PARAMETERS:
%   country_i: the country index (as shown when first run) to only show one
%       country (usefule in the country damagefunction calibration process)
%   hazard_i: the hazard index (as shown when first run) to only show one
%       hazard (usefule in the country damagefunction calibration process)
%   CAGR: the compound annual growth rate to inflate historic EM-DAT
%       damages with, if empty, the default value is used (climada_global.global_CAGR)
%   show_plot: =1 (default) show the plot, 0= just create and save the plot
% OUTPUTS:
%   plot, as figure and stored to .../results/cr_results/{region}{peril}_aggregate
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150213, intial
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

if ~exist('country_risk','var'),return;end
if ~exist('country_i','var'),country_i=[];end
if ~exist('hazard_i','var'),hazard_i=[];end
if ~exist('CAGR','var'),CAGR=[];end
if ~exist('show_plot','var'),show_plot=1;end

% plot the DFCs of all EDSs
if show_plot,fig_visible='on';else fig_visible='off';end

% PARAMETERS
%
% define the folder where plot(s) will be stored
DFC_plot_dir=[climada_global.data_dir filesep 'results' filesep 'cr_results'];
%
% the maxium return period (RP) we show (to zoom in a bit)
plot_max_RP=250;
%
if isempty(CAGR),CAGR=climada_global.global_CAGR;end % default CAGR
%
% the file with target damage frequency curves (DFCs), need to have columns
% country, peril_ID, return period and damage (TIV and GDP are read, if present)
% the matching country and peril DFC will be plotted for reference (i.e. to
% help calibrate climada to any given (other model) results
target_DFC_file=[climada_global.data_dir filesep 'results' filesep 'target_DFC.xls'];


if show_plot,fig_visible='on';else fig_visible='off';end


n_entities=length(country_risk);

for entity_i=1:n_entities
    
    if ~isempty(country_i)
        if entity_i==country_i
            show_country=1;
        else
            show_country=0;
        end
    else
        show_country=1;
    end
    
    if show_country
        
        if isfield(country_risk(entity_i).res,'hazard') % country exposed
            
            n_hazards=length(country_risk(entity_i).res.hazard);
            for hazard_ii=1:n_hazards
                
                if ~isempty(hazard_i)
                    if hazard_ii==hazard_i
                        show_hazard=1;
                    else
                        show_hazard=0;
                    end
                else
                    show_hazard=1;
                end
                
                if ~isempty(country_risk(entity_i).res.hazard(hazard_ii).EDS) && show_hazard
                    
                    country_name=country_risk(entity_i).res.country_name;
                    country_ISO3=country_risk(entity_i).res.country_ISO3;
                    
                    peril_ID=country_risk(entity_i).res.hazard(hazard_ii).EDS.peril_ID;
                    
                    % figure peril region
                    [~,fN]=fileparts(country_risk(entity_i).res.hazard(hazard_ii).hazard_set_file);
                    fN=strrep(fN,country_ISO3,'');
                    fN=strrep(fN,strrep(country_name,' ',''),'');
                    fN=strrep(fN,peril_ID,'');
                    fN=strrep(fN,'_','');
                    peril_region=strrep(fN,'_','');
                    
                    fprintf('\n*** %s %s (%i) %s %s (%i) ***\n',...
                        char(country_ISO3),char(country_name),entity_i,char(peril_ID),char(peril_region),hazard_ii);
                    
                    Value=country_risk(entity_i).res.hazard(hazard_ii).EDS.Value;
                    DFC=climada_EDS2DFC(country_risk(entity_i).res.hazard(hazard_ii).EDS);
                    
                    DFC_plot = figure('Name',['DFC ' char(country_ISO3) ' ' char(country_name) ' ' peril_ID ' ' peril_region],'visible',fig_visible,'Color',[1 1 1],'Position',[430 20 920 650]);
                    legend_str={};max_RP_damage=0; % init
                    
                    plot(DFC.return_period,DFC.damage,'-b','LineWidth',2);hold on
                    max_damage   =interp1(DFC.return_period,DFC.damage,plot_max_RP); % interp to plot_max_RP
                    max_RP_damage=max(max_RP_damage,max_damage);
                    legend_str{end+1}=country_name;
                    
                    % add EM-DAT
                    em_data=emdat_read('',country_name,peril_ID,1,0,CAGR); % last parameter =1 for verbose
                    if ~isempty(em_data)
                        [adj_EDS,climada2emdat_factor_weighted] = cr_EDS_emdat_adjust(country_risk(entity_i).res.hazard(hazard_ii).EDS);
                        if abs(climada2emdat_factor_weighted-1)>10*eps
                            adj_DFC=climada_EDS2DFC(adj_EDS);
                            plot(adj_DFC.return_period,adj_DFC.damage,':b','LineWidth',1);
                            legend_str{end+1}='EM-DAT adjusted';
                        end
                        
                        plot(em_data.DFC.return_period,em_data.DFC.damage,'dg');
                        legend_str{end+1} = em_data.DFC.annotation_name;
                        plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og');
                        legend_str{end+1} = em_data.DFC_orig.annotation_name;
                        max_RP_damage=max(max_RP_damage,max(em_data.DFC.damage));
                    end % em_data
                    
                    % add cmp results in case they exist
                    cmp_DFC_file=[climada_global.data_dir filesep 'results' filesep 'cmp_results' ...
                        filesep peril_ID filesep country_ISO3 '_' ...
                        strrep(country_name,' ','') '_' ...
                        peril_region '_' peril_ID '_cmp_results.xlsx'];
                    
                    if exist(cmp_DFC_file,'file')
                        fprintf('cmp: %s\n',cmp_DFC_file);
                        DFC_cmp=climada_DFC_read(cmp_DFC_file);
                        if ~isempty(DFC_cmp)
                            hold on
                            fprintf('cmp value:%2.2g (climada value %2.2g)\n',DFC_cmp.value,Value);
                            DFC_cmp.damage=DFC_cmp.damage/DFC_cmp.value*Value; % scale
                            plot(DFC_cmp.return_period,DFC_cmp.damage,'-k','LineWidth',2);
                            max_damage   =interp1(DFC_cmp.return_period,DFC_cmp.damage,plot_max_RP); % interp to plot_max_RP
                            max_RP_damage=max(max_RP_damage,max_damage);
                            legend_str{end+1} = 'cmp';
                        end
                    end
                    
                    if exist(target_DFC_file,'file')
                        %                     try
                        target_DFC=climada_spreadsheet_read('no',target_DFC_file,'target_DFC',1);
                        country_pos=strmatch(country_name,target_DFC.country_name);
                        peril_pos=strmatch(peril_ID,target_DFC.peril_ID(country_pos));
                        country_pos=country_pos(peril_pos);
                        if ~isempty(country_pos)
                            target_Value=target_DFC.value(country_pos(1));
                            fprintf('target value:%2.2g (climada value %2.2g)\n',target_Value,Value);
                            target_DFC.damage(country_pos)=target_DFC.damage(country_pos)/target_Value*Value; % scale
                            plot(target_DFC.return_period(country_pos),target_DFC.damage(country_pos),':k','LineWidth',2)
                            max_damage   =interp1(target_DFC.return_period(country_pos),target_DFC.damage(country_pos),plot_max_RP); % interp to plot_max_RP
                            max_RP_damage=max(max_RP_damage,max_damage);
                            legend_str{end+1} = 'target';
                        end
                        %                     catch
                        %                         fprintf('Warning: troubles reading/processing %s\n',target_DFC_file);
                        %                     end
                    end
                    
                    % zoom to 0..plot_max_RP years return period
                    if max_RP_damage==0,max_RP_damage=1;end
                    axis([0 plot_max_RP 0 max_RP_damage]);
                    
                    legend(legend_str,'Location','NorthWest'); % show legend
                    title([peril_ID ' ' peril_region ' ' country_ISO3 ' ' country_name]);
                    
                    DFC_plot_name=[DFC_plot_dir filesep peril_ID '_' ...
                        peril_region '_' country_ISO3 '_' strrep(country_name,' ','') '_DFC.png'];
                    if ~exist(DFC_plot_dir,'dir'),mkdir(DFC_plot_dir);end
                    while exist(DFC_plot_name,'file'),DFC_plot_name=strrep(DFC_plot_name,'.png','_.png');end % avoid overwriting
                    if ~isempty(DFC_plot_name)
                        saveas(DFC_plot,DFC_plot_name,'png');
                        fprintf('saved as %s\n',DFC_plot_name);
                    end
                    if ~show_plot,delete(DFC_plot);end
                    
                end % ~isempty(EDS)
            end % hazard_ii
            
        end % country exposed
        
    end % show_country
    
end % entity_i

end % cr_DFC_plot