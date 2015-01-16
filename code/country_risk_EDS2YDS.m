function country_risk=country_risk_EDS2YDS(country_risk)
% climada country risk
% MODULE:
%   country_risk
% NAME:
%   country_risk_EDS2YDS
% PURPOSE:
%   Convert event damage sets (EDS) to year damage sets (YDS) where
%   appropriate (currently TC, TS and TR, see climada_EDS2YDS, where
%   this is determined).
%
%   Works properly with both country_risk_calc and
%   country_admin1_risk_calc output
%
%   Makes most sense of country_risk_EDS_combine has been applied to the
%   country_risk rsult structure before
%
%   prior call: country_risk_EDS_combine
% CALLING SEQUENCE:
%   res=country_risk_EDS2YDS(country_risk)
% EXAMPLE:
%   res=country_risk_EDS2YDS(country_risk)
% INPUTS:
%   country_risk: a structure as returned by country_risk_calc
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
%   country_risk: a structure as returned by country_risk_calc, EDSs
%   converted into YDSs where appropriate
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150116, initial (TC, TS, TR)
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
                for EDS_i=1:n_EDS
                    load(country_risk(entity_i).res.hazard(hazard_i).hazard_set_file);
                    if isfield(hazard,'orig_yearset')
                        hazard=climada_hazard2octave(hazard); % Octave compatibility for -v7.3 mat-files
                        YDS=climada_EDS2YDS(country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i),hazard);
                        if ~isempty(YDS)
                            YDS=rmfield(YDS,'yyyy'); % to keep same fields as EDS
                            YDS=rmfield(YDS,'orig_year_flag'); % to keep same fields as EDS
                            country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i)=YDS;
                        end
                    end % isfield(hazard,'orig_yearset')
                end % EDS_i
            end % ~isempty(EDS)
        end % hazard_i
    end % country exposed
end % entity_i

end