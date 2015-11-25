
% create waterfall graphs and calculate damage as percentage of GDP
% for two example countries Dominican Republic and USA


% set time span
climada_global.present_reference_year = 2015;
timespan = climada_global.future_reference_year - climada_global.present_reference_year;
climada_global.font_scale = 1.3;


% -----Dom Rep-------------
annual_eco_growth = 0.0458;
[entity, entity_future, DFC, DFC_eco, DFC_cc] = country_risk_waterfall('Dominican Republic',annual_eco_growth);
GDP = 6.116*10^10;
GDP_future = GDP*(1+annual_eco_growth)^timespan;

fprintf('- Factor total assets/GDP: %2.2f\n',sum(entity.assets.Value)/GDP)
fprintf('- Factor assets future/today: %2.3f\n',sum(entity_future.assets.Value)/sum(entity.assets.Value))
fprintf('- Factor damage future/today: %2.3f\n',DFC_eco.damage/DFC.damage)
fprintf('\n')
fprintf('- Today''s damage as percentage of GDP (%d): %2.1f %%\n',2014,DFC.damage/GDP*100)
fprintf('- Eco damage as percentage of GDP (%d): %2.1f %%\n',climada_global.future_reference_year,DFC_eco.damage/GDP_future*100)
fprintf('- Cc damage as percentage of GDP (%d): %2.1f %%\n',climada_global.future_reference_year,DFC_cc.damage/GDP_future*100)
fprintf('\n')
fprintf('- Cc damage absolute increase: %2.1f %%\n', (DFC_cc.damage-DFC_eco.damage)/GDP_future*100);
fprintf('- Cc damage percentage increase: %2.1f %%\n', (DFC_cc.damage-DFC_eco.damage)/DFC_eco.damage*100);


% ------USA--------------
annual_eco_growth = 0.022;
[entity, entity_future, DFC, DFC_eco, DFC_cc] = country_risk_waterfall('USA',annual_eco_growth);
GDP = 1.667*10^13;
GDP_future = GDP*(1+annual_eco_growth)^timespan;

fprintf('- Factor total assets/GDP: %2.2f\n',sum(entity.assets.Value)/GDP)
fprintf('- Factor assets future/today: %2.3f\n',sum(entity_future.assets.Value)/sum(entity.assets.Value))
fprintf('- Factor damage future/today: %2.3f\n',DFC_eco.damage/DFC.damage)
fprintf('\n')
fprintf('- Today''s damage as percentage of GDP (%d): %2.1f %%\n',2014,DFC.damage/GDP*100)
fprintf('- Eco damage as percentage of GDP (%d): %2.1f %%\n',climada_global.future_reference_year,DFC_eco.damage/GDP_future*100)
fprintf('- Cc damage as percentage of GDP (%d): %2.1f %%\n',climada_global.future_reference_year,DFC_cc.damage/GDP_future*100)
fprintf('\n')
fprintf('- Cc damage absolute increase: %2.1f %%\n', (DFC_cc.damage-DFC_eco.damage)/GDP_future*100);
fprintf('- Cc damage percentage increase: %2.1f %%\n', (DFC_cc.damage-DFC_eco.damage)/DFC_eco.damage*100);


