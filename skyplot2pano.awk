#!/usr/bin/awk -f
######################################################################################################################################################
#
# Filename:     skyplot2pano.awk
# Author:       Adrian Boehlen
# Date:         15.03.2024
# Version:      1.0
#
# Purpose:      Programm zur Erzeugung eines Panoramas mit aus Punkten gebildeten,
#               nach Distanz abgestuften "Silhouettenlinien"
#               Berechnung von Sichtbarkeitskennwerten
#               Eingegebene und abgeleitete Parameter werden in ein Protokoll geschrieben
#
# Requirements: - das Programm verwendet UNIX-Kommandos, muss also wenn unter Windows betrieben, in einem UNIX-Emulator ausgefuehrt werden
#               - die zu verwendenden Hoehenmodelle muessen im Format SCOP RDH vorliegen
#               - der Speicherort der verwendeten Hoehenmodelle muss in der Funktion 'dhmKopieren' festgelegt werden
#               - die Aufrufparameter der verwendeten Hoehenmodelle sind in der Funktion 'dhmBeschreibung' festzulegen
#               - das SCOP Utility Programm skyplot.exe muss vorhanden und über den Befehl 'skyplot' aufrufbar sein
#
# Usage:        skyplot2pano.awk  <X> <Y> <Z> <Name> <DHM> <Aufloes-Azi> <Azi links> <Azi rechts> <Bildbreite> <Min-Dist> <Max-Dist> <Aufloes-Dist>
#
######################################################################################################################################################

