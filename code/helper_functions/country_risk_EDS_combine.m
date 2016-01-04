function [country_risk,EDC]=country_risk_EDS_combine(country_risk)
% climada country risk
% MODULE:
%   country_risk
% NAME:
%   country_risk_EDS_combine
% PURPOSE:
%   Combine sub-hazards TC and TS in country_risk result structure
%   does NOT combine TR (rain). See output EDC for maximally combined EDS.
%
%   Works properly with both country_risk_calc and
%   country_admin1_risk_calc output
%
%   Note assumes the TS EDS directly follows the TC EDS, does not search all EDSs
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
%   country_risk: the same structure as returned by country_risk_calc,
%       with TC and TS combined
%   EDC: the maximally combined EDS, the event damage collector
%       i.e. only one fully combined EDS per hazard and region (i.e. on for
%       all TC atl, EQ glb...). Only assumption: the summation happens over
%       EDS.damage of exact same length, i.e. should two perils (and
%       regions) have exactly the same number of events, the code sums them
%       up, as long as the peril_ID(1) match (it does never sum up EQ and
%       TC, as E and T are different, but would sum up TC atl and TC epa
%       should both basin hazard event sets have the same number of events.
%       Therefore, inspect the EDC(i).EDS.annotation_name carefully, it is
%       the cllection of all annotation names.
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150114, initial (only TC and TS)
% David N. Bresch, david.bresch@gmail.com, 20150203, maximally combined EDS
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

if nargout>1 % EDC requested
    
    fprintf('\nevent damage collector (EDC):\n');
    n_entities=length(country_risk);
    EDS_sizes=[];next_EDS=1;EDC=[]; % init
    
    % and now the maximally combined EDS
    for entity_i=1:n_entities
        if isfield(country_risk(entity_i).res,'hazard') % country exposed
            n_hazards=length(country_risk(entity_i).res.hazard);
            for hazard_i=1:n_hazards
                if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                    n_EDS=length(country_risk(entity_i).res.hazard(hazard_i).EDS);
                    for EDS_i=1:n_EDS
                        EDS2add=country_risk(entity_i).res.hazard(hazard_i).EDS(EDS_i); % the EDS to add
                        pos=find(EDS_sizes == length(EDS2add.damage)); % find damage vector of same length
                        % safety check for first digit of peril_ID to match
                        if ~isempty(pos) && ~strcmp(EDS2add.peril_ID(1),EDC(pos).EDS.peril_ID(1)),pos=[];end
                        if isempty(pos) % alas, a new hazard or region
                            fprintf('new EDC %s: %s\n',EDS2add.peril_ID,EDS2add.annotation_name);
                            EDC(next_EDS).EDS=EDS2add; % copy
                            EDS_sizes(next_EDS)=length(EDS2add.damage);
                            EDC(next_EDS).EDS=rmfield(EDC(next_EDS).EDS,'ED_at_centroid');
                            EDC(next_EDS).EDS=rmfield(EDC(next_EDS).EDS,'assets');
                            EDC(next_EDS).EDS=rmfield(EDC(next_EDS).EDS,'damagefunctions');
                            [~,fP]=fileparts(EDS2add.hazard.filename);
                            peril_ID_pos=strfind(fP,EDS2add.peril_ID);
                            if ~isempty(peril_ID_pos)
                                EDC(next_EDS).EDS.comment=fP(peril_ID_pos(end)-4:peril_ID_pos(end)+1);
                            else
                                EDC(next_EDS).EDS.comment=fP;
                            end
                            next_EDS=next_EDS+1;
                        else
                            EDC(pos).EDS.damage=EDC(pos).EDS.damage+EDS2add.damage;
                            EDC(pos).EDS.Value =EDC(pos).EDS.Value+EDS2add.Value;
                            EDC(pos).EDS.annotation_name=[EDC(pos).EDS.annotation_name ' ' EDS2add.annotation_name];
                            fprintf('adding %s to %s: %s\n',EDS2add.peril_ID,EDC(pos).EDS.peril_ID,EDS2add.annotation_name);
                        end
                    end % EDS_i
                end % ~isempty(EDS)
            end % hazard_i
        end % country exposed
    end % entity_i
    
    for EDC_i=1:length(EDC)
        EDC(EDC_i).EDS.ED=EDC(EDC_i).EDS.damage*EDC(EDC_i).EDS.frequency';
    end % EDC_i
end % nargout>1

end % country_risk_EDS_combine