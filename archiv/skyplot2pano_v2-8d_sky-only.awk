#!/usr/bin/awk -f
#########################################################################################################################################################
#
# Filename:     skyplot2pano_sky-only.awk
# Author:       Adrian Boehlen
# Date:         08.06.2025
# Version:      2.8t
#
# Purpose:      Performancetests und -vergleiche. Awk-spezifische Berechnungen sind entfernt, es laufen nur skyplot Berechnungen.
#
# Usage:        skyplot2pano_sky-only.awk  <X> <Y> <Z> <Name> <DHM> <Aufl-Azi> <Azi li> <Azi re> <Bildbr> <Min-Dist> <Max-Dist> <Aufloes-Dist> <Nam> <Tol>
#
#########################################################################################################################################################


##########################
########## main ##########
##########################

BEGIN {

  # Zeitstempel Beginn
  start = systime();
  
  # Versionsnummer
  version = "2.8t";

  # Field Separator auf "," stellen, zwecks Einlesen der Konfigurationsdateien und der temporaer erzeugten Namensfiles
  FS = ",";

  # Liste der verfuegbaren Hoehenmodelle einlesen
  copy("$SCOP_ROOT/scop/util/dhm.txt", ".", "Konfigurationsdatei dhm.txt existiert nicht");
  anzDhm = dhmListeEinlesen("dhm.txt");

  # Liste der verfuegbaren Namensfiles einlesen
  copy("$SCOP_ROOT/scop/util/nam.txt", ".", "Konfigurationsdatei nam.txt existiert nicht");
  anzNamFiles = namListeEinlesen("nam.txt");

  # Usage ausgeben, wenn zuwenig Argumente
  if (ARGC < 15) { 
    usage(version);
    system("rm -f dhm.txt");
    system("rm -f nam.txt");
    exit;
  }
  else {

    # Programmtitel ausgeben
    printTitel(version, strftime("%d.%m.%Y", systime()));

    # Variablen initialisieren
    initVar();

    # Argumente einlesen
    argEinl();

    # Argumente pruefen
    argPr();

    # Daten vorbereiten
    datVorb();

    # Berechnen der Extrempunkte
    extrBer();

    # Berechnen des Panoramas
    panoBer();

    # Berechnung abschliessen
    abschlBer();
  }
}

###########################################
########## Funktionsdefinitionen ##########
###########################################

########## Hauptfunktionen ##########

##### initVar #####
# diverse Variablen initialisieren 
function initVar() {

  # diverse Variablen initialisieren
  formatExtrTxt = "%7s, %7s, %4s, %-15s\n";
  formatExtrDat = "%7d, %7d, %4d, %-15s\n";
  formatSilTxt =  "%7s, %7s, %7s, %7s, %6s, %16s, %8s, %5s, %5s, %6s, %5s\n";
  formatSilDat =  "%7.3f, %7.3f, %7d, %7d, %6d, %16s, %8.1f, %5.1f, %5.1f, %6d, %5d\n";
  formatProtTxt = "%-8s%-8s%-6s%-7s%-10s%-8s%-6s\n";
  formatProtDat = "%-8d%-8d%4d%7.1f%9.3f%9.1f%6d\n";
  formatNamTmp =  "%s, %d, %d, %d, %d, %d\n";
  anzBer = 0; # Anzahl Berechnungen pro Panoramabild
  anzPte = 0; # Anzahl Azimute pro Berechnung
}

##### argEinl #####
# liest Argumente ein
function argEinl() {

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

  # Namendatenfile kopieren falls gewuenscht
  namFile = ARGV[13];
  if (namFile != "0") {
    namFile = namFile ".txt";
    namKopieren(namFile);
    toleranz = ARGV[14];
    toleranz = round(toleranz);
  }

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
  ARGV[13] = "";
  ARGV[14] = "";
}

##### argPr #####
# prueft Argumente 
function argPr() {

  # Usage ausgeben, wenn zuviele Argumente
  if (ARGV[15] != "") {
    usage();
    system("rm -f dhm.txt");
    system("rm -f nam.txt");
    exit;
  }

  # Plausibilitaet der Argumente pruefen. Andernfalls Fehlermeldung ausgeben und beenden
  if (aziLi < -400 || aziLi > 400)
    abort("\nlinkes Azimut muss zwischen -400 und +400 gon betragen.");

  if (aziRe < -400 || aziRe > 400)
    abort("\nrechtes Azimut muss zwischen -400 und +400 gon betragen.");

  if (aziLi >= aziRe)
    abort("\nlinkes Azimut muss kleiner sein als rechtes Azimut.");

  if (minDist < 0)
    abort("\ndie minimale Distanz kann nicht kleiner als 0 sein.");

  if (minDist >= maxDist)
    abort("\ndie minimale Distanz muss kleiner als die maximale Distanz sein.");
}