BEGIN {

  # Usage ausgeben, wenn zuwenig Argumente
  if (ARGC < 13) { 
    usage();
    exit;
  }
  else {
    ##### vorbereiten #####
    # speichern der Argumente in Variablen und nicht erlaubte Fliesskommazahlen auf Ganzzahlen runden
    x = ARGV[1];
    y = ARGV[2];
    z = ARGV[3];
    name = ARGV[4];
    dhm = ARGV[5];
    aufloesAzi = ARGV[6];
    aziLi = ARGV[7];
    aziLi = round(aziLi);
    aziRe = ARGV[8];
    aziRe = round(aziRe);
    bildbr = ARGV[9];
    bildbr = round(bildbr);
    minDist = ARGV[10] * 1000;
    minDist = round(minDist);
    maxDist = ARGV[11] * 1000;
    maxDist = round(maxDist);
    aufloesDist = ARGV[12] * 1000;
    aufloesDist = round(aufloesDist);

    # Array zuruecksetzen, damit Argumente nicht als Files interpretiert werden
    ARGV[1] = "";
    ARGV[2] = "";
    ARGV[3] = "";
    ARGV[4] = "";
    ARGV[5] = "";
    ARGV[6] = "";
    ARGV[7] = "";
    ARGV[8] = "";
    ARGV[9] = "";
    ARGV[10] = "";
    ARGV[11] = "";
    ARGV[12] = "";

    # Usage ausgeben, wenn zuviele Argumente
    if (ARGV[13] != "") {
      usage();
      exit;
    }

    # Plausibilitaet der Argumente pruefen. Andernfalls Fehlermeldung ausgeben und beenden
    if (aziLi < -400 || aziLi > 400)
      abbruch("\nlinkes Azimut muss zwischen -400 und +400 gon betragen.");

    if (aziRe < -400 || aziRe > 400)
      abbruch("\nrechtes Azimut muss zwischen -400 und +400 gon betragen.");

    if (aziLi >= aziRe)
      abbruch("\nlinkes Azimut muss kleiner sein als rechtes Azimut.");

    if (minDist < 0)
      abbruch("\ndie minimale Distanz kann nicht kleiner als 0 sein.");

    if (minDist >= maxDist)
      abbruch("\ndie minimale Distanz muss kleiner als die maximale Distanz sein.");

    # Oeffnungswinkel bestimmen
    # 1 gon im Bildkoordinatensystem ermitteln
    oeffWink = aziRe - aziLi;
    gonInMM = bildbr / oeffWink;

    # ausgehend von einer Zylinderprojektion wird der Umfang
    # und der Radius des Projektionszylinders abgeleitet
    umfang = 400 / oeffWink * bildbr;
    radPr = umfang / (2 * pi());

    # sky.rdh verlinken
    dhmKopieren(dhm, "sky.rdh");

    # Panoramadatei vorbereiten
    panofile = "sil_" name "_" aziLi "-" aziRe ".txt"
    printf("%7s, %7s, %9s, %9s, %8s, %5s, %5s, %6s, %5s\n", "X", "Y", "LageX", "LageY", "Dist", "Azi", "HWink", "Limit", "DiRel") > panofile;

    # aus 'maxDist' einen relativen Wert ableiten, um spaeter die einzelnen Punkte den Werten 0 bis 10
    # zuzuweisen (0 = naheliegendst, 10 = entferntest)
    distRel = (maxDist - minDist) / 10;


    ###########################################
    ##### 1. Teil: Extrempunkte berechnen #####
    ###########################################
    
    # Arrays zur Speicherung der Extrempunkte initialisieren
    exEntf["Distanz"] = 0;
    exNord["x"] = exOst["x"] = exSued["x"] = exWest["x"] = x;
    exNord["y"] = exOst["y"] = exSued["y"] = exWest["y"] = y;

    # Theoretische Aussichtsweite ermitteln
    maxSicht = theoausweit(z);
	
	# bei geringer theoretischen Aussichtsweite (niedriges Projektionszentrum) den Wert auf 100 km festlegen 
	if (maxSicht < 100000)
	  maxSicht = 100000;

    # SCOP LIMITS im Abstand des doppelten zuvor ermittelten Wertes festlegen
    N = maxDists(x, y, (maxSicht * 2), "N");
    E = maxDists(x, y, (maxSicht * 2), "E");
    S = maxDists(x, y, (maxSicht * 2), "S");
    W = maxDists(x, y, (maxSicht * 2), "W");

    # Erstellen des SCOP-Input-Files SKYPLOT.CMD mit 0.1 gon azimutaler Aufloesung fuer die Berechnung der Extrempunkte
    resfile = "extr.txt";
    skyplot("SKYPLOT.CMD", resfile, x, y, z, W, S, E, N, 0.1, aziLi, aziRe, "Extrempunkte");
    
    # Starten von skyplot und Unterdruecken der Ausgabe
    print "Berechnung der Extrempunkte...";
    system("skyplot < SKYPLOT.CMD > /dev/null");

    # Modellhoehe ermitteln
    mhoehe = modellhoehe(resfile);

    # numerische Ausgabe von Skyplot einlesen
    maxRec = daten_einlesen(resfile);
    
    # jeden horizontbildenden Punkt auswerten zwecks Bestimmung der Extrempunkte
    for (i = 1; i <= maxRec; i++ ) {
    
      ##### Entferntester Punkt ermitteln #####
      
      if (distanz[i] > exEntf["Distanz"]) {
        exEntf["Azi"] = azi[i];
        exEntf["Distanz"] = distanz[i];
        exEntf["Hoehenwinkel"] = hoehenwinkel[i];
      }
      
      ##### Extrempunkte N, E, S, W ermitteln #####
      
      # Distanz in der Ebene (math. Horizont) ermitteln
      dist0 = ankathete_aus_hypotenuse_und_winkel(distanz[i], hoehenwinkel[i]);
      
      split(bestimme_xy(x, y, dist0, azi[i]), xyAkt, " ")
      if (xyAkt[1] == -1)
        abbruch("\nungueltiges Azimut.");
      else {
        if (xyAkt[2] > exNord["y"]) {
          exNord["x"] = xyAkt[1];
          exNord["y"] = xyAkt[2];
		  exNord["Azi"] = azi[i];
		  exNord["Distanz"] = distanz[i];
		  exNord["Hoehenwinkel"] = hoehenwinkel[i];
        }
        if (xyAkt[1] > exOst["x"]) {
          exOst["x"] = xyAkt[1];
          exOst["y"] = xyAkt[2];
		  exOst["Azi"] = azi[i];
		  exOst["Distanz"] = distanz[i];
		  exOst["Hoehenwinkel"] = hoehenwinkel[i];
        }
        if (xyAkt[2] < exSued["y"]) {
          exSued["x"] = xyAkt[1];
          exSued["y"] = xyAkt[2];
		  exSued["Azi"] = azi[i];
		  exSued["Distanz"] = distanz[i];
		  exSued["Hoehenwinkel"] = hoehenwinkel[i];
        }
        if (xyAkt[1] < exWest["x"]) {
          exWest["x"] = xyAkt[1];
          exWest["y"] = xyAkt[2];
		  exWest["Azi"] = azi[i];
		  exWest["Distanz"] = distanz[i];
		  exWest["Hoehenwinkel"] = hoehenwinkel[i];
        }
      }
    }
	
	# Z Koordinate der Extrempunkte N, E, S, W bestimmen
	exNord["z"] = hoehe_aus_distanz_und_winkel(z, exNord["Distanz"], exNord["Hoehenwinkel"]);
    exOst["z"] = hoehe_aus_distanz_und_winkel(z, exOst["Distanz"], exOst["Hoehenwinkel"]);
    exSued["z"] = hoehe_aus_distanz_und_winkel(z, exSued["Distanz"], exSued["Hoehenwinkel"]);
    exWest["z"] = hoehe_aus_distanz_und_winkel(z, exWest["Distanz"], exWest["Hoehenwinkel"]);
    
    # X/Y/Z Koordinaten des entferntesten Punktes bestimmen
    dist0 = ankathete_aus_hypotenuse_und_winkel(exEntf["Distanz"], exEntf["Hoehenwinkel"]);
    if (split(bestimme_xy(x, y, dist0, exEntf["Azi"]), xyEntf, " ") == -1)
      abbruch("\nungueltiges Azimut.");
    exEntf["z"] = hoehe_aus_distanz_und_winkel(z, exEntf["Distanz"], exEntf["Hoehenwinkel"]);

    # aufraeumen
    system("rm -f " resfile);
    system("rm -f SKYPLOT.CMD");

    ###########################################
    ####### 2. Teil: Panorama berechnen #######
    ###########################################

    # Variablen zum Speichern der Punkte einrichten
    new(bisherigePte);
    existiert = 0;

    # Berechnungen im Abstand von 'aufloesDist' durchfuehren, bis 'maxDist' erreicht ist
    # um fehlerhafte Resultate zu vermeiden, muss der unmittelbare Nahbereich unterdrueckt werden
    if (minDist < 500)
      minDist = 500;

    for (i = minDist; i <= maxDist; i += aufloesDist) {

      # SCOP LIMITS festlegen
      N = maxDists(x, y, i, "N");
      E = maxDists(x, y, i, "E");
      S = maxDists(x, y, i, "S");
      W = maxDists(x, y, i, "W");

      # Erstellen des SCOP-Input-Files SKYPLOT.CMD
      resfile = "sky_" name i ".txt";
      skyplot("SKYPLOT.CMD", resfile, x, y, z, W, S, E, N, aufloesAzi, aziLi, aziRe, name);

      # Starten von skyplot und Unterdruecken der Ausgabe
      printf("Berechnung zu %.1f%% abgeschlossen\n", (i - minDist) * 100 / (maxDist - minDist));
      system("skyplot < SKYPLOT.CMD > /dev/null");

      # numerische Ausgabe von Skyplot einlesen und Anzahl Datenzeilen speichern
      maxRec = daten_einlesen(resfile);
      
      # rekonstruieren der azimutalen Aufloesung in gon. Der minimal moegliche Wert betraegt offenbar 0.01375 gon.
      # Damit die Darstellung trotzdem korrekt erstellt wird, wenn ein kleinerer Wert eingegeben wird,
      # muss die tatsaechliche azimutale Aufloesung nachtraeglich aus der numerischen Ausgabe rekonstruiert werden.
      aufloesAziCalc = oeffWink / (maxRec - 1);

      # am linken Bildrand beginnen
      abstX = 0;

      # X/Y in Bildkoordinaten fuer jeden Eintrag der Skyplot-Ausgabe berechnen
      # der horizontale Abstand der Punkte entspricht einem gon im Bildkoordinatensystem...
      # ...multipliziert mit der azimutalen Aufloesung in gon
      # der vertikale Abstand der Punkte entspricht der Gegenkathete, wenn der
      # Projektionszylinderradius als Ankathete und der Hoehenwinkel als Alpha betrachtet wird
      for (j = 1; j <= maxRec; j++ ) {
        distDHMrand = distGre(i, azi[j]);

        if (distDHMrand == -1)
          abbruch("\nungueltiges Azimut.");

        # Distanz zur Begrenzung des Hoehenmodell-Ausschnitts geringfuegig reduzieren
        distDHMrand = int(distDHMrand) - 200;

        # Ist die Entfernung des Grenzpunktes der Sichtbarkeit gleich oder groesser der Begrenzung des Hoehenmodell-
        # Ausschnitts, muss dieser Punkt ignoriert werden, da er keine Gelaendekante, sondern nur den Rand des
        # Hoehenmodell-Ausschnittes repraesentiert.	Die X-Koordinate muss dennoch einen Schritt erhoeht werden.
        if (distanz[j] >= distDHMrand) {
          abstX = abstX + (gonInMM * aufloesAziCalc);
          continue;
        }
        # andernfalls wird geprueft, ob an der betreffenden Stelle von einer vorherigen Berechnung bereits ein Punkt
        # vorhanden ist. Falls nicht, wird er in die Ausgabedatei geschrieben.
        # Die X-Koordinate wird in jedem Fall um einen Schritt erhoeht.
        else {
          abstY = radPr * tan(gon2rad(hoehenwinkel[j]));
          xy = abstX abstY; # X und Y Koordinate als String konkatenieren
          for (k in bisherigePte)
            if (xy == bisherigePte[k])
              existiert = 1;
          if (existiert == 0) {
		    dist0 = ankathete_aus_hypotenuse_und_winkel(distanz[j], hoehenwinkel[j])
			# Bestimmen der Lagekoordinaten jedes Punktes
		    if (split(bestimme_xy(x, y, dist0, azi[j]), xyPt, " ") == -1)
              abbruch("\nungueltiges Azimut.");
            printf("%7.3f, %7.3f, %9.1f, %9.1f, %8.1f, %5.1f, %5.1f, %6d, %5d\n", abstX, abstY, xyPt[1], xyPt[2], distanz[j], azi[j], hoehenwinkel[j], i, round((i - minDist) / distRel)) > panofile;
          }
          else
            existiert = 0;
          bisherigePte[j] = xy; # aktueller Punkt ins Array ergaenzen
          abstX = abstX + (gonInMM * aufloesAziCalc);
        }
      }

      # numerische Ausgabe wieder loeschen
      system("rm -f " resfile);
    }

    close(panofile);

    ##### Berechnungsprotokoll erstellen #####
    protokoll = "prot_" name "_" aziLi "-" aziRe ".txt";
    prot(protokoll);

    ##### aufraeumen und beenden #####
    system("rm -f SKYPLOT.CMD");
    system("rm -f SKYPLOT.LOG");
    system("rm -f SKYPLOT.PLT");
    system("rm -f SKYPLOT.RPT");
    system("rm -f sky.rdh");

    # um Awk zu zwingen, das Programm zu beenden, ohne Files zu lesen
    if (ARGV[12] == "")
      exit;
  }
}

