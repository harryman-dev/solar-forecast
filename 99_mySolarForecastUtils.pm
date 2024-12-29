##############################################################################################################################
# Modul to handle all activities around the SolarForecast in FHEM
##############################################################################################################################

package main;

use strict;
use warnings;

LoadModule("Astro");

sub
mySolarForecastUtils_Initialize($$)
{
  my ($hash) = @_;
}

##############################################################################################################################
# calculation of sun position for the current evaluation period (today and tomorrow)
##############################################################################################################################
sub mySolarForecastUtils_calcSunPosition()
{
	my $SunAlt;
	my $SunAz;
	my $timeOffset = 0;
	my $k;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	
	my $Azimut = ReadingsVal("du_SunPos","azimut",0);
	my $AziDelta;
  
	for(my $i=0; $i<=1; $i++) {
	
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time+$timeOffset);
		$year += 1900;
		++$mon;
	
		fhem("setreading du_SunPos fc".$i."_Date ".$year."-".sprintf("%02d",$mon)."-".sprintf("%02d",$mday));
	
		for(my $j= 4; $j<24; $j++) {

			$k = $j-1;
			
			$SunAlt = Astro_Get(undef,undef,"text","SunAlt", $year."-".sprintf("%02d",$mon)."-".sprintf("%02d",$mday)." ".sprintf("%02d",$k).":30:00");
			if ($SunAlt < 0) {$SunAlt = 0};
			fhem("setreading du_SunPos fc".$i."_".$j."_SunAlt $SunAlt");

			$SunAz = Astro_Get(undef,undef,"text","SunAz", $year."-".sprintf("%02d",$mon)."-".sprintf("%02d",$mday)." ".sprintf("%02d",$k).":30:00");
			$SunAz -=$Azimut;
			if ($SunAz > 180) {$SunAz = 180- ($SunAz - 180)};
			if ($SunAlt == 0) {$SunAz = 0};
			
			fhem("setreading du_SunPos fc".$i."_".$j."_SunAz $SunAz");
		}
		
		$timeOffset += 86400;
	}
}

##############################################################################################################################
# get the index for the given hour
# para: hour
##############################################################################################################################
sub mySolarForecastUtils_getHourIndex($){

	my ($hour) = @_;
	
	for(my $i = 1; $i <=44; $i++) {
		my @parts = split /[ :]/, ReadingsVal("WetterFc2","hfc".$i."_day_of_week","");
		
		if ($parts[1] == sprintf("%02d",$hour)) {
			return $i;
		}
	}
	return 0;
}

##############################################################################################################################
# save current values provided by DWD and locally in order to fill the AI model (runs from 04:02 to 23:02 hourly)
##############################################################################################################################
sub mySolarForecastUtils_saveCurValuesSolarFc(){

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	
	my $para = ReadingsVal("WetterFc","fc0_".$hour."_TTT",0).",";
	$para .= ReadingsVal("EG_au_MS_1","temperatureAV60m",0).",";
	$para .= ReadingsVal("WetterFc","fc0_".$hour."_RRad1",0).",";
	$para .= ReadingsVal("WetterFc","fc0_".$hour."_Rad1h",0).",";
	$para .= ReadingsVal("du_SunPos","fc0_".$hour."_SunAlt",0).",";
	$para .= ReadingsVal("du_SunPos","fc0_".$hour."_SunAz",0).",";
	$para .= ReadingsVal("WetterFc","fc0_".$hour."_SunD1",0).",";
	$para .= ReadingsVal("WetterFc","fc0_".$hour."_Neff",0).",";
	$para .= ReadingsVal("WetterFc2","hfc".mySolarForecastUtils_getHourIndex($hour)."_cloudCover",0).",";
	$para .= ReadingsVal("EG_au_MS_1","brightnessAV60m",0).",";
	$para .= ReadingsVal("du_KG_ws_WR_Ges","EHour",0);
		
	system("/opt/fhem/saveCurValuesSolarFc.sh $para >> /opt/fhem/log/saveCurValuesSolarFc.log");
	
	fhem("setreading du_KG_ws_WR_Ges EHourLast ".ReadingsVal("du_KG_ws_WR_Ges","EToday",0));
}

##############################################################################################################################
# save forecast values provided by DWD in order to fill the AI model for today and tomorrow (runs from 04:02 to 23:02 hourly)
##############################################################################################################################
sub mySolarForecastUtils_saveNextValuesSolarFc(){

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	++$mon;
	
	my $para = "";

	my $curHour = mySolarForecastUtils_getHourIndex($hour)+1;
	
	for(my $i = 4; $i <24; $i++) {		# today
	
		if ($i > $hour) {
			$para  = $year.",";
			$para .= $mon.",";
			$para .= $mday.",";
			$para .= $i.",";
			$para .= ReadingsVal("WetterFc","fc0_".$i."_TTT",0).",";
			$para .= ReadingsVal("WetterFc","fc0_".$i."_RRad1",0).",";
			$para .= ReadingsVal("WetterFc","fc0_".$i."_Rad1h",0).",";
			$para .= ReadingsVal("du_SunPos","fc0_".$i."_SunAlt",0).",";
			$para .= ReadingsVal("du_SunPos","fc0_".$i."_SunAz",0).",";
			$para .= ReadingsVal("WetterFc","fc0_".$i."_SunD1",0).",";
			$para .= ReadingsVal("WetterFc","fc0_".$i."_Neff",0).",";
			$para .= ReadingsVal("WetterFc2","hfc".$curHour."_cloudCover",0);

			system("/opt/fhem/saveNextValuesSolarFc.sh $para >> /opt/fhem/log/saveNextValuesSolarFc.log");
			$curHour++;
		}
	}
	
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time + 86400);
	$year = $year+1900;
	++$mon;
	
	$curHour = $curHour + 4;
	
	for(my $i = 4; $i <24; $i++) {		# tomorrow
	
		$para  = $year.",";
		$para .= $mon.",";
		$para .= $mday.",";
		$para .= $i.",";
		$para .= ReadingsVal("WetterFc","fc1_".$i."_TTT",0).",";
		$para .= ReadingsVal("WetterFc","fc1_".$i."_RRad1",0).",";
		$para .= ReadingsVal("WetterFc","fc1_".$i."_Rad1h",0).",";
		$para .= ReadingsVal("du_SunPos","fc1_".$i."_SunAlt",0).",";
		$para .= ReadingsVal("du_SunPos","fc1_".$i."_SunAz",0).",";
		$para .= ReadingsVal("WetterFc","fc1_".$i."_SunD1",0).",";
		$para .= ReadingsVal("WetterFc","fc1_".$i."_Neff",0).",";
		$para .= ReadingsVal("WetterFc2","hfc".$curHour."_cloudCover",0);

		system("/opt/fhem/saveNextValuesSolarFc.sh $para >> /opt/fhem/log/saveNextValuesSolarFc.log");
		$curHour++;
	}
	
}

##############################################################################################################################
# Create output for Chart graph
##############################################################################################################################
sub mySolarForecastUtil_EnergyFc()
{

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	++$mon;
	
	my $date = $year.'-'.sprintf("%02d",($mon)).'-'.sprintf("%02d",($mday)).'_';
	my $ret = "";

	for(my $i = 0; $i < 24; $i++) {
		$ret .= $date.sprintf("%02d",($i-1)).':30:00 '.ReadingsVal("du_EnergyFc","D0_H".sprintf("%02d",($i)),0)."\r\n";
	}

	return $ret;
}

1;