##### datVorb #####
# diverse Daten vorbereiten 
function datVorb() {

  # Hoehenmodell als sky.rdh kopieren
  dhmKopieren(dhm, "sky.rdh");

  # Oeffnungswinkel bestimmen
  # 1 gon im Bildkoordinatensystem ermitteln
  oeffWink = aziRe - aziLi;
  gonInMM = bildbr / oeffWink;

  # ausgehend von einer Zylinderprojektion wird der Umfang
  # und der Radius des Projektionszylinders abgeleitet
  umfang = 400 / oeffWink * bildbr;
  radPr = umfang / (2 * pi());

  # Extrempunktedatei vorbereiten
  extrFile = "extr_" name "_" aziLi "-" aziRe ".txt"
  printf(formatExtrTxt, "X", "Y", "Z", "Extrempunkt") > extrFile;

  # Panoramadatei vorbereiten
  panofile = "sil_" name "_" aziLi "-" aziRe ".txt"
  printf(formatSilTxt, "X", "Y", "LageX", "LageY", "LageZ", "LageX LageY", "Dist", "Azi", "HWink", "Limit", "DiRel") > panofile;

  # Namen-Ausgabedateien vorbereiten
  if (namFile != "0") {
    namTmpFile = "namTmp.txt"
    namDXFFile = "nam_" name "_" aziLi "-" aziRe ".dxf"
    print "\n...Berechnung mit Namen...\n";
  }
  else
    print "\n...Berechnung ohne Namen...\n";

  # aus 'minDist' und 'maxDist' einen Hilfswert ableiten, um spaeter die einzelnen Punkte den
  # relative Werten 0 bis 10 zuzuweisen (0 = naheliegendst, 10 = entferntest)
  distRelDiv = (maxDist - minDist) / 10;
}

##### extrBer #####
# berechnet die topographischen Extrempunkte, d.h. den noerdlichsten, oestlichsten
# suedlichsten, westlichsten, hoechsten und entferntesten Punkt
function extrBer() {
  # Arrays zur Speicherung der Extrempunkte initialisieren
  exEntf["Distanz"] = 0;
  exHoe["z"] = 0;
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

  # Erstellen des SCOP-Input-Files SKYPLOT.CMD fuer die Berechnung der Extrempunkte
  resfile = "extr.txt";
  skyplot("SKYPLOT.CMD", resfile, x, y, z, W, S, E, N, aufloesAzi, aziLi, aziRe, "Extrempunkte");
  
  # Starten von skyplot und Unterdruecken der Ausgabe
  print "Berechnung der Extrempunkte...";
  system("skyplot < SKYPLOT.CMD > /dev/null");

  # aufraeumen
  system("rm -f " resfile);
  system("rm -f SKYPLOT.CMD");
}

##### panoBer #####
# berechnet das Panoramabild
function panoBer() {

  # Namendaten einlesen, wenn spezifiziert
  if (namFile != "0")
    anzNam = namEinlesen(namFile);

  # um fehlerhafte Resultate zu vermeiden, muss der unmittelbare Nahbereich unterdrueckt werden
  if (minDist < 500)
    minDist = 500;

  # Berechnungen im Abstand von 'aufloesDist' durchfuehren, bis 'maxDist' erreicht ist
  for (i = minDist; i <= maxDist; i += aufloesDist) {

    anzBer++; # Zaehler fuer die Anzahl Berechnungen

    # SCOP LIMITS festlegen
    N = maxDists(x, y, i, "N");
    E = maxDists(x, y, i, "E");
    S = maxDists(x, y, i, "S");
    W = maxDists(x, y, i, "W");

    # Erstellen des SCOP-Input-Files SKYPLOT.CMD
    resfile = "sky_" name i ".txt";
    skyplot("SKYPLOT.CMD", resfile, x, y, z, W, S, E, N, aufloesAzi, aziLi, aziRe, name);

    # Starten von skyplot und Unterdruecken der Ausgabe
    printf("Berechnung zu %.1f%% abgeschlossen\t%s Sek.\n", (i - minDist) * 100 / (maxDist - minDist), (systime() - start));
    system("skyplot < SKYPLOT.CMD > /dev/null");

    # numerische Ausgabe wieder loeschen
    system("rm -f " resfile);
  }
}