###########################################
########## Funktionsdefinitionen ##########
###########################################

##### abbruch #####
# Fehlermeldung ausgeben und Programm beenden
function abbruch(info) {
  print info;
  print "Programm wird beendet.\n";
  exit;
}

##### bestimme_xy #####
# Berechnet aus dem Standort (X und Y Koordinaten) sowie der Distanz und Azimut die X/Y-Koordinaten des
# anvisierten Punktes. Dabei wird der Vollkreis in 8 Sektoren zu je 50 gon aufgeteilt.
# Die Distanz bildet die Hypotenuse (c), das Azimut wird in den Winkel Alpha oder Beta umgerechnet.
# Zurueckgeliefert werden X und Y Koordinaten als Leerzeichen-getrennter String.
# bei einem ungueltigen Azimut (< 0 oder > 400) wird -1 zurueckgegeben
function bestimme_xy(x, y, dist, aziGon,    a, b, alpha, beta, xE, yE) {
  if (aziGon == 0)
    return x " " y + dist;
  else if (aziGon > 0 && aziGon < 50) {
    a = gegenkathete_aus_hypotenuse_und_winkel(dist, aziGon);
    xE = x + a;
    yE = y + ankathete_aus_gegenkathete_und_winkel(a, aziGon);
    return xE " " yE;
  }
  else if (aziGon >= 50 && aziGon < 100) {
    beta = 100 - aziGon;
    b = gegenkathete_aus_hypotenuse_und_winkel(dist, beta);
    xE = x + ankathete_aus_gegenkathete_und_winkel(b, beta);
    yE = y + b;
    return xE " " yE;
  }
  else if (aziGon == 100)
    return x + dist " " y;
  else if (aziGon > 100 && aziGon < 150) {
    alpha = aziGon - 100;
    a = gegenkathete_aus_hypotenuse_und_winkel(dist, alpha);
    xE = x + ankathete_aus_gegenkathete_und_winkel(a, alpha);
    yE = y - a;
    return xE " " yE;
   }
  else if (aziGon >= 150 && aziGon < 200) {
    beta = 200 - aziGon;
    b = gegenkathete_aus_hypotenuse_und_winkel(dist, beta);
    xE = x + b;
    yE = y - ankathete_aus_gegenkathete_und_winkel(b, beta);
    return xE " " yE;
  }
  else if (aziGon == 200)
    return x " " y - dist;
  else if (aziGon > 200 && aziGon < 250) {
    alpha = aziGon - 200;
    a = gegenkathete_aus_hypotenuse_und_winkel(dist, alpha);
    xE = x - a;
    yE = y - ankathete_aus_gegenkathete_und_winkel(a, alpha);
    return xE " " yE;
  }
  else if (aziGon >= 250 && aziGon < 300) {
    beta = 300 - aziGon;
    b = gegenkathete_aus_hypotenuse_und_winkel(dist, beta);
    xE = x - ankathete_aus_gegenkathete_und_winkel(b, beta);
    yE = y - b;
    return xE " " yE;
  }
  else if (aziGon == 300)
    return x - dist " " y;
  else if (aziGon > 300 && aziGon < 350) {
    alpha = aziGon - 300;
    a = gegenkathete_aus_hypotenuse_und_winkel(dist, alpha);
    xE = x - ankathete_aus_gegenkathete_und_winkel(a, alpha);
    yE = y + a;
    return xE " " yE;
  }
  else if (aziGon >= 350 && aziGon < 400) {
    beta = 400 - aziGon;
    b = gegenkathete_aus_hypotenuse_und_winkel(dist, beta);
    xE = x - b;
    yE = y + ankathete_aus_gegenkathete_und_winkel(b, beta);
    return xE " " yE;
  }
  else
    return dist = -1;
}

