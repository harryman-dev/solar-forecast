# Solar forecast
AI-based prediction of the solar yield for the current and the following day using a random forest regressor.
The input parameters are collected in FHEM (in a separate table) and the calculated forecast is returned to FHEM via MQTT protocol.

The meteorological input parameters are obtained from the MOSMIX system of the DWD (German Weather Service).
The sun angles are calculated using the FHEM Astro module.

Logic:
The forecast will be carried out in two steps:
1. forecast of brightness with global radiation, sunshine duration and sun angle as input parameters
2. forecast of PV power with brightness, temperature and sun angle as input parameters

The forecast is deliberately made in two steps, as this increases the accuracy of the model.
The best parameters of the random forest regressor are determined by hypertuning.

## Purpose of files:
+ 000_datamodel.sql ... database table (MariaDB) and stored procedures
+ settings/config.py ... individual settings depends on the target platform
+ 010_featureengineering.ipynb ... feature engineering
+ 021_tune_model_brightness.ipynb ... hypertuning - model: brightness
+ 022_build_model_brightness.ipynb ... training - model: brightness
+ 023_predict_model_brightness.ipynb ... prediction - model: brightness
+ 031_tune_model_energy.ipynb ... hypertuning - model: energy
+ 032_build_model_energy.ipynb ... training - model: energy
+ 033_predict_model_energy.ipynb prediction - model: energy
+ 040_prediction.py ... final (productive) script for solar energy forecast 
+ 99_mySolarForecastUtils.pm ... FHEM-Modul contains all activities around the forecast
+ requirements.txt ... requirement file (related to the productive environment: 040_prediction.py)
+ solar-forecast.sh ... command script for 040_prediction.py


Further information can be found at https://smarthome.kaempf-nk.de/pv-ertragsprognose/index.html (in German).

