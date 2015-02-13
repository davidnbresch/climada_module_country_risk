function cr_plot_DFC_aggregate(country_risk,EDC,CAGR,show_plot)
% climada template
% MODULE:
%   country_risk
% NAME:
%   cr_plot_DFC_aggregate
% PURPOSE:
%   Plot the combined global damage frequency curve (DFC) and the annual
%   aggregate DFC 
%
%   Note that the countries and perils selected in EM-DAT are written to
%   stdout for check (as a country might have no EM-DAT data and hence
%   comparison with EM-DAT might be misleading - as it should anyway be
%   taken with a pinch of salt...)
%
%   Previous call: country_risk_EDS_combine
%   See also: cr_plot_DFC (country instead of aggrgate results)
% CALLING SEQUENCE:
%   cr_plot_DFC_aggregate(country_risk,EDC,CAGR,show_plot)
% EXAMPLE:
%   % let's assume country_risk_calc has been run for this list with
%   % method=-3 (create hazard event sets) already, then:
%   country_list={'Colombia','Costa Rica','Dominican Republic'};
%   country_risk=country_risk_calc(country_list,-7,0,0,['atl_TC';'atl_TS']); % calc EDS
%   [country_risk,EDC]=country_risk_EDS_combine(country_risk); % combine TC and TS and calculate EDC
%   cr_plot_DFC_aggregate(country_risk,EDC)
% INPUTS:
%   country_risk: the output of country_risk_EDS_combine, see there
%       note that country_risk_EDS_combine is just called after
%       country_risk_calc to combine sub-peril EDSs and to produce the EDC,
%       the maximally combined EDS (i.e. one global EDS per peril and
%       region)
%   EDC: the output of country_risk_EDS_combine, see there
% OPTIONAL INPUT PARAMETERS:
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
if ~exist('EDC','var'),return;end
if ~exist('CAGR','var'),CAGR=[];end
if ~exist('show_plot','var'),show_plot=1;end

% prepare the plot
if show_plot,fig_visible='on';else fig_visible='off';end
DFC_fig = figure('Name','DFC aggregate','visible',fig_visible,'Color',[1 1 1],'Position',[430 20 920 650]);
max_RP_damage=0; % init

% PARAMETERS
%
% define the folder where plot(s) will be stored
DFC_plot_dir=[climada_global.data_dir filesep 'results' filesep 'cr_results'];
%
% the maxium return period (RP) we show (to zoom in a bit)
plot_max_RP=250;
%
if isempty(CAGR),CAGR=climada_global.global_CAGR;end % default CAGR

% plot the aggregate per event (PE) and annual aggregate (AA) damage
% frequency curve for each basin as well as the total global aggregate

PE_damage=[];PE_frequency=[]; % init
legend_str={};saveas_str=''; % init
AA_damage=[];AA_frequency=[]; % init for annual aggregate
plot_symboll={'-b','-g','-r','-c','-m','-y'}; % line
plot_symbold={':b',':g',':r',':c',':m',':y'}; % dotted
for EDC_i=1:length(EDC)
    % the per event perspective:
    PE_damage=[PE_damage EDC(EDC_i).EDS.damage]; % collect per event damage
    PE_frequency=[PE_frequency EDC(EDC_i).EDS.frequency]; % collect per event frequency
    DFC=climada_EDS2DFC(EDC(EDC_i).EDS);
    plot(DFC.return_period,DFC.damage,plot_symboll{EDC_i},'LineWidth',2);hold on
    legend_str{end+1}=strrep(EDC(EDC_i).EDS.comment,'_',' ');
    
    saveas_str=[saveas_str strrep(EDC(EDC_i).EDS.comment,' ','_')]; % avoid space in filename
    
    max_damage = interp1(DFC.return_period,DFC.damage,plot_max_RP); % interp to plot_max_RP
    max_RP_damage=max(max_RP_damage,max_damage);
    
    % and the annual aggregate perspective
    YDS=climada_EDS2YDS(EDC(EDC_i).EDS);
    if ~isempty(YDS)
        AA_damage=[AA_damage YDS.damage]; % collect AA damage
        AA_frequency=[AA_frequency YDS.frequency]; % collect AA frequency
        YFC=climada_EDS2DFC(YDS);
        plot(YFC.return_period,YFC.damage,plot_symbold{EDC_i},'LineWidth',2);hold on
        legend_str{end+1}=[strrep(EDC(EDC_i).EDS.comment,'_',' ') ' annual aggregate'];
        
        max_damage = interp1(YFC.return_period,YFC.damage,plot_max_RP); % interp to plot_max_RP
        max_RP_damage=max(max_RP_damage,max_damage);
    end
end % EDC_i