##### daten_einlesen #####
# einlesen der numerischen Ausgabe von Skyplot
# nur Datenzeilen beruecksichtigen (solche, die mit Zahlen beginnen)
# aus den 3 Feldern die Arrays 'azi', 'hoehenwinkel' und 'distanz' bilden
# die Felder muessen mit substr extrahiert werden, weil sie direkt aneinander grenzen
# die Addition mit 0 erzwingt die Konvertierung in eine Zahl
# Anzahl Datenzeilen zurueckliefern
function daten_einlesen(resultfile,    i) {
  new(azi);
  new(hoehenwinkel);
  new(distanz);
  i = 0;
  while ((getline < resultfile) > 0)
    if ($1 ~ /^[1-9]/) {
      i++;
      azi[i] = substr($0, 1, 8);
      azi[i] = azi[i] + 0;
      hoehenwinkel[i] = substr($0, 9, 8);
      hoehenwinkel[i] = hoehenwinkel[i] + 0;
      distanz[i] = substr($0, 18, 8);
      distanz[i] = distanz[i] + 0;
    }
  close(resultfile);
  return i;
}

##### dhmBeschreibung #####
# Ausgeben des genauen Namens des angegebenen Hoehenmodells
function dhmBeschreibung(dhmTyp) {
  if (dhmTyp == "alti25")
    return "Digitales Hoehenmodell swissALTI3D (25 m  Gitter)";
  else if (dhmTyp == "dhm25")
    return "Digitales Hoehenmodell DHM25 (25 m  Gitter)";
  else if (dhmTyp == "komb")
    return "Kombiniertes Hoehenmodell DHM25, Ferranti, SRTM, DTED (25 m  Gitter)";
  else if (dhmTyp == "modt")
    return "Kombiniertes Hoehenmodell DHM25, MONA, DTED (50 m  Gitter)";
  else if (dhmTyp == "srtm")
    return "Digitales Hoehenmodell SRTM (30 m  Gitter)";
  else if (dhmTyp == "euD")
    return "Digitales Hoehenmodell euroDEM (60 m  Gitter)";
  else
    abbruch("\nungueltiges Hoehenmodell.");
}