##### abschlBer #####
# schliesst die Berechnung ab und loescht temporaere Dateien
function abschlBer(    berD, protokoll) {

  # Dauer der Berechnung ermitteln und ausgeben
  berD = convertsecs(systime() - start);
  
  printf("\n%s\n", rep(45, "*"))
  printf("Dauer der Berechnung: %s\n", berD);
  printf("%s\n", rep(45, "*"))

  # aufraeumen und beenden
  system("rm -f dhm.txt");
  system("rm -f nam.txt");
  system("rm -f sky.rdh");
  system("rm -f SKYPLOT.CMD");
  system("rm -f SKYPLOT.LOG");
  system("rm -f SKYPLOT.PLT");
  system("rm -f SKYPLOT.RPT");

  if (namFile != "0") {
    system("rm -f " namFile);
    system("rm -f " namTmpFile);
  }

  # um Awk zu zwingen, das Programm zu beenden, ohne Files zu lesen
  if (ARGV[14] == "")
    exit;
}


########## allgemeine Funktionen ##########

##### abort #####
# Fehlermeldung ausgeben und Programm beenden
function abort(info) {
  print info;
  print "Programm wird beendet.\n";
  exit;
}

##### convertsecs #####
# rechnet Sekunden in formatierte Ausgabe Std. Min. und Sek. um
function convertsecs(sec,    h, m, s) {
  h = sec / 3600;
  m = (sec % 3600) / 60;
  s = sec % 60;
  return sprintf("%02d Std. %02d Min. %02d Sek.", h, m, s);
}

##### copy #####
# kopiert Datei von 'source' nach 'target' mittels UNIX-Kommando cp
# beendet das Programm, wenn der Kopiervorgang scheitert
function copy(source, target, errorMsg,    exitStatus) {
  exitStatus = system("cp " source " " target);
  if (exitStatus != 0)
    abort("\n" errorMsg);
}

