function damage_weight = cr_get_damage_weight(damage_per_GDP)
% MODULE:
%   country_risk
% NAME:
%   cr_get_damage_weight
% PURPOSE:
%   Get the weight of a specific damage caused by a natural hazard, i.e.,
%   the factor it will be multiplied with in the calculation of the
%   economic loss caused by that event (see
%   climada_calculate_economic_loss). 
%   The underlying assumption is that damages up to a certain threshold
%   (defined in terms of damage per GDP) do not affect a country's national
%   economy, but the bigger the damage, the more importance/weight is given
%   to the country's socioeconomic strength and preparedness for disasters
%   (as indicated by the country_damage_factor calculated in 
%   climada_calculate_economic_loss).
% CALLING SEQUENCE:
%   damage_weight = cr_get_damage_weight(damage_per_GDP)
% EXAMPLE:
%   damage_weight = cr_get_damage_weight(0.02)
% INPUT:
%   damage_per_GDP: the ratio of the damage caused by a specific event to
%   the GDP of the country where the event occurred
% OUTPUT:
%   damage_weight: The weighting factor for the input damage per GDP
% MODIFICATION HISTORY:
% Melanie Bieli, melanie.bieli@bluewin.ch 20150101, initial

% set parameters
damage_threshold=0.0001; % below this threshold, damage_weight is set to zero 
damage_size_exp=1.3; % >1: concave, <1 convex, 1: linear
scaling_factor=1;

% calculate damage_weight
damage_weight=scaling_factor*(min(max(damage_per_GDP-damage_threshold,0).^(damage_size_exp)...
    /((1-damage_threshold)^damage_size_exp),1));

%plot(damage,damage_weight)
end