##### dhmKopieren #####
# Hoehenmodell ins Arbeitsverzeichnis kopieren
function dhmKopieren(dhmTyp, dhmName) {
  if (dhmTyp == "alti25")
    system("cp $SCOP_ROOT/swissalti/swissalti25.dtm " dhmName);
  else if (dhmTyp == "dhm25")
    system("cp $SCOP_ROOT/chdtedrdh/ch25_l2_dted.dtm " dhmName);
  else if (dhmTyp == "komb")
    system("cp $SCOP_ROOT/srtm/DHM25_Ferranti_SRTM_DTED.dtm " dhmName);
  else if (dhmTyp == "modt")
    system("cp $SCOP_ROOT/ch_mona_dted/ch50modt.dtm " dhmName);
  else if (dhmTyp == "srtm")
    system("cp $SCOP_ROOT/srtm/srtm_1arcsecond.dtm " dhmName);
  else if (dhmTyp == "euD")
    system("cp $SCOP_ROOT/euroDEM/euroDEMclip.dtm " dhmName);
  else
    abbruch("\nungueltiges Hoehenmodell.");
}

##### distGre #####
# fuer jedes Azimut ist die Distanz zum Rand des Hoehenmodell-Ausschnitts mittels Dreiecksberechnung
# zu ermitteln. Dabei gilt:
# die Ankathete entspricht der Haelfte der Mittelsenkrechten, das Azimut dem Winkel Alpha, jeweils
# umgerechnet auf einen Wert zwischen 0 und 50 gon
# bei einem ungueltigen Azimut (< 0 oder > 400) wird -1 zurueckgegeben
function distGre(haelfteMittelsenkr, aziGon,    dist) {
  if (aziGon >=0 && aziGon < 50)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, aziGon);
  else if (aziGon >= 50 && aziGon < 100)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, 100 - aziGon);
  else if (aziGon >= 100 && aziGon < 150)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, aziGon - 100);
  else if (aziGon >= 150 && aziGon < 200)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, 200 - aziGon);
  else if (aziGon >= 200 && aziGon < 250)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, aziGon - 200);
  else if (aziGon >= 250 && aziGon < 300)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, 300 - aziGon);
  else if (aziGon >= 300 && aziGon < 350)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, aziGon - 300);
  else if (aziGon >= 350 && aziGon < 400)
    return dist = hypotenuse_aus_ankathete_und_winkel(haelfteMittelsenkr, 400 - aziGon);
  else
    return dist = -1;
}

