/*	Copyright (C) 2024  Harry Kämpf kontakt@kaempf-nk.de
 
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.


	Purpose: database table and stored procedures to handle solar forecast parameters
*/

-- table to save the historical data, forecast values and predictions

drop table if exists SolarEnergyFc;
CREATE TABLE IF NOT EXISTS `SolarEnergyFc` (
  `TimeStamp`		datetime NOT NULL,
  `Year`   			int NOT NULL,
  `Month`  			int NOT NULL,
  `Day`    			int NOT NULL,
  `Hour`   			int NOT NULL,
  `TTT`				float NULL DEFAULT 0 COMMENT "Temperature 2m above surface - source: DWD",
  `Temp`    		float NULL DEFAULT null COMMENT "Temperature - source: local sensor",
  `RRad1`			int NULL DEFAULT 0 COMMENT "Global irradiance within the last hour % (0..80) - source: DWD",
  `Rad1h`  			int NULL DEFAULT 0 COMMENT "Global irradiance kJ/m2 - source: DWD",
  `SunAlt`  		float NULL DEFAULT 0 COMMENT "Sun altitude - source: FHEM module Astro",
  `SunAz`  			float NULL DEFAULT 0 COMMENT "Sun azimuth - source: FHEM module Astro",
  `SunD1`  			int NULL DEFAULT 0 COMMENT "Sunshine duration during the last Hour s - source: DWD",
  `Neff`  			int NULL DEFAULT 0 COMMENT "Effective cloud cover % (0..100) - source: DWD",
  `CloudCover`		int NULL DEFAULT 0 COMMENT "Effective cloud cover % (0..100) - source: OpenWeather",
  `Brightness` 		int NULL DEFAULT 0 COMMENT "Brightness lux - source: local sensor",
  `BrightnessFc`	int NULL DEFAULT 0 COMMENT "Brightness forecast lux - source: prediction",
  `EnergyHour` 		float NULL DEFAULT 0 COMMENT "Total energy/hour kWh - source: local converter",
  `EnergyHourFc`	float NULL DEFAULT 0 COMMENT "Total energy/hour forecast kWh - source: prediction",
  PRIMARY KEY (Year,Month,Day,Hour),
  INDEX (Year,Month,Day,Hour)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


-- procedure to save current values provided by DWD and locally

DELIMITER |

CREATE or Replace procedure saveCurValuesSolarFc(in TTT float, IN Temp float, IN RRad1 int, IN Rad1h int,IN SunAlt float, IN SunAz float, IN SunD1 int, IN Neff int, IN CloudCover int, IN Brightness int, IN EnergyHour float )
BEGIN
	DECLARE TimeStamp datetime;
	DECLARE sSQL varchar(1024);
	DECLARE sStmt varchar(1024);
	
	SET @TimeStamp = now();
	SET @Year = year(now());
	SET @Month = month(now());
	SET @Day = day(now());
	SET @Hour = hour(now());
	
	SET @TTT = TTT;
	SET @Temp = Temp;
	SET @RRad1 = RRad1;
	SET @Rad1h = Rad1h;
	SET @SunAlt = SunAlt;
	SET @SunAz = SunAz;
	SET @SunD1 = SunD1;
	SET @Neff = Neff;
	SET @CloudCover = CloudCover;
	SET @Brightness = Brightness;
	SET @EnergyHour = EnergyHour;
	
	SET sSQL := 'select count(*) into @iRows from SolarEnergyFc where Year=? and Month=? and Day=? and Hour=?';
	PREPARE sStmt FROM sSQL;
	EXECUTE sStmt USING @Year, @Month, @Day, @Hour;
	
	IF (@iRows >= 1) THEN
	    SET sSQL := 'update SolarEnergyFc set TimeStamp=?, TTT=?, Temp=?, RRad1=?, Rad1h=?, SunAlt=?, SunAz=?, SunD1=?, Neff=?, CloudCover=?, Brightness=?, EnergyHour=? where Year=? and Month=? and Day=? and Hour=?';
        PREPARE sStmt FROM sSQL;
        EXECUTE sStmt USING @TimeStamp, @TTT, @Temp, @RRad1, @Rad1h, @SunAlt, @SunAz, @SunD1, @Neff, @CloudCover, @Brightness, @EnergyHour, @Year, @Month, @Day, @Hour;
	ELSE
		SET sSQL := 'insert into SolarEnergyFc (TimeStamp, Year, Month, Day , Hour, TTT, Temp, RRad1, Rad1h, SunAlt, SunAz, SunD1, Neff, CloudCover, Brightness, EnergyHour) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)';
		PREPARE sStmt FROM sSQL;
		EXECUTE sStmt USING @TimeStamp, @Year, @Month, @Day, @Hour, @TTT, @Temp, @RRad1, @Rad1h, @SunAlt, @SunAz, @SunD1, @Neff, @CloudCover, @Brightness, @EnergyHour;
	END IF;

END; |
DELIMITER ;

GRANT EXECUTE ON PROCEDURE saveCurValuesSolarFc TO 'myfhem'@'%';
flush privileges;

-- procedure to save forecast values provided by DWD

DELIMITER |

CREATE or Replace procedure saveNextValuesSolarFc(IN Year int,IN Month int,IN Day int,IN Hour int,in TTT float, IN RRad1 int,IN Rad1h int, IN SunAlt float, IN SunAz float, IN SunD1 int, IN Neff int, IN CloudCover int)
BEGIN
	DECLARE TimeStamp datetime;
	DECLARE sSQL varchar(1024);
	DECLARE sStmt varchar(1024);
	
	SET @TimeStamp = now();
	SET @Year = Year;
	SET @Month = Month;
	SET @Day = Day;
	SET @Hour = Hour;
	
	SET @TTT = TTT;
	SET @RRad1 = RRad1;
	SET @Rad1h = Rad1h;
	SET @SunAlt = SunAlt;
	SET @SunAz = SunAz;
	SET @SunD1 = SunD1;
	SET @Neff = Neff;
	SET @CloudCover = CloudCover;
	
	SET sSQL := 'select count(*) into @iRows from SolarEnergyFc where Year=? and Month=? and Day=? and Hour=?';
	PREPARE sStmt FROM sSQL;
	EXECUTE sStmt USING @Year, @Month, @Day, @Hour;
	
	IF (@iRows >= 1) THEN
	    SET sSQL := 'update SolarEnergyFc set TimeStamp=?, TTT=?, RRad1=?, Rad1h=?, SunAlt=?, SunAz=?, SunD1=?, Neff=?, CloudCover=? where Year=? and Month=? and Day=? and Hour=?';
        PREPARE sStmt FROM sSQL;
        EXECUTE sStmt USING @TimeStamp, @TTT, @RRad1, @Rad1h, @SunAlt, @SunAz, @SunD1, @Neff, @CloudCover, @Year, @Month, @Day, @Hour;
	ELSE
		SET sSQL := 'insert into SolarEnergyFc (TimeStamp, Year, Month, Day , Hour, TTT, RRad1, Rad1h, SunAlt, SunAz, SunD1, Neff, CloudCover) values (?,?,?,?,?,?,?,?,?,?,?,?,?)';
		PREPARE sStmt FROM sSQL;
		EXECUTE sStmt USING @TimeStamp, @Year, @Month, @Day ,@Hour, @TTT, @RRad1, @Rad1h, @SunAlt, @SunAz, @SunD1, @Neff, @CloudCover;
	END IF;

END; |
DELIMITER ;

GRANT EXECUTE ON PROCEDURE saveNextValuesSolarFc TO 'myfhem'@'%';
flush privileges;

-- procedure to save the brightness prediction result

DELIMITER |

CREATE or Replace procedure saveBrightnessHourFc(in Year int, IN Month int, IN Day int, IN Hour int, IN Target int)
BEGIN
	DECLARE sSQL varchar(1024);
	DECLARE sStmt varchar(1024);
	
	SET @TimeStamp = now();
	SET @Year = Year;
	SET @Month = Month;
	SET @Day = Day;
	SET @Hour = Hour;
	SET @Target = Target;

	SET sSQL := 'update SolarEnergyFc set BrightnessFc=?, TimeStamp=? where Year=? and Month=? and Day=? and Hour=?';
    PREPARE sStmt FROM sSQL;
    EXECUTE sStmt USING @Target, @TimeStamp, @Year, @Month, @Day, @Hour;

END; |
DELIMITER ;

GRANT EXECUTE ON PROCEDURE saveBrightnessHourFc TO 'mypred'@'%';
flush privileges;

-- procedure to save the energy prediction result

DELIMITER |

CREATE or Replace procedure saveEnergyHourFc(in Year int, IN Month int, IN Day int, IN Hour int, IN Target float)
BEGIN
	DECLARE sSQL varchar(1024);
	DECLARE sStmt varchar(1024);
	
	SET @TimeStamp = now();
	SET @Year = Year;
	SET @Month = Month;
	SET @Day = Day;
	SET @Hour = Hour;
	SET @Target = Target;

	SET sSQL := 'update SolarEnergyFc set EnergyHourFc=?, TimeStamp=? where Year=? and Month=? and Day=? and Hour=?';
    PREPARE sStmt FROM sSQL;
    EXECUTE sStmt USING @Target, @TimeStamp, @Year, @Month ,@Day, @Hour;

END; |
DELIMITER ;

GRANT EXECUTE ON PROCEDURE saveEnergyHourFc TO 'mypred'@'%';
flush privileges;
