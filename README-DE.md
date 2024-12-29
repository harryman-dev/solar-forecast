# Photovoltaik-Ertragsprognose
KI-basierte Vorhersage des PV-Ertrags für den aktuellen und den Folgetag mittels Random Forest Regressor
Die Eingangsparameter werden in FHEM in einer separaten Tabelle gesammelt und das Ergebnis (PV-Prognose) per MQTT-Protokoll an FHEM zurückgeliefert.

Die meteorologischen Eingangsparameter werden über das MOSMIX-System des DWD (Deutscher Wetterdienst) bezogen.
Die Sonnenwinkel werden mit dem FHEM Astro-Modul berechnet.

Logik:
Die Prognose erfolgt in zwei Schritten:
1. Prognose der Helligkeit aus der globalen Strahlung, Sonnenscheindauer und Sonnenwinkel als Eingangsparameter
2. Prognose der PV-Leistung aus Helligkeit, Temperatur und Sonnenwinkel als Eingangsparameter

Die Prognose erfolgt bewusst in zwei Schritten, da hierdurch die Genauigkeit des Models signifikant höher ist.
Per Hypertuning werden die besten Parameter des Random Forest Regressor ermittelt.

## Bedeutung der Files:
+ 000_datamodel.sql ... Datenbank-Tabelle (Maria DB) und stored Procedures
+ settings/config.py ... individuelle Settings in Abh. der Zielplattform
+ 010_featureengineering.ipynb ... Feature engineering
+ 021_tune_model_brightness.ipynb ... Hypertuning - Modell: Helligkeit
+ 022_build_model_brightness.ipynb ... Training - Modell: Helligkeit
+ 023_predict_model_brightness.ipynb ... Vorhersage - Modell: Helligkeit
+ 031_tune_model_energy.ipynb ... Hypertuning - Modell: Energie
+ 032_build_model_energy.ipynb ... Training - Modell: Energie
+ 033_predict_model_energy.ipynb Vorhersage - Modell: Energie
+ 040_prediction.py ... finales (produktives) Script zur PV-Ertragsprognose 
+ 99_mySolarForecastUtils.pm ... FHEM-Modul für alle Aktivitäten rund um die PV-Prognose
+ requirements.txt ... Requirement file (bezogen auf die Produktiv-Umgebung: 040_prediction.py)
+ solar-forecast.sh ... Aufruf von 040_prediction.py


Weiterführende Informationen sind auf https://smarthome.kaempf-nk.de/pv-ertragsprognose/index.html zu finden.