##### ekrref #####
# Auswertung der Formel fuer Erdkruemmung und Refraktion
# distanz ist die Distanz in Metern
# (1 - k): setzt sich zusammen aus 1 minus mittlerer Refraktionskoeffizient (~0.13)
# erdRad ist der Erdradius, der mit 6370000  m festgelegt wird (gleicher Wert wie SCOP.SKYPLOT)
function ekrref(distanz,    k, erdRad) {
  k = 0.13;
  erdRad = 6370000 ;
  return (1 - k) * distanz^2 / (2 * erdRad);
}

##### hoehe_aus_distanz_und_winkel #####
# berechnet die Hoehe eines Punktes, der durch Distanz und Hoehenwinkel von einer bekannten Hoehe definiert ist
function hoehe_aus_distanz_und_winkel(z, distanz, hoehenwinkel,    hoehe) {
  hoehe = gegenkathete_aus_hypotenuse_und_winkel(distanz, hoehenwinkel);
  hoehe = hoehe + ekrref(distanz);
  return hoehe = hoehe + z;
}

##### maxDists #####
# Bilden eines Quadrats um das Projektionszentrum im Abstand von 'maxdist'
function maxDists(x, y, maxdist, richt) {
  if (richt == "N")
    return y + maxdist;
  else if (richt == "E")
    return x + maxdist;
  else if (richt == "S")
    return y - maxdist;
  else if (richt == "W")
    return x - maxdist;
  else
    abbruch("\nungueltige Angabe(n).");
}

##### modellhoehe #####
# einlesen der numerischen Ausgabe von Skyplot
# ermitteln der Modellhoehe und zurueckliefern
function modellhoehe(resultfile,    mh) {
  while ((getline < resultfile) > 0)
    if ($1 ~ /^Model/)
      mh = $3;
  close(resultfile);  
  return mh;
}

##### new #####
# erzeugt ein neues, leeres Array oder loescht den Inhalt eines bestehenden
function new(array) {
  split("", array);
}