% the per event perspective:
[sorted_damage,exceedence_freq]=climada_damage_exceedence(PE_damage',PE_frequency);
nonzero_pos      = find(exceedence_freq);
agg_PE_damage       = sorted_damage(nonzero_pos);
exceedence_freq  = exceedence_freq(nonzero_pos);
agg_PE_return_period    = 1./exceedence_freq;
plot(agg_PE_return_period,agg_PE_damage,'-k','LineWidth',2);
legend_str{end+1}='full global aggregate';

max_damage = interp1(agg_PE_return_period,agg_PE_damage,plot_max_RP); % interp to plot_max_RP
max_RP_damage=max(max_RP_damage,max_damage);

if ~isempty(AA_damage)
    % the AA perspective:
    [sorted_damage,exceedence_freq]=climada_damage_exceedence(AA_damage',AA_frequency);
    nonzero_pos      = find(exceedence_freq);
    agg_AA_damage       = sorted_damage(nonzero_pos);
    exceedence_freq  = exceedence_freq(nonzero_pos);
    agg_AA_return_period    = 1./exceedence_freq;
    plot(agg_AA_return_period,agg_AA_damage,':k','LineWidth',2);
    legend_str{end+1}='full global annual aggregate';
    
    max_damage = interp1(agg_AA_return_period,agg_AA_damage,plot_max_RP); % interp to plot_max_RP
    max_RP_damage=max(max_RP_damage,max_damage);
    
end

% get country_list from country_risk
country_list={};country_ISO3_list={};peril_ID={};peril_region={}; % init
n_entities=length(country_risk);
for entity_i=1:n_entities
    if isfield(country_risk(entity_i).res,'hazard') % country exposed
        n_hazards=length(country_risk(entity_i).res.hazard);
        for hazard_i=1:n_hazards
            if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                country_list{end+1}=country_risk(entity_i).res.country_name;
                country_ISO3_list{end+1}=country_risk(entity_i).res.country_ISO3;
                peril_ID{end+1}=country_risk(entity_i).res.hazard(hazard_i).EDS.peril_ID;
                
                % figure peril region
                [~,fN]=fileparts(country_risk(entity_i).res.hazard(hazard_i).hazard_set_file);
                fN=strrep(fN,country_ISO3_list{end},'');
                fN=strrep(fN,strrep(country_list{end},' ',''),'');
                fN=strrep(fN,peril_ID{end},'');
                fN=strrep(fN,'_','');
                peril_region{end+1}=char(strrep(fN,'_',''));
                
            end % ~isempty(EDS)
        end % hazard_i
    end % country exposed
end % entity_i

peril_ID=char(unique(peril_ID));peril_str='';
for peril_i=1:size(peril_ID,1) % we allow for more than one peril here
    peril_str=[peril_str peril_ID(peril_i,:)];
end
peril_str=strrep(peril_str,' ','');
peril_str=strrep(peril_str,' ','');

peril_region=char(unique(peril_region));region_str='';
for peril_region_i=1:size(peril_region,1) % we allow for more than one peril here
    region_str=[region_str peril_region(peril_region_i,:)];
end
region_str=strrep(region_str,' ','');
region_str=strrep(region_str,' ','');

% plot EM-DAT
em_data=emdat_read('',country_list,peril_ID,1,1,CAGR);
if ~isempty(em_data)
    plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og'); hold on
    legend_str{end+1}='EM-DAT';
    
    plot(em_data.DFC.return_period,em_data.DFC.damage,'xg'); hold on
    legend_str{end+1}='EM-DAT indexed';
    
    max_RP_damage=max(max_RP_damage,max(em_data.DFC.damage));
    
    em_data.YDS.DFC=climada_EDS2DFC(em_data.YDS);
    plot(em_data.YDS.DFC.return_period,em_data.YDS.DFC.damage,'sg'); hold on
    legend_str{end+1}=em_data.YDS.DFC.annotation_name;
    
    max_RP_damage=max(max_RP_damage,max(em_data.YDS.DFC.damage));
    
end

legend(legend_str);title([peril_str ' ' region_str ' global aggregate'])

% zoom to 0..plot_max_RP years return period
if max_RP_damage==0,max_RP_damage=1;end
axis([0 plot_max_RP 0 max_RP_damage]);

DFC_plot_name=[DFC_plot_dir filesep peril_str '_' region_str '_aggregate.png'];

if ~exist(DFC_plot_dir,'dir'),mkdir(DFC_plot_dir);end
while exist(DFC_plot_name,'file'),DFC_plot_name=strrep(DFC_plot_name,'.png','_.png');end % avoid overwriting
if ~isempty(DFC_plot_name)
    saveas(DFC_fig,DFC_plot_name,'png');
    fprintf('saved as %s\n',DFC_plot_name);
end
if ~show_plot,delete(DFC_fig);end

end % cr_plot_DFC_aggregate