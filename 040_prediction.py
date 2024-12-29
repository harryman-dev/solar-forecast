"""Module contains the final solar forecast prediction
   The predictions runs in two steps (brightness and finally energy) for the next two days (rest of today + tomorrow)"""

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#  Copyright (C) 2024  Harry Kämpf kontakt@kaempf-nk.de

import pickle
import json
import numpy as np
from sqlalchemy import create_engine, text
from paho.mqtt import client as mqtt
from settings import config as cfg

class Db:
    """Class contains all data base related actions"""

    def __init__(self):
        self.host = cfg.Common.HOST_NAME
        self.port = cfg.Common.DB_PORT
        self.name = cfg.Common.DB_NAME
        self.user = cfg.Common.DB_USER_NAME
        self.password = cfg.Common.DB_USER_PASSWORD
        self.cnx = None
        self.set_cnx()

    def set_cnx(self):
        """Initialize connection"""
        if self.cnx is None:
            self.cnx = create_engine('mysql+pymysql://'+self.user+':'+self.password+'@'+self.host+':'+str(self.port)+'/'+self.name, echo=False, future=True)

    def get_query(self, query):
        """Execute data base query"""
        with self.cnx.connect() as conn:
            result = conn.execute(text(query))
            rows = result.fetchall()
        return np.array(rows)

    def save_result(self, Proc, Year, Month, Day, Hour, Value):
        """Save result in the data base"""
        with self.cnx.connect() as conn:
            conn.execute(text("call "+Proc+"(:Year, :Month, :Day, :Hour, :Target)"), {'Year': Year, 'Month': Month, 'Day': Day, 'Hour': Hour, 'Target': Value})
            conn.commit()

    def close(self):
        """Close data base connection"""
        self.cnx.dispose()

class Pred:
    """Class contains the predictions"""

    def __init__(self, counter):
        self.debug = cfg.Common.DEBUG
        self.model_path = cfg.Common.MODEL_PATH
        self.cnx = Cnx
        self.mqtt = Mqtt
        self.counter = counter
        self.target = self.set_target()

        self.query = None
        self.model = None
        self.proc = None
        self.set_pred_env()

    def set_target(self):
        """Set the prediction target value"""
        if self.counter == 0:
            return 'Brightness'
        if self.counter > 0:
            return 'Energy'
        return None

    def set_pred_env(self):
        """Set some properties depends on the target value"""
        if self.target == 'Brightness':
            self.query = "select * from (select Brightness, Year, Month, Day, Hour, Rad1h, RRad1, SunAlt, SunAz, SunD1, CloudCover from SolarEnergyFc order by Year desc, Month desc, Day desc, Hour desc limit 40) AS subselect order by Year asc, Month asc, Day asc, Hour asc"
            self.model = self.model_path + "brightness.pkl"
            self.proc = "saveBrightnessHourFc"
        else:
            self.query = "select * from (select EnergyHour, Year, Month, Day, Hour, if (Brightness = 0, BrightnessFc, Brightness) as Brightness , SunAlt, SunAz, if (Temp is null, TTT, Temp) as Temp from SolarEnergyFc order by Year desc, Month desc, Day desc, Hour desc limit 40) AS subselect order by Year asc, Month asc, Day asc, Hour asc"
            self.model = self.model_path + "energy.pkl"
            self.proc = "saveEnergyHourFc"


    def make_pred(self):
        """Make the prediction"""

        data = self.cnx.get_query(self.query)       # read data from database
        
        data = np.hstack((data, np.zeros((data.shape[0], 3), dtype=bool)))
        
        if self.target == 'Brightness':
            data[:,11] = np.where((data[:,2]>=11) | (data[:,2]<=2), True, False)
            data[:,12] = np.where((data[:,2]==3) | (data[:,2]==4) | (data[:,2]==9) | (data[:,2]==10), True, False)
            data[:,13] = np.where((data[:,2]>=6) & (data[:,2]<=8), True, False)
            X = data[:, [5,6,7,8,9,10,11,12,13]]  # extract features
        else:
            data[:,9] = np.where((data[:,2]>=11) | (data[:,2]<=2), True, False)
            data[:,10] = np.where((data[:,2]==3) | (data[:,2]==4) | (data[:,2]==9) | (data[:,2]==10), True, False)
            data[:,11] = np.where((data[:,2]>=6) & (data[:,2]<=8), True, False)
            X = data[:, [5,6,7,8,9,10,11]]        # extract features

        model = pickle.load(open(self.model, 'rb')) # load existing model

        y_pred = model.predict(X)                   # make a prediction

        day_fc = 1
        hour_last = 23
        jdata = {}

        for i in reversed(range(len(y_pred))):

            if data[i,0] > 0:                       # Brightness or EnergyHour
                break

            Year = int(data[i,1])                   # extract date / time values from the dataset
            Month = int(data[i,2])
            Day = int(data[i,3])
            Hour = int(data[i,4])

            target_value = 0

            if Hour > hour_last:
                day_fc = 0
            else:
                hour_last = Hour

            if data[i,5] > 0:             # RadEff / Brightness
                if self.target == 'Brightness':
                    target_value =  int(y_pred[i])
                else:
                    target_value =  round(y_pred[i],3)

                if target_value < 0:
                    target_value = 0

                self.cnx.save_result(self.proc, Year, Month, Day, Hour, target_value)

                if self.target == 'Energy':
                    jdata["D"+str(day_fc)+"_H"+f"{Hour:02d}"] = str(target_value)

                if self.debug:
                    if self.target == 'Brightness':
                        print(i, Year, Month, Day, Hour, '   ', data[i,0] ,'   ', target_value)
                    else:
                        print(jdata)
            else:
                if self.target == 'Energy':
                    jdata["D"+str(day_fc)+"_H"+f"{Hour:02d}"] = "0"

        self.send_result(jdata)

        return True

    def send_result(self, jdata):
        """send the results for the energy prediction"""
        if self.target == 'Energy':
            self.mqtt.send_data(jdata)

class Mqtt:
    """Class contains the complete MQTT handling"""

    def __init__(self):
        self.host = cfg.Common.HOST_NAME
        self.port = cfg.Common.MQTT_PORT
        self.topic = cfg.Common.MQTT_TOPIC

        self.mqttc = None
        self.set_client()

    def set_client(self):
        """Set the MQTT client"""
        self.mqttc = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "du_"+self.topic)

    def send_data(self, mqtt_msg):
        """Send data to the MQTT server"""
        self.mqttc.connect(self.host, self.port)
        self.mqttc.subscribe(self.topic)
        self.mqttc.publish(self.topic,json.dumps(mqtt_msg))
        self.mqttc.disconnect()

Cnx = Db()
Mqtt = Mqtt()

for count in range(2):
    pred = Pred(count)
    rc = pred.make_pred()

Cnx.close()
print(rc)