##### prot #####
# erzeugt Berechnungsprotokoll
function prot(protfile) {
  printf("Berechnungsdatum: %s\n", strftime("%a. %d. %B %Y", systime()))                   > protfile;
  printf("Berechnet von   : %s\n\n\n", username())                                         > protfile;
  printf("%s\n", rep(90, "*"))                                                             > protfile;
  printf("Berechnungsprotokoll SKY-SIL %s\n", name)                                        > protfile;
  printf("%s\n", rep(90, "*"))                                                             > protfile;
  printf("\n\nEingabe\n")                                                                  > protfile;
  printf("%s\n\n", rep(7, "*"))                                                            > protfile;
  printf("Standort                            :  %d / %d / %d\n", x, y, z)                 > protfile;
  printf("Name                                :  %s\n", name)                              > protfile;
  printf("Azimut links                        :  %d gon\n", aziLi)                         > protfile;
  printf("Azimut rechts                       :  %d gon\n", aziRe)                         > protfile;
  printf("Azimutale Aufloesung                :  %.3f gon\n", aufloesAzi)                  > protfile;
  printf("Bildbreite                          :  %d mm\n", bildbr)                         > protfile;
  printf("Verwendetes Hoehenmodell            :  %s\n", dhmBeschreibung(dhm))              > protfile;
  printf("Berechnungen ab                        %d km\n", minDist / 1000)                 > protfile;
  printf("   bis                                 %d km\n", maxDist / 1000)                 > protfile;
  printf("   im Abstand von                      %d m durchgefuehrt\n", aufloesDist)       > protfile;
  printf("\n\n\nAbgeleitete Parameter\n")                                                  > protfile;
  printf("%s\n\n", rep(21, "*"))                                                           > protfile;
  printf("Eingegebene Hoehe                   :  %.1f m\n", z)                             > protfile;
  printf("Interpolierte Hoehe im %-13s:  %.1f m\n", toupper(dhm), mhoehe)                  > protfile;
  printf("Differenz                           :  %.1f m\n", z - mhoehe)                    > protfile;
  printf("Oeffnungswinkel                     :  %d gon\n", aziRe - aziLi)                 > protfile;
  printf("Radius                              :  %.3f mm\n", radPr)                        > protfile;
  printf("Azimutale Aufloesung in Skyplot     :  %.5f gon\n", aufloesAziCalc)              > protfile;
  printf("Anzahl Berechnungen                 :  %d\n", (maxDist - minDist) / aufloesDist) > protfile;
  printf("\n\n\nTopographische Extrempunkte\n")                                            > protfile;
  printf("%s\n\n", rep(27, "*"))                                                           > protfile;
  printf("Extrempunkt    %-8s%-8s%-6s%-7s%-10s%-8s%-6s\n",\
    "X", "Y", "Z", "D [km]", "Azi [gon]", "E-R [m]", "dH [m]")                             > protfile;
  printf("%s\n", rep(68, "-"))                                                             > protfile;

  printf("Noerdlichster: %-8d%-8d%4d%7.1f%9.3f%9.1f%6d\n",\
    exNord["x"], exNord["y"], exNord["z"], exNord["Distanz"] / 1000, exNord["Azi"], ekrref(exNord["Distanz"]), exNord["z"] - z) > protfile;
  printf("Oestlichster:  %-8d%-8d%4d%7.1f%9.3f%9.1f%6d\n",\
    exOst["x"], exOst["y"], exOst["z"], exOst["Distanz"] / 1000, exOst["Azi"], ekrref(exOst["Distanz"]), exOst["z"] - z)        > protfile;
  printf("Suedlichster:  %-8d%-8d%4d%7.1f%9.3f%9.1f%6d\n",\
    exSued["x"], exSued["y"], exSued["z"], exSued["Distanz"] / 1000, exSued["Azi"], ekrref(exSued["Distanz"]), exSued["z"] - z) > protfile;
  printf("Westlichster:  %-8d%-8d%4d%7.1f%9.3f%9.1f%6d\n",\
    exWest["x"], exWest["y"], exWest["z"], exWest["Distanz"] / 1000, exWest["Azi"], ekrref(exWest["Distanz"]), exWest["z"] - z) > protfile;
  printf("Entferntester: %-8d%-8d%4d%7.1f%9.3f%9.1f%6d\n",\
    xyEntf[1], xyEntf[2], exEntf["z"], exEntf["Distanz"] / 1000, exEntf["Azi"], ekrref(exEntf["Distanz"]), exEntf["z"] - z)     > protfile;
}

##### rep #####
# erzeugt n Zeichen vom Typ 's' und liefert sie zurueck
function rep(n, s,    t) {
  while (n-- > 0)
    t = t s;
  return t;
}

##### round #####
# rundet angegebene Fliesskommazahl auf die naechste Ganzzahl
function round(float) {
  return int(float + 0.5);
}

##### skyplot #####
# erzeugt das CMD-File fuer die Skyplot-Berechnung
function skyplot(output, resultfile, x, y, z, W, S, E, N, aufloesAzi, aziLi, aziRe, name) {
  printf("SKYPLOT,POSITION=(%s,%s),\n", x, y)                        > output;
  printf("        HEIGHT=%s,\n", z)                                  > output;
  printf("        RDHFILE=(sky.rdh),\n")                             > output;
  printf("        LIMITS=(%d %d %d %d),\n", W, S, E, N)              > output;
  printf("        RESOLUTION=GRADES=%s,\n", aufloesAzi)              > output;
  printf("        SECTOR=(%d,%d),\n", aziLi, aziRe)                  > output;
  printf("        TITEL=(%s),\n", name)                              > output;
  printf("        PLOTTER=113,\n")                                   > output;
  printf("        RESULTFILE=(%s);\n", resultfile)                   > output;
  printf("STOP;\n")                                                  > output;
  printf("$A;\n")                                                    > output;
  close(output);
}

