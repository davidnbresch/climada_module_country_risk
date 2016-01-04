climada_module_country_risk
===========================

**Purpose**

This module runs all (available) perils for one country or for a list of countries. First, it allows generating the country assets (10 or 1 km resolution, based on night light intensity), second to generate the hazard event sets and second to run all damage calculations. The core function is ***country_risk_calc***, which does it all in one go. Read the [country risk manual](docs/climada_module_country_risk.pdf).
 
This module contains the former GDP entity module. GDP entity creates an asset base and centroids for a specific country for today and a selected future year, based on today's GDP and a future extrapolated GDP. The country assets are created with the main function ***climada_create_GDP_entity***. Read the [GDP entity manual](docs/climada_module_GDP_entity.pdf).

<br>

**Get to know** ***climada***

* Go to the [wiki](../../../climada/wiki/Home) and read the [introduction](../../../climada/wiki/Home) and find out what _**climada**_ and ECA is. 
* Are you ready to start adapting? This wiki page helps you to [get started!](../../../climada/wiki/Getting-started)  
* Read more on [natural catastrophe modelling](../../../climada/wiki/NatCat-modelling) and look at the GUI that we have prepared for you.
* Read the [core ***climada*** manual (PDF)](../../../climada/docs/climada_manual.pdf?raw=true).

<br>

**Set-up**
In order to grant core climada access to additional modules, create a folder ‘modules’ in the core climada folder and copy/move any additional modules into climada/modules, without 'climada_module_' in the filename. 

E.g. if the addition module is named climada_module_MODULE_NAME, we should have
.../climada the core climada, with sub-folders as
.../climada/code
.../climada/data
.../climada/docs
and then
.../climada/modules/MODULE_NAME with contents such as 
.../climada/modules/MODULE_NAME/code
.../climada/modules/MODULE_NAME/data
.../climada/modules/MODULE_NAME/docs
this way, climada sources all modules' code upon startup

see climada/docs/climada_manual.pdf to get started

copyright (c) 2016, David N. Bresch, david.bresch@gmail.com all rights reserved.
