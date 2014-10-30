function country_risk_report(country_risk,print_unsorted,plot_DFC)
% climada
% NAME:
%   country_risk_report
% PURPOSE:
%   produce a report based on the results from
%   country_risk=country_risk_calc
%
%   previous call: country_risk_calc
% CALLING SEQUENCE:
%   country_risk_report(country_risk,print_unsorted,plot_DFC)
% EXAMPLE:
%   country_risk_report(country_risk_calc('Barbados')); % all in one
% INPUTS:
%   country_risk: a structure with the results from country_risk_calc
% OPTIONAL INPUT PARAMETERS:
%   print_unsorted: if =1, show the results in the order they have been
%       calculated, if =0, show by descending losses (default)
%   plot_DFC: if =1, plot damage frequency curves (DFC) of all EDSs (!) in
%       country_risk, =0 not (default)
%       if =2, plot logarithmic scale both axes
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141024, initial
% David N. Bresch, david.bresch@gmail.com, 20141025, cleanup
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
        EL=zeros(1,n_hazards);
        for hazard_i=1:n_hazards
            if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                ED(hazard_i)=country_risk(entity_i).res.hazard(hazard_i).EDS.ED; % we need for sort later
                res(hazard_i).ED=ED(hazard_i);
                res(hazard_i).EDoL=country_risk(entity_i).res.hazard(hazard_i).EDS.ED/...
                    country_risk(entity_i).res.hazard(hazard_i).EDS.Value*1000;
                res(hazard_i).peril_ID=country_risk(entity_i).res.hazard(hazard_i).EDS.hazard.peril_ID;
                res(hazard_i).annotation_name=country_risk(entity_i).res.hazard(hazard_i).EDS.annotation_name;
                
                if print_unsorted
                    fprintf('  %s EL=%f (%f%%oo)   %s\n',...
                        res(hazard_i).peril_ID,res(hazard_i).ED,res(hazard_i).EDoL,...
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
            [~,EL_index] = sort(ED); % sort EDs descendingly
            
            for EL_i=n_hazards:-1:1
                fprintf('  %s EL=%f (%f%%oo)   %s\n',...
                    res(EL_index(EL_i)).peril_ID,res(EL_index(EL_i)).ED,res(EL_index(EL_i)).EDoL,...
                    res(EL_index(EL_i)).annotation_name);
            end % EL_i
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
