#  Copyright (C) 2024  Harry Kämpf kontakt@kaempf-nk.de
#  
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
#
# Purpose:
# define some global settings in general and depends on the platform

import platform

class Common:
    """Class contains global and platform depending settings"""

    HOST_NAME = '<<hostname>>'                                       # hostname data base server (maria db) and MQTT server
    DB_PORT = <<port>>                                                  # data base port
    DB_NAME = 'fhem'                                                # name of the database
    DB_USER_NAME = '<<dbuser>>'                                         # name of data base user
    DB_USER_PASSWORD = '<<password>>'                 # passwort of data base user

    MQTT_PORT = 1883                                                # MQTT port
    MQTT_TOPIC = "EnergyFc"                                         # MQTT topic

    if platform.machine().lower().startswith('x86_64'):             # platform specific section for productive environment (NAS server)
        DEBUG = False
        MODEL_PATH = '/volume1/homes/boss/solar-forecast/models/'
    elif platform.machine().lower().startswith('armv7l'):           # platform specific section for productive environment (Raspberry PI 2)
        DEBUG = False
        MODEL_PATH = '/home/<<user>>/solar-forecast/models/'
    else:                                                           # platform specific section for developer environment (Windows PC)
        DEBUG = True
        MODEL_PATH = './models/'