##### theoausweit #####
# Naeherungsformel für die Berechnung der theoretischen Aussichtsweite eines Punktes in Metern
# (1 - k): setzt sich zusammen aus 1 minus mittlerer Refraktionskoeffizient (~0.13)
# erdRad ist der Erdradius, der mit 6370000  m festgelegt wird (gleicher Wert wie SCOP.SKYPLOT)
function theoausweit(z,    k, erdRad) {
  erdRad = 6370000 ;
  k = 0.13;
  return (sqrt((2 * erdRad) / (1 - k)) * sqrt(z));
}

##### usage #####
# gibt aus, wie das Programm parametrisiert werden muss
function usage() {
  printf("\n%s\n", rep(140, "*"));
  printf("  Usage: skyplot2pano.awk  <X> <Y> <Z> <Name> <DHM> <Aufloes-Azi> <Azi links> <Azi rechts> <Bildbreite> <Min-Dist> <Max-Dist> <Aufloes-Dist>\n");
  printf("%s\n\n", rep(140, "*"));
  printf("Das Programm erzeugt ein Panorama mit aus Punkten gebildeten Silhouetten von einem beliebigen Punkt\n");
  printf("\n");
  printf("Erlaeuterung der Argumente\n");
  printf("%s\n", rep(26, "-"));
  printf("<X> <Y> <Z> definieren das Projektionszentrum (PZ) in Landeskoordinaten LV03 und Hoehe in m ue M.\n");
  printf("<Name> ist der Name des PZ. Er darf keine Leerzeichen enthalten.\n");
  printf("<DHM> ist das zu verwendende digitale Hoehenmodell. Folgende stehen zur Verfuegung:\n");
  printf("   alti25  (hochpraezises digitales Hoehenmodell der Schweiz und Liechtensteins (reduziert auf 25 m Aufloesung)\n");
  printf("   dhm25   (kartenbasiertes digitales Hoehenmodell der Schweiz und umliegender Gebiete mit 25 m Aufloesung)\n");
  printf("   srtm    (SRTM-Mosaik der Alpen mit ca. 30 m Aufloseung)\n");
  printf("   euD     (euroDEM, das europaeische Hoehenmodell mit ca. 60 m  Aufloesung)\n");
  printf("<Aufloesung-Azi> ist die azimutale Aufloesung in gon.\n");
  printf("<Azi links> <Azi rechts> sind das ganzzahlige linke und rechte Azimut in gon.\n");
  printf("<Bildbreite> ist die ganzzahlige gewuenschte Bildbreite in mm.\n");
  printf("<Min-Dist> definiert, ab welcher Distanz in km (Ganzzahl) vom Projektionszentrum die Berechnung vorgenommen wird.\n");
  printf("<Max-Dist> definiert, bis zu welcher Distanz in km (Ganzzahl) vom Projektionszentrum die Berechnung vorgenommen wird.\n");
  printf("<Aufloes-Dist> definiert, in welchen Intervallen (km-Abstand zu <Min-Dist>) Berechnungen durchgefuehrt werden, bis <Max-Dist> erreicht ist.\n");
  printf("\n");
  printf("Beispiel\n");
  printf("%s\n", rep(8, "-"));
  printf("  skyplot2pano.awk 610558 197236 635 Gantrischweg dhm25 0.1 200 250 400 0 40 1\n");
}

##### username #####
# ermittelt mit UNIX-Kommando den Usernamen und gibt ihn zurueck
function username(    cmd) {
  cmd = "whoami";
  cmd | getline user;
  close(cmd);
  return user;
}

##### Funktionen fuer die geometrischen Berechnungen #####
function pi() {
  return atan2(0, -1);
}

function gon2rad(gon) {
  return pi() / (400 / 2) * gon;
}

function ankathete_aus_hypotenuse_und_winkel(c, winkelGon) {
  return c * sin(gon2rad(100 - winkelGon));
}

function gegenkathete_aus_hypotenuse_und_winkel(c, winkelGon) {
  return c * sin(gon2rad(winkelGon));
}

function ankathete_aus_gegenkathete_und_winkel(a, winkelGon) {
  return a / tan(gon2rad(winkelGon));
}

function hypotenuse_aus_ankathete_und_winkel(b, winkelGon) {
  return b / cos(gon2rad(winkelGon));
}

function tan(winkel) {
  return sin(winkel) / cos(winkel);
}
