#!/usr/bin/awk -f
################################################################################################
#
# Filename:     skyplot2pano.awk
# Author:       Adrian Boehlen
# Date:         06.07.2023
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
  for (i = 10; i <= NR; i++ ) {
    maxEntf = distGre(limit, azi[i])
    if (maxEntf == -1) {
      printf("\nUngueltiges Azimut\nAbbruch\n") > "/dev/stderr";
      exit;
    }
	# Distanz zur Begrenzung des Hoehenmodell-Ausschnitts geringfuegig reduzieren
    maxEntf = int(maxEntf) - 200;

    # Ist die Entfernung des Grenzpunktes der Sichtbarkeit gleich oder groesser der Begrenzung des Hoehenmodell-
    # Ausschnitts, muss dieser Punkt ignoriert werden, da er keine Gelaendekante, sondern nur den Rand des
    # Hoehenmodell-Ausschnittes repraesentiert.	
    if (distanz[i] >= maxEntf) {
      abstX = abstX + (gonInMM * aufloesAzi);
      continue;
    }
    else {
      printf("%f, %f, %f, %d\n", abstX, radPr * tan(gon2rad(hoehenwinkel[i])), distanz[i], limit);
      abstX = abstX + (gonInMM * aufloesAzi);
    }
  }
}


# fuer jedes Azimut ist die Distanz zum Rand des Hoehenmodell-Ausschnitts mittels Dreiecksberechnung
# zu ermitteln. Dabei gilt:
# die Ankathete entspricht der Haelfte der Mittelsenkrechten, das Azimut dem Winkel Alpha, jeweils
# umgerechnet auf einen Wert zwischen 0 und 50 Gon
# bei einem ungueltigen Azimut (< 0 oder > 400) wird -1 zurueckgegeben
function distGre(haelfteMittelsenkr, aziGon,    dist) {
  if (aziGon >=0 && aziGon < 50)
    return dist = hypotenuse(haelfteMittelsenkr, aziGon);
  else if (aziGon >= 50 && aziGon < 100)
    return dist = hypotenuse(haelfteMittelsenkr, 100 - aziGon);
  else if (aziGon >= 100 && aziGon < 150)
    return dist = hypotenuse(haelfteMittelsenkr, aziGon - 100);
  else if (aziGon >= 150 && aziGon < 200)
    return dist = hypotenuse(haelfteMittelsenkr, 200 - aziGon);
  else if (aziGon >= 200 && aziGon < 250)
    return dist = hypotenuse(haelfteMittelsenkr, aziGon - 200);
  else if (aziGon >= 250 && aziGon < 300)
    return dist = hypotenuse(haelfteMittelsenkr, 300 - aziGon);
  else if (aziGon >= 300 && aziGon < 350)
    return dist = hypotenuse(haelfteMittelsenkr, aziGon - 300);
  else if (aziGon >= 350 && aziGon < 400)
    return dist = hypotenuse(haelfteMittelsenkr, 400 - aziGon);
  else
    return dist = -1;
}

##### Grundfunktionen fuer die geometrischen Berechnungen #####
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

