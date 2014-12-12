function country_risk_report_raw(country_risk,print_unsorted,plot_DFC)
% climada
% MODULE:
%   country_risk
% NAME:
%   country_risk_report_raw
% PURPOSE:
%   produce a quick&dirty report based on the results from
%   country_risk=country_risk_calc
%
%   previous call: country_risk_calc and country_admin1_risk_calc
%   see also: country_risk_report
% CALLING SEQUENCE:
%   country_risk_report_raw(country_risk,print_unsorted,plot_DFC)
% EXAMPLE:
%   country_risk_report_raw(country_risk_calc('Barbados')); % all in one
%
%   country_risk0=country_risk_calc('Switzerland'); % country, admin0 level
%   country_risk1=country_admin1_risk_calc('Switzerland'); % admin1 level
%   country_risk_report([country_risk0 country_risk1]) % report all
% INPUTS:
%   country_risk: a structure with the results from country_risk_calc
% OPTIONAL INPUT PARAMETERS:
%   print_unsorted: =1, show the results in the order they have been calculated
%       =0, show by descending damages (default)
%   plot_DFC: if =1, plot damage frequency curves (DFC) of all EDSs (!) in
%       country_risk, =0 not (default)
%       if =2, plot logarithmic scale both axes
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141024, initial
% David N. Bresch, david.bresch@gmail.com, 20141025, cleanup of country_risk_report
% David N. Bresch, david.bresch@gmail.com, 20141209, renamed to country_risk_report_raw
%-

%global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
if ~exist('country_risk','var'),return;end
if ~exist('print_unsorted','var'),print_unsorted=0;end
if ~exist('plot_DFC','var'),plot_DFC=0;end

% PARAMETERS
%
% set default value for param2 if not given

n_entities=length(country_risk);

for entity_i=1:n_entities
    fprintf('%s (%i)\n',country_risk(entity_i).res.country_name,entity_i);
    
    if isfield(country_risk(entity_i).res,'hazard') % country exposed
        
        n_hazards=length(country_risk(entity_i).res.hazard);
        ED=zeros(1,n_hazards);
        for hazard_i=1:n_hazards
            if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                ED(hazard_i)=country_risk(entity_i).res.hazard(hazard_i).EDS.ED; % we need for sort later
                res(hazard_i).ED=ED(hazard_i);
                res(hazard_i).EDoL=country_risk(entity_i).res.hazard(hazard_i).EDS.ED/...
                    country_risk(entity_i).res.hazard(hazard_i).EDS.Value;
                res(hazard_i).peril_ID=country_risk(entity_i).res.hazard(hazard_i).EDS.hazard.peril_ID;
                res(hazard_i).annotation_name=country_risk(entity_i).res.hazard(hazard_i).EDS.annotation_name;
                
                if print_unsorted
                    fprintf('  %s ED=%f (%2.2f%%o)   %s\n',...
                        res(hazard_i).peril_ID,res(hazard_i).ED,res(hazard_i).EDoL*1000,...
                        res(hazard_i).annotation_name);
                end % print_unsorted
            else
                ED(hazard_i)=0;
                res(hazard_i).ED=0;
                res(hazard_i).EDoL=0;
                res(hazard_i).peril_ID=country_risk(entity_i).res.hazard(hazard_i).peril_ID;
                res(hazard_i).annotation_name='EMPTY';
            end % ~isempty(EDS)
        end % hazard_i
        
        if ~print_unsorted
            [~,ED_index] = sort(ED); % sort EDs descendingly
            
            for ED_i=n_hazards:-1:1
                fprintf('  %s ED=%f (%2.2f%%o)   %s\n',...
                    res(ED_index(ED_i)).peril_ID,res(ED_index(ED_i)).ED,res(ED_index(ED_i)).EDoL*1000,...
                    res(ED_index(ED_i)).annotation_name);
            end % ED_i
        end % ~print_unsorted
        
    end % country exposed
    
end % entity_i

if plot_DFC
    
    % rearrange all EDSs to pass on to climada_EDS_DFC
    EDS_i=1;
    for entity_i=1:n_entities
        if isfield(country_risk(entity_i).res,'hazard') % country exposed
            n_hazards=length(country_risk(entity_i).res.hazard);
            for hazard_i=1:n_hazards
                if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                    EDS(EDS_i)=country_risk(entity_i).res.hazard(hazard_i).EDS;
                    EDS_i=EDS_i+1;
                end
            end % hazard_i
        end
    end % entity_i
    
    plot_loglog=0;if plot_DFC==2,plot_loglog=1;end
    climada_EDS_DFC(EDS,'',0,plot_loglog);
end

return
