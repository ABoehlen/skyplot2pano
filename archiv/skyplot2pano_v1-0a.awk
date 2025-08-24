#!/usr/bin/awk -f
################################################################################################
#
# Filename:     skyplot2pano.awk
# Author:       Adrian Boehlen
# Date:         05.07.2023
# Version:      1.0
#
# Purpose:      - berechnet anhand der Ergebnisdatei (*.txt) einer Skyplot-Berechnung
#                 eine Profillinie, wobei nur reale Gelaendekanten beruecksichtigt
#                 werden.
#
#               Voraussetzungen
#               - der Skyplot muss in der Winkeleinheit Gon berechnet worden sein.
#               - die gewuenschte Bildbreite kann ueber den Scriptaufruf mitgegeben werden
#                 oder wird ansonsten mit 800 (mm) festgelegt.
#               - das Limit (x/y-Distanz zum Rand des Hoehenmodells) kann ueber den Scriptaufruf
#                 in km mitgegeben werden oder wird ansonsten mit 300000 m festgelegt.
#
################################################################################################

BEGIN {
  if (!bildbr)
    bildbr = 800;
	
  if (!limit)
    limit = 300000;
  else
    limit = limit * 1000;
  
  if (ARGC != 2) {
    printf("\n***************************************************************************************************\n")   > "/dev/stderr";
    printf("    Usage: skyplot2pano.awk  <Skyplot txt File> > <Output csv File>\n")                                     > "/dev/stderr";
    printf("       or\n")                                                                                               > "/dev/stderr";
    printf("    awk -v bildbr=<value> -f <full path>/skyplot2ano.awk <Skyplot txt File> > <Output csv File>\n")         > "/dev/stderr";
    printf("***************************************************************************************************\n\n")   > "/dev/stderr";
    beende = 1; # um END-Regel zum sofortigen Beenden zu erzwingen
    exit;
  }
}

# Ergebnisdatei einlesen und in Arrays speichern
$1 ~ /^[1-9]/ {
  azi[NR] = $1;
  hoehenwinkel[NR] = $2;
  distanz[NR] = $3;
}

END {
  # damit END nicht ausgefuehrt wird, wenn kein File gelesen wurde
  if (beende == 1)
    exit;

  # Bildbegrenzung links und rechts festhalten
  aziLi = azi[10];
  aziRe = azi[NR];

  # Oeffnungswinkel bestimmen
  # 1 Gon im Bildkoordinatensystem ermitteln
  # rekonstruieren der azimutalen Aufloesung in Gon
  oeffWink = aziRe - aziLi;
  gonInMM = bildbr / oeffWink;
  aufloesAzi = oeffWink / (length(azi) - 1);

  # ausgehend von einer Zylinderprojektion wird der Umfang
  # und der Radius des Projektionszylinders abgeleitet
  umfang = 400 / oeffWink * bildbr;
  radPr = umfang / (2 * pi());

  # am linken Bildrand beginnen
  abstX = 0;
  
  # 1. Zeile mit den Feldbezeichnungen einfuegen
  printf("%s, %s, %s, %s\n", "X", "Y", "Dist", "Limit");

  # X/Y in Bildkoordinaten fuer jeden Eintrag der Ergebnisdatei berechnen
  # der horizontale Abstand der Punkte entspricht einem Gon im Bildkoordinatensystem,
  # mulitpliziert mit der azimutalen Aufloesung in Gon
  # der vertikale Abstand der Punkte entspricht der Gegenkathete, wenn der
  # Projektionszylinderradius als Ankathete und der Hoehenwinkel als Alpha betrachtet wird
  # ----
  # fuer jedes Azimut ist anhand des gegebenen Limits die entsprechende Distanz zum Rand des
  # Hoehenmodell-Ausschnitts mittels Dreiecksberechnung zu ermitteln. Dabei gilt:
  # die Ankathete entspricht dem Limit, das Azimut dem Winkel Alpha, umgerechnet auf einen Wert 
  # zwischen 0 und 50 Gon
  for (i = 10; i <= NR; i++ ) {
    if (azi[i] >=0 && azi[i] < 50)
	  entfGre = hypotenuse(limit, azi[i]);
    else if (azi[i] >= 50 && azi[i] < 100)
	  entfGre = hypotenuse(limit, 100 - azi[i]);
	else if (azi[i] >= 100 && azi[i] < 150)
	  entfGre = hypotenuse(limit, azi[i] - 100);
	else if (azi[i] >= 150 && azi[i] < 200)
	  entfGre = hypotenuse(limit, 200 - azi[i]);
	else if (azi[i] >= 200 && azi[i] < 250)
	  entfGre = hypotenuse(limit, azi[i] - 200);
	else if (azi[i] >= 250 && azi[i] < 300)
	  entfGre = hypotenuse(limit, 300 - azi[i]);
	else if (azi[i] >= 300 && azi[i] < 350)
	  entfGre = hypotenuse(limit, azi[i] - 300);
	else if (azi[i] >= 350 && azi[i] < 400)
	  entfGre = hypotenuse(limit, 400 - azi[i]);
	  
	entfGre = int(entfGre) - 200;

    # Ist die Entfernung des Grenzpunktes der Sichtbarkeit gleich oder groesser der Begrenzung des Hoehenmodell-
    # Ausschnitts, muss dieser Punkt ignoriert werden, da er keine Gelaendekante, sondern nur den Rand des
    # Hoehenmodell-Ausschnittes repraesentiert.	
	if (distanz[i] >= entfGre) {
	  abstX = abstX + (gonInMM * aufloesAzi);
	  continue;
	}
	else {
      printf("%f, %f, %f, %d\n", abstX, radPr * tan(gon2rad(hoehenwinkel[i])), distanz[i], limit);
	  abstX = abstX + (gonInMM * aufloesAzi);
	}
  }
}

# Funktionen fuer die geometrischen Berechnungen
function pi() {
  return atan2(0, -1);
}

function gon2rad(gon) {
  return pi() / (400 / 2) * gon;
}

function hypotenuse(ankathete, alphaGon) {
  return ankathete / cos(gon2rad(alphaGon));
}

function tan(winkel) {
  return sin(winkel) / cos(winkel);
}

