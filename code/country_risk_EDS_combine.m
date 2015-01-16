function country_risk=country_risk_EDS_combine(country_risk)
% climada country risk
% MODULE:
%   country_risk
% NAME:
%   country_risk_EDS_combine
% PURPOSE:
%   Combine sub-hazards TC and TS in country_risk result structure
%   does NOT combine TR (rain)
%
%   Works properly with both country_risk_calc and
%   country_admin1_risk_calc output
%
%   Note assumes the TS EDS follows the TC EDS, does not search all EDSs
%   for matching ones, just: if TC, check whether next EDS is TC (and same
%   ocean basin, obviously), then combine.
%
%   prior call: country_risk_calc
% CALLING SEQUENCE:
%   res=country_risk_EDS_combine(country_risk)
% EXAMPLE:
%   res=country_risk_EDS_combine(country_risk)
% INPUTS:
%   country_risk: a structure as returned by country_risk_calc
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
%   res: a structure as returned by country_risk_calc, with TC and TS
%       combined
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150114, initial (only TC and TS)
%-

%global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('country_risk','var'),return;end

% PARAMETERS
%

n_entities=length(country_risk);

for entity_i=1:n_entities
    if isfield(country_risk(entity_i).res,'hazard') % country exposed
        n_hazards=length(country_risk(entity_i).res.hazard);
        for hazard_i=1:n_hazards-1
            if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                n_EDS=length(country_risk(entity_i).res.hazard(hazard_i).EDS);
                for EDS_i=1:max(n_EDS-1,1)
                    peril_ID=country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i).peril_ID;
                    if n_EDS>1
                        next_peril_ID=country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i+1).peril_ID;
                        if strcmp(peril_ID,'TC') && strcmp(next_peril_ID,'TS')
                            next_EDS=country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i+1);
                            country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i+1)=[]; % EMPTY
                        end
                    elseif hazard_i<n_hazards
                        next_peril_ID=country_risk(entity_i).res.hazard(hazard_i+1).EDS(1).peril_ID;
                        if strcmp(peril_ID,'TC') && strcmp(next_peril_ID,'TS')
                            next_EDS=country_risk(entity_i).res.hazard(hazard_i+1).EDS;
                            country_risk(entity_i).res.hazard(hazard_i+1).EDS=[]; % EMPTY
                        end
                    else
                        next_peril_ID='';
                    end
                    if strcmp(peril_ID,'TC') && strcmp(next_peril_ID,'TS')
                        fprintf('combining %s & %s: ',peril_ID,next_peril_ID);
                        country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i)=...
                            climada_EDS_combine(country_risk(entity_i).res.hazard(hazard_i).EDS,...
                            next_EDS);
                        fprintf('%s\n',country_risk(entity_i).res.hazard(hazard_i).EDS.annotation_name)
                    end % TC and TS
                end % EDS_i
            end % ~isempty(EDS)
        end % hazard_i
    end % country exposed
end % entity_i

end