##### new #####
# erzeugt ein neues, leeres Array oder loescht den Inhalt eines bestehenden
function new(array) {
  split("", array);
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

##### username #####
# ermittelt mit UNIX-Kommando den Usernamen und gibt ihn zurueck
function username(    cmd) {
  cmd = "whoami";
  cmd | getline user;
  close(cmd);
  return user;
}



########## spezifische Funktionen ##########



##### dhmBeschreibung #####
# Ausgeben des genauen Namens des angegebenen Hoehenmodells
function dhmBeschreibung(dhmTyp,    i) {
  for (i = 1; i <= anzDhm; i++)
    if (dhmTyp == dhmKuerz[i])
      return dhmBeschr[i];
}

##### dhmListeEinlesen #####
# einlesen der Liste mit den verfuegbaren Hoehenmodellen
# nur Datenzeilen beruecksichtigen (Zeile 2 ff)
# aus den 3 Feldern die Arrays 'dhmKuerz', 'dhmPfad' und 'dhmBeschr' bilden
# Anzahl Datenzeilen zurueckliefern
function dhmListeEinlesen(dhmListe,    i) {
  new(dhmKuerz);
  new(dhmPfad);
  new(dhmBeschr);
  i = 0;
  while ((getline < dhmListe) > 0) {
    if (i == 0) {
      i++;
      continue;
    }
    else {
      gsub(/[ ]+$/,"",$1) # Leerzeichen am Ende entfernen
      dhmKuerz[i] = $1;
      dhmPfad[i] = $2;
      dhmBeschr[i] = $3;
      i++;
    }
  }
  close(dhmListe);
  return i - 1;
}

##### dhmKopieren #####
# Hoehenmodell ins Arbeitsverzeichnis kopieren
# ln waere schneller, funktioniert aber bei Verwendung einer RAM-Disk nicht
function dhmKopieren(dhmTyp, dhmName,    i) {
  for (i = 1; i <= anzDhm; i++)
    if (dhmTyp == dhmKuerz[i])
      copy(dhmPfad[i], dhmName, "angegebenes Hoehenmodell existiert nicht");
}



##### maxDists #####
# Bilden eines Quadrats um das Projektionszentrum im Abstand von 'maxDist'
function maxDists(x, y, maxDist, ri) {
  if (ri == "N")
    return y + maxDist;
  else if (ri == "E")
    return x + maxDist;
  else if (ri == "S")
    return y - maxDist;
  else if (ri == "W")
    return x - maxDist;
  else
    abort("\nungueltige Angabe(n).");
}

##### modellhoehe #####
# einlesen der numerischen Ausgabe von Skyplot
# ermitteln der Modellhoehe und zurueckliefern
function modellhoehe(res,    mh) {
  while ((getline < res) > 0)
    if ($0 ~ /^Model/) {
      mh = substr($0, 50, 7);
      mh = mh + 0;
    }
  close(res);  
  return mh;
}

##### namEinlesen #####
# einlesen des angegebenen Namensfiles
# aus den Namen und Koordinaten die Arrays 'namName', 'namX', 'namY' und 'namZ' bilden
# den Code ins Array 'namCode' einlesen
# die Felder muessen mit substr extrahiert werden, weil sie in einem fixen Kolonnenformat vorliegen
# Werte werden auf Ganzzahlen gerundet
# Anzahl Datenzeilen zurueckliefern
function namEinlesen(namFile,    i) {
  new(namName);
  new(namX);
  new(namY);
  new(namZ);
  new(namCode);
  i = 0;
  while ((getline < namFile) > 0) {
    i++;
    namName[i] = substr($0, 1, 32);
    namX[i] =    substr($0, 35, 10);
    namX[i] =    round(namX[i]);
    namY[i] =    substr($0, 47, 10);
    namY[i] =    round(namY[i]);
    namZ[i] =    substr($0, 61, 8);
    namZ[i] =    round(namZ[i]);
    namCode[i] = substr($0, 71, 2);
  }
  close(namFile);
  return i;
}


##### namListeEinlesen #####
# einlesen der Liste mit den verfuegbaren Namensfiles
# nur Datenzeilen beruecksichtigen (Zeile 2 ff)
# aus den 3 Feldern die Arrays 'namKuerz', 'namPfad' und 'namBeschr' bilden
# Anzahl Datenzeilen zurueckliefern
function namListeEinlesen(namListe,    i) {
  new(namKuerz);
  new(namPfad);
  new(namBeschr);
  i = 0;
  while ((getline < namListe) > 0) {
    if (i == 0) {
      i++;
      continue;
    }
    else {
      gsub(/[ ]+$/,"",$1) # Leerzeichen am Ende entfernen
      namKuerz[i] = $1;
      namPfad[i] = $2;
      namBeschr[i] = $3;
      i++;
    }
  }
  close(namListe);
  return i - 1;
}

##### namKopieren #####
# Namensfile ins Arbeitsverzeichnis kopieren
function namKopieren(namTyp,    i) {
  for (i = 1; i <= anzNamFiles; i++)
    if (namTyp == namKuerz[i] ".txt")
      copy(namPfad[i], ".", "angegebenes Namensfile existiert nicht");
}

##### printTitel #####
# gibt vor jeder Berechnung einen Titel in der Konsole aus
function printTitel(vers, dat,    tit) {
  tit = "\n\
        ***************************************************\n\
        *                                                 *\n\
        *            skyplot2pano, Version " vers "            *\n\
        *    https://github.com/ABoehlen/skyplot2pano     *\n\
        *                                                 *\n\
        *                   " dat "                    *\n\
        *                                                 *\n\
        ***************************************************\n";

  print tit;
}

function pi() {
  return atan2(0, -1);
}

##### skyplot #####
# erzeugt das CMD-File fuer die Skyplot-Berechnung
function skyplot(output, res, x, y, z, W, S, E, N, auflAzi, aziLi, aziRe, name) {
  printf("SKYPLOT,POSITION=(%s,%s),\n", x, y)                        > output;
  printf("        HEIGHT=%s,\n", z)                                  > output;
  printf("        RDHFILE=(sky.rdh),\n")                             > output;
  printf("        LIMITS=(%d %d %d %d),\n", W, S, E, N)              > output;
  printf("        RESOLUTION=GRADES=%s,\n", auflAzi)                 > output;
  printf("        SECTOR=(%d,%d),\n", aziLi, aziRe)                  > output;
  printf("        TITEL=(%s),\n", name)                              > output;
  printf("        PLOTTER=113,\n")                                   > output;
  printf("        RESULTFILE=(%s);\n", res)                          > output;
  printf("STOP;\n")                                                  > output;
  printf("$A;\n")                                                    > output;
  close(output);
}

##### skyplotEinlesen #####
# einlesen der numerischen Ausgabe von Skyplot
# nur Datenzeilen beruecksichtigen (solche, die mit Zahlen beginnen)
# aus den 3 Feldern die Arrays 'azi', 'hoehenwinkel' und 'distanz' bilden
# die Felder muessen mit substr extrahiert werden, weil sie direkt aneinander grenzen
# die Addition mit 0 erzwingt die Konvertierung in eine Zahl
# Anzahl Datenzeilen zurueckliefern
function skyplotEinlesen(res,    i) {
  new(azi);
  new(hoehenwinkel);
  new(distanz);
  i = 0;
  while ((getline < res) > 0)
    if ($1 ~ /^[1-9 ]/) {
      i++;
      azi[i] = substr($0, 1, 8);
      azi[i] = azi[i] + 0;
      hoehenwinkel[i] = substr($0, 9, 8);
      hoehenwinkel[i] = hoehenwinkel[i] + 0;
      distanz[i] = substr($0, 18, 8);
      distanz[i] = distanz[i] + 0;
    }
  close(res);
  return i;
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
function usage(vers) {
  printf("\nskyplot2pano v%s, https://github.com/ABoehlen/skyplot2pano\n", vers)
  printf("\n%s\n", rep(141, "*"));
  printf("  Usage: skyplot2pano.awk  <X> <Y> <Z> <Name> <DHM> <Aufl-Azi> <Azi li> <Azi re> <Bildbr> <Min-Dist> <Max-Dist> <Aufloes-Dist> <Nam> <Tol>\n");
  printf("%s\n\n", rep(141, "*"));
  printf("Das Programm erzeugt ein Panorama mit aus Punkten gebildeten Silhouetten von einem beliebigen Punkt\n");
  printf("\n");
  printf("Erlaeuterung der Argumente\n");
  printf("%s\n", rep(26, "-"));
  printf("<X> <Y> <Z> definieren das Projektionszentrum (PZ) in rechtwinkligen Koordinaten und Hoehe in m ue M.\n");
  printf("<Name> ist der Name des PZ. Er darf keine Leerzeichen enthalten.\n");
  printf("<DHM> ist das zu verwendende digitale Hoehenmodell. Folgende stehen zur Verfuegung:\n");
  for (i = 1; i <= anzDhm; i++)
    printf("   %-15s%s\n", dhmKuerz[i], dhmBeschr[i]);
  printf("<Auf-Azi> ist die azimutale Aufloesung in gon.\n");
  printf("<Azi li> und <Azi re> sind das ganzzahlige linke und rechte Azimut in gon.\n");
  printf("<Bildbr> ist die ganzzahlige gewuenschte Bildbreite in mm.\n");
  printf("<Min-Dist> definiert, ab welcher Distanz in km (Ganzzahl) vom Projektionszentrum die Berechnung vorgenommen wird.\n");
  printf("<Max-Dist> definiert, bis zu welcher Distanz in km (Ganzzahl) vom Projektionszentrum die Berechnung vorgenommen wird.\n");
  printf("<Aufloes-Dist> definiert, in welchen Intervallen (km-Abstand zu <Min-Dist>) Berechnungen durchgefuehrt werden, bis <Max-Dist> erreicht ist.\n");
  printf("<Nam> definiert, ob und aufgrund welcher Namendatei die Beschriftung vorgenommen werden soll. Folgende stehen zur Verfuegung:\n");
  printf("   %-15s%s\n", "0", "keine Beschriftung");
  for (i = 1; i <= anzNamFiles; i++)
    printf("   %-15s%s\n", namKuerz[i], namBeschr[i]);
  printf("<Tol> ist die Toleranz in m, innerhalb der bei berechneten Punkten nach Namen im Namensfile gesucht werden soll.\n");
  printf("\n");
  printf("Beispiel\n");
  printf("%s\n", rep(8, "-"));
  printf("  skyplot2pano.awk 610558 197236 635 Gantrischweg dhm25 0.1 200 250 400 0 40 1 sn200 50\n");
}


