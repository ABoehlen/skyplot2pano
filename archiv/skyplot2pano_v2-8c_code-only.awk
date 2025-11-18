#!/usr/bin/awk -f
# kompletter Code der Version 2.8 ohne Kommentar- und Leerzeilen
BEGIN {
  start = systime();
  version = "2.8";
  FS = ",";
  copy("$SCOP_ROOT/scop/util/dhm.txt", ".", "Konfigurationsdatei dhm.txt existiert nicht");
  anzDhm = dhmListeEinlesen("dhm.txt");
  copy("$SCOP_ROOT/scop/util/nam.txt", ".", "Konfigurationsdatei nam.txt existiert nicht");
  anzNamFiles = namListeEinlesen("nam.txt");
  if (ARGC < 15) { 
    usage(version);
    system("rm -f dhm.txt");
    system("rm -f nam.txt");
    exit;
  }
  else {
    printTitel(version, strftime("%d.%m.%Y", systime()));
    initVar();
    argEinl();
    argPr();
    datVorb();
    extrBer();
    panoBer();
    if (namFile != "0")
      dxfBer();
    abschlBer();
  }
}
function initVar() {
  formatExtrTxt = "%7s, %7s, %4s, %-15s\n";
  formatExtrDat = "%7d, %7d, %4d, %-15s\n";
  formatSilTxt =  "%7s, %7s, %7s, %7s, %6s, %16s, %8s, %5s, %5s, %6s, %5s\n";
  formatSilDat =  "%7.3f, %7.3f, %7d, %7d, %6d, %16s, %8.1f, %5.1f, %5.1f, %6d, %5d\n";
  formatProtTxt = "%-8s%-8s%-6s%-7s%-10s%-8s%-6s\n";
  formatProtDat = "%-8d%-8d%4d%7.1f%9.3f%9.1f%6d\n";
  formatNamTmp =  "%s, %d, %d, %d, %d, %d\n";
  anzBer = 0; 
  anzPte = 0; 
}
function argEinl() {
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
  namFile = ARGV[13];
  if (namFile != "0") {
    namFile = namFile ".txt";
    namKopieren(namFile);
    toleranz = ARGV[14];
    toleranz = round(toleranz);
  }
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
function argPr() {
  if (ARGV[15] != "") {
    usage();
    system("rm -f dhm.txt");
    system("rm -f nam.txt");
    exit;
  }
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
function datVorb() {
  dhmKopieren(dhm, "sky.rdh");
  oeffWink = aziRe - aziLi;
  gonInMM = bildbr / oeffWink;
  umfang = 400 / oeffWink * bildbr;
  radPr = umfang / (2 * pi());
  extrFile = "extr_" name "_" aziLi "-" aziRe ".txt"
  printf(formatExtrTxt, "X", "Y", "Z", "Extrempunkt") > extrFile;
  panofile = "sil_" name "_" aziLi "-" aziRe ".txt"
  printf(formatSilTxt, "X", "Y", "LageX", "LageY", "LageZ", "LageX LageY", "Dist", "Azi", "HWink", "Limit", "DiRel") > panofile;
  if (namFile != "0") {
    namTmpFile = "namTmp.txt"
    namDXFFile = "nam_" name "_" aziLi "-" aziRe ".dxf"
    print "\n...Berechnung mit Namen...\n";
  }
  else
    print "\n...Berechnung ohne Namen...\n";
  distRelDiv = (maxDist - minDist) / 10;
}
function extrBer() {
  exEntf["Distanz"] = 0;
  exHoe["z"] = 0;
  exNord["x"] = exOst["x"] = exSued["x"] = exWest["x"] = x;
  exNord["y"] = exOst["y"] = exSued["y"] = exWest["y"] = y;
  maxSicht = theoausweit(z);
  if (maxSicht < 100000)
    maxSicht = 100000;
  N = maxDists(x, y, (maxSicht * 2), "N");
  E = maxDists(x, y, (maxSicht * 2), "E");
  S = maxDists(x, y, (maxSicht * 2), "S");
  W = maxDists(x, y, (maxSicht * 2), "W");
  resfile = "extr.txt";
  skyplot("SKYPLOT.CMD", resfile, x, y, z, W, S, E, N, aufloesAzi, aziLi, aziRe, "Extrempunkte");
  print "Berechnung der Extrempunkte...";
  system("skyplot < SKYPLOT.CMD > /dev/null");
  mhoehe = modellhoehe(resfile);
  maxRec = skyplotEinlesen(resfile);
  aufloesAziCalc = oeffWink / (maxRec - 1);
  for (i = 1; i <= maxRec; i++ ) {
    if (distanz[i] > exEntf["Distanz"]) {
      exEntf["Azi"] = azi[i];
      exEntf["Distanz"] = distanz[i];
      exEntf["Hoehenwinkel"] = hoehenwinkel[i];
    }
    hoehe = hoeheAusDistanzUndWinkel(z, distanz[i], hoehenwinkel[i]);
    if (hoehe > exHoe["z"]) {
      exHoe["z"] = hoehe;
      exHoe["Azi"] = azi[i];
      exHoe["Distanz"] = distanz[i];
      exHoe["Hoehenwinkel"] = hoehenwinkel[i];
    }
    dist0 = ankathAusHypothUndAlpha(distanz[i], hoehenwinkel[i]);
    if (bestimmeXY(x, y, dist0, azi[i]) == -1)
      abort("\nungueltiges Azimut.");
    else
      extrempunkteNESW(substr(bestimmeXY(x, y, dist0, azi[i]), 0, 10), substr(bestimmeXY(x, y, dist0, azi[i]), 11, 10), azi[i], distanz[i], hoehenwinkel[i]);
  }
  exNord["z"] = hoeheAusDistanzUndWinkel(z, exNord["Distanz"], exNord["Hoehenwinkel"]);
  exOst["z"] =  hoeheAusDistanzUndWinkel(z, exOst["Distanz"],  exOst["Hoehenwinkel"]);
  exSued["z"] = hoeheAusDistanzUndWinkel(z, exSued["Distanz"], exSued["Hoehenwinkel"]);
  exWest["z"] = hoeheAusDistanzUndWinkel(z, exWest["Distanz"], exWest["Hoehenwinkel"]);
  dist0 = ankathAusHypothUndAlpha(exEntf["Distanz"], exEntf["Hoehenwinkel"]);
  if (bestimmeXY(x, y, dist0, exEntf["Azi"]) == -1)
    abort("\nungueltiges Azimut.");
  exEntf["x"] = substr(bestimmeXY(x, y, dist0, exEntf["Azi"]), 0, 10);
  exEntf["y"] = substr(bestimmeXY(x, y, dist0, exEntf["Azi"]), 11, 10);
  exEntf["z"] = hoeheAusDistanzUndWinkel(z, exEntf["Distanz"], exEntf["Hoehenwinkel"]);
  dist0 = ankathAusHypothUndAlpha(exHoe["Distanz"], exHoe["Hoehenwinkel"]);
  if (bestimmeXY(x, y, dist0, exHoe["Azi"]) == -1)
    abort("\nungueltiges Azimut.");
  exHoe["x"] = substr(bestimmeXY(x, y, dist0, exHoe["Azi"]), 0, 10);
  exHoe["y"] = substr(bestimmeXY(x, y, dist0, exHoe["Azi"]), 11, 10);
  printf(formatExtrDat, exNord["x"], exNord["y"], exNord["z"], "Noerdlichster") > extrFile;
  printf(formatExtrDat, exOst["x"], exOst["y"], exOst["z"], "Oestlichster")     > extrFile;
  printf(formatExtrDat, exSued["x"], exSued["y"], exSued["z"], "Suedlichster")  > extrFile;
  printf(formatExtrDat, exWest["x"], exWest["y"], exWest["z"], "Westlichster")  > extrFile;
  printf(formatExtrDat, exHoe["x"] , exHoe["y"] , exHoe["z"], "Hoechster")      > extrFile;
  printf(formatExtrDat, exEntf["x"], exEntf["y"], exEntf["z"], "Entferntester") > extrFile;
  close(extrFile);
  system("rm -f " resfile);
  system("rm -f SKYPLOT.CMD");
}
function panoBer() {
  new(bisherigePte);
  new(bisherigeNamen);
  existiertPkt = 0;
  existiertNam = 0;
  if (namFile != "0")
    anzNam = namEinlesen(namFile);
  if (minDist < 500)
    minDist = 500;
  for (i = minDist; i <= maxDist; i += aufloesDist) {
    anzBer++; 
    N = maxDists(x, y, i, "N");
    E = maxDists(x, y, i, "E");
    S = maxDists(x, y, i, "S");
    W = maxDists(x, y, i, "W");
    resfile = "sky_" name i ".txt";
    skyplot("SKYPLOT.CMD", resfile, x, y, z, W, S, E, N, aufloesAzi, aziLi, aziRe, name);
    printf("Berechnung zu %.1f%% abgeschlossen\n", (i - minDist) * 100 / (maxDist - minDist));
    system("skyplot < SKYPLOT.CMD > /dev/null");
    maxRec = skyplotEinlesen(resfile);
    abstX = 0;
    if (anzBer == 1) {
      minX = abstX; 
      maxX = abstX; 
    }
    for (j = 1; j <= maxRec; j++ ) {
      distDHMrand = distGre(i, azi[j]);
      if (distDHMrand == -1)
        abort("\nungueltiges Azimut.");
      distDHMrand = int(distDHMrand) - 200;
      if (distanz[j] >= distDHMrand) {
        abstX = abstX + (gonInMM * aufloesAziCalc);
        continue;
      }
      else {
        anzPte++; 
        abstY = radPr * tan(gon2rad(hoehenwinkel[j]));
        if (anzBer == 1 && anzPte == 1) {
          minY = abstY; 
          maxY = abstY; 
        } 
        xy = abstX abstY; 
        for (k in bisherigePte)
          if (xy == bisherigePte[k])
            existiertPkt = 1;
        if (existiertPkt == 0) {
          dist0 = ankathAusHypothUndAlpha(distanz[j], hoehenwinkel[j])
          if (bestimmeXY(x, y, dist0, azi[j]) == -1)
            abort("\nungueltiges Azimut.");
          xyPt["x"] = substr(bestimmeXY(x, y, dist0, azi[j]), 0, 10);
          xyPt["y"] = substr(bestimmeXY(x, y, dist0, azi[j]), 11, 10);
          xyPt["z"] = hoeheAusDistanzUndWinkel(z, distanz[j], hoehenwinkel[j]);
          distRel = round((i - minDist) / distRelDiv);
          printf(formatSilDat, abstX, abstY, xyPt["x"], xyPt["y"], xyPt["z"], xyPt["x"] " "  xyPt["y"], distanz[j], azi[j], hoehenwinkel[j], i, distRel) > panofile;
          if (abstX < minX)
            minX = abstX;
          if (abstX > maxX)
            maxX = abstX;
          if (abstY < minY)
            minY = abstY;
          if (abstY > maxY)
            maxY = abstY;
          if (namFile != "0")
            panoNamBer();
        }
        else
          existiertPkt = 0;
        bisherigePte[j] = xy; 
        abstX = abstX + (gonInMM * aufloesAziCalc);
      }
    }
    system("rm -f " resfile);
  }
  close(panofile);
}
function panoNamBer() {
  for (nam = 1; nam <= anzNam; nam++) {
    if ((((xyPt["x"] - namX[nam]) >= (toleranz * -1) && (xyPt["x"] - namX[nam]) <= toleranz) || namCode[nam] == 99) && namCode[nam] != 98) {
      if ((((xyPt["y"] - namY[nam]) >= (toleranz * -1) && (xyPt["y"] - namY[nam]) <= toleranz) || namCode[nam] == 99) && namCode[nam] != 98) {
        nameHoehe = namName[nam] namZ[nam]; 
        for (m in bisherigeNamen)
          if (nameHoehe == bisherigeNamen[m])
            existiertNam = 1;
        if (existiertNam == 0) {
          if (azimut(x, y, namX[nam], namY[nam]) > aziLi && azimut(x, y, namX[nam], namY[nam]) < aziRe) {
            namAbstX = bildkooX(x, y, namX[nam], namY[nam], aziLi, gonInMM);
            namAbstY = bildkooY(x, y, z, namX[nam], namY[nam], namZ[nam], radPr);
            namDist = distanzEbene(x, y, namX[nam], namY[nam]);
            printf(formatNamTmp, namName[nam], namZ[nam], namDist, namAbstX, namAbstY, namCode[nam]) >> namTmpFile;
            bisherigeNamen[m + 1] = nameHoehe; 
            if (namAbstY < minY)
              minY = namAbstY;
          }
        }
        else
          existiertNam = 0;
      }
    }
  }
  close(namTmpFile);
}
function dxfBer() {
  anzNam = namTmpEinlesen(namTmpFile);
  erwRechts = 60;
  erwOben = 80;
  namRe = 0;
  for (i = 1; i <= anzNam; i++) {
    if (namtX[i] > namRe)
      namRe = namtX[i];
  }
  if ((maxX - namRe) < erwRechts)
    maxX = maxX + erwRechts;
  dxfHeader(namDXFFile, minX, minY, maxX, maxY + erwOben);
  dxfInhaltBeginn(namDXFFile);
  dxfLinienInhalt(namDXFFile, minX, 0, 20, 0, "HORIZONT");        
  dxfLinienInhalt(namDXFFile, maxX - 20, 0, maxX, 0, "HORIZONT"); 
  dxfLinienInhalt(namDXFFile, minX, minY, minX, maxY + erwOben, "RAHMEN");           
  dxfLinienInhalt(namDXFFile, maxX, minY, maxX, maxY + erwOben, "RAHMEN");           
  dxfLinienInhalt(namDXFFile, minX, maxY + erwOben, maxX, maxY + erwOben, "RAHMEN"); 
  dxfLinienInhalt(namDXFFile, maxX, minY, minX, minY, "RAHMEN");                     
  dxfText(namDXFFile, minX + 3, 1, 0 , "Horizont", "HORIZONT");  
  dxfText(namDXFFile, maxX - 16, 1, 0 , "Horizont", "HORIZONT"); 
  for (i = 1; i <= anzNam; i++)
    if (namtC[i] == 99)
      dxfLinienInhalt(namDXFFile, namtX[i], namtY[i] + 0.5, namtX[i], maxY + 10, "ZUORDNUNGSLINIE_99");
    else
      dxfLinienInhalt(namDXFFile, namtX[i], namtY[i] + 0.5, namtX[i], maxY + 10, "ZUORDNUNGSLINIE");
  for (i = 1; i <= anzNam; i++)
    if (namtC[i] == 99)
      dxfText(namDXFFile, namtX[i], maxY + 12, 45, sprintf("%s  %d m / %.1f km", namtName[i], namtZ[i], namtD[i]/1000), "BERGNAME_99");
    else
      dxfText(namDXFFile, namtX[i], maxY + 12, 45, sprintf("%s  %d m / %.1f km", namtName[i], namtZ[i], namtD[i]/1000), "BERGNAME");
  dxfAbschluss(namDXFFile);
}
function abschlBer() {
  berD = convertsecs(systime() - start);
  printf("\nDauer der Berechnung: %s\n", berD);
  protokoll = "prot_" name "_" aziLi "-" aziRe ".txt";
  prot(protokoll, version);
  close(protokoll);
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
  if (ARGV[14] == "")
    exit;
}
function abort(info) {
  print info;
  print "Programm wird beendet.\n";
  exit;
}
function convertsecs(sec,    h, m, s) {
  h = sec / 3600;
  m = (sec % 3600) / 60;
  s = sec % 60;
  return sprintf("%02d Std. %02d Min. %02d Sek.\n", h, m, s);
}
function copy(source, target, errorMsg,    exitStatus) {
  exitStatus = system("cp " source " " target);
  if (exitStatus != 0)
    abort("\n" errorMsg);
}
function new(array) {
  split("", array);
}
function rep(n, s,    t) {
  while (n-- > 0)
    t = t s;
  return t;
}
function round(float) {
  return int(float + 0.5);
}
function username(    cmd) {
  cmd = "whoami";
  cmd | getline user;
  close(cmd);
  return user;
}
function dxfHeader(dxfFile, minX, minY, maxX, maxY) {
  printf("  0\n")             > dxfFile;
  printf("SECTION\n")         > dxfFile;
  printf("  2\n")             > dxfFile;
  printf("HEADER\n")          > dxfFile;
  printf("  9\n")             > dxfFile;
  printf("$ACADVER\n")        > dxfFile;
  printf("  1\n")             > dxfFile;
  printf("AC1009\n")          > dxfFile;
  printf("  9\n")             > dxfFile;
  printf("$INSBASE\n")        > dxfFile;
  printf(" 10\n")             > dxfFile;
  printf("0.0\n")             > dxfFile;
  printf(" 20\n")             > dxfFile;
  printf("0.0\n")             > dxfFile;
  printf(" 30\n")             > dxfFile;
  printf("0.0\n")             > dxfFile;
  printf("  9\n")             > dxfFile;
  printf("$EXTMIN\n")         > dxfFile;
  printf(" 10\n")             > dxfFile;
  printf("%.1f\n", minX)      > dxfFile;
  printf(" 20\n")             > dxfFile;
  printf("%.1f\n", minY)      > dxfFile;
  printf(" 30\n")             > dxfFile;
  printf("0.0\n")             > dxfFile;
  printf("  9\n")             > dxfFile;
  printf("$EXTMAX\n")         > dxfFile;
  printf(" 10\n")             > dxfFile;
  printf("%.1f\n", maxX)      > dxfFile;
  printf(" 20\n")             > dxfFile;
  printf("%.1f\n", maxY + 70) > dxfFile;
  printf(" 30\n")             > dxfFile;
  printf("0.0\n")             > dxfFile;
  printf("  9\n")             > dxfFile;
  printf("$TEXTSTYLE\n")      > dxfFile;
  printf("  7\n")             > dxfFile;
  printf("STANDARD\n")        > dxfFile;
  printf("  0\n")             > dxfFile;
  printf("ENDSEC\n")          > dxfFile;
  close(dxfFile);
}
function dxfInhaltBeginn(dxfFile) {
  printf("  0\n")             >> dxfFile;
  printf("SECTION\n")         >> dxfFile;
  printf("  2\n")             >> dxfFile;
  printf("ENTITIES\n")        >> dxfFile;
  close(dxfFile);
}
function dxfPunkteInhalt(dxfFile, x, y, typ) {
  printf("  0\n")                  >> dxfFile;
  printf("POINT\n")                >> dxfFile;
  printf("  8\n")                  >> dxfFile;
  printf("%s\n", typ)              >> dxfFile;
  printf(" 10\n")                  >> dxfFile;
  printf("%.1f\n", x)              >> dxfFile;
  printf(" 20\n")                  >> dxfFile;
  printf("%.1f\n", y)              >> dxfFile;
  printf(" 30\n")                  >> dxfFile;
  printf("0.000000000\n")          >> dxfFile;
  printf(" 39\n")                  >> dxfFile;
  printf("0.000000000\n")          >> dxfFile;
  printf(" 62\n")                  >> dxfFile;
  printf("8.000000000\n")          >> dxfFile;
  close(dxfFile);
}
function dxfLinienInhalt(dxfFile, x1, y1, x2, y2, typ) {
  printf("  0\n")                  >> dxfFile;
  printf("POLYLINE\n")             >> dxfFile;
  printf("  8\n")                  >> dxfFile;
  printf("%s\n", typ)              >> dxfFile;
  printf(" 66\n")                  >> dxfFile;
  printf("     1\n")               >> dxfFile;
  printf(" 10\n")                  >> dxfFile;
  printf("0.0\n")                  >> dxfFile;
  printf(" 20\n")                  >> dxfFile;
  printf("0.0\n")                  >> dxfFile;
  printf(" 30\n")                  >> dxfFile;
  printf("0.0\n")                  >> dxfFile;
  printf(" 70\n")                  >> dxfFile;
  printf("     0\n")               >> dxfFile;
  printf("  0\n")                  >> dxfFile;
  printf("VERTEX\n")               >> dxfFile;
  printf("  8\n")                  >> dxfFile;
  printf("%s\n", typ)              >> dxfFile;
  printf(" 66\n")                  >> dxfFile;
  printf("     1\n")               >> dxfFile;
  printf(" 10\n")                  >> dxfFile;
  printf("%.1f\n", x2)             >> dxfFile;
  printf(" 20\n")                  >> dxfFile;
  printf("%.1f\n", y2 )            >> dxfFile;
  printf(" 30\n")                  >> dxfFile;
  printf("0.0\n")                  >> dxfFile;
  printf("  0\n")                  >> dxfFile;
  printf("VERTEX\n")               >> dxfFile;
  printf("  8\n")                  >> dxfFile;
  printf("%s\n", typ)              >> dxfFile;
  printf(" 66\n")                  >> dxfFile;
  printf("     1\n")               >> dxfFile;
  printf(" 10\n")                  >> dxfFile;
  printf("%.1f\n", x1)             >> dxfFile;
  printf(" 20\n")                  >> dxfFile;
  printf("%.1f\n", y1)             >> dxfFile;
  printf(" 30\n")                  >> dxfFile;
  printf("0.0\n")                  >> dxfFile;
  printf("  0\n")                  >> dxfFile;
  printf("SEQEND\n")               >> dxfFile;
  printf("  8\n")                  >> dxfFile;
  printf("%s\n", typ)              >> dxfFile;
  close(dxfFile);
}
function dxfText(dxfFile, x, y, winkel, text, typ) {
  printf("  0\n")                  >> dxfFile;
  printf("TEXT\n")                 >> dxfFile;
  printf("  8\n")                  >> dxfFile;
  printf("%s\n", typ)              >> dxfFile;
  printf(" 10\n")                  >> dxfFile;
  printf("%.1f\n", x)              >> dxfFile;
  printf(" 20\n")                  >> dxfFile;
  printf("%.1f\n", y)              >> dxfFile;
  printf(" 30\n")                  >> dxfFile;
  printf("0.0\n")                  >> dxfFile;
  printf(" 40\n")                  >> dxfFile;
  printf("3\n")                    >> dxfFile;
  printf(" 50\n")                  >> dxfFile;
  printf("%d\n", winkel)           >> dxfFile;
  printf("  1\n")                  >> dxfFile;
  printf("%s\n", text)             >> dxfFile;
  close(dxfFile);
}
function dxfAbschluss(dxfFile) {
  printf("  0\n")             >> dxfFile;
  printf("ENDSEC\n")          >> dxfFile;
  printf("  0\n")             >> dxfFile;
  printf("EOF\n")             >> dxfFile;
  close(dxfFile);
}
function azimut(xA, yA, xB, yB,    azi) {
  azi = atan2(xB - xA, yB - yA);
  if (azi >= 0)
    return rad2gon(azi);
  else
    return 400 - rad2gon(azi) * -1;
}
function bestimmeXY(x, y, dist, aziGon,    a, b, alpha, beta, xE, yE) {
  if (aziGon == 0)
    return sprintf("%10d%10d", x, y + dist);
  else if (aziGon > 0 && aziGon < 50) {
    a = gegenkathAusHypothUndAlpha(dist, aziGon);
    xE = x + a;
    yE = y + ankathAusGegenkathUndAlpha(a, aziGon);
    return sprintf("%10d%10d", round(xE), round(yE));
  }
  else if (aziGon >= 50 && aziGon < 100) {
    beta = 100 - aziGon;
    b = gegenkathAusHypothUndAlpha(dist, beta);
    xE = x + ankathAusGegenkathUndAlpha(b, beta);
    yE = y + b;
    return sprintf("%10d%10d", round(xE), round(yE));
  }
  else if (aziGon == 100)
    return sprintf("%10d%10d", x + dist, y);
  else if (aziGon > 100 && aziGon < 150) {
    alpha = aziGon - 100;
    a = gegenkathAusHypothUndAlpha(dist, alpha);
    xE = x + ankathAusGegenkathUndAlpha(a, alpha);
    yE = y - a;
    return sprintf("%10d%10d", round(xE), round(yE));
   }
  else if (aziGon >= 150 && aziGon < 200) {
    beta = 200 - aziGon;
    b = gegenkathAusHypothUndAlpha(dist, beta);
    xE = x + b;
    yE = y - ankathAusGegenkathUndAlpha(b, beta);
    return sprintf("%-10d%-10d", round(xE), round(yE));
  }
  else if (aziGon == 200)
    return sprintf("%10d%10d", x, y - dist);
  else if (aziGon > 200 && aziGon < 250) {
    alpha = aziGon - 200;
    a = gegenkathAusHypothUndAlpha(dist, alpha);
    xE = x - a;
    yE = y - ankathAusGegenkathUndAlpha(a, alpha);
    return sprintf("%-10d%-10d", round(xE), round(yE));
  }
  else if (aziGon >= 250 && aziGon < 300) {
    beta = 300 - aziGon;
    b = gegenkathAusHypothUndAlpha(dist, beta);
    xE = x - ankathAusGegenkathUndAlpha(b, beta);
    yE = y - b;
    return sprintf("%-10d%-10d", round(xE), round(yE));
  }
  else if (aziGon == 300)
    return sprintf("%10d%10d", x - dist, y);
  else if (aziGon > 300 && aziGon < 350) {
    alpha = aziGon - 300;
    a = gegenkathAusHypothUndAlpha(dist, alpha);
    xE = x - ankathAusGegenkathUndAlpha(a, alpha);
    yE = y + a;
    return sprintf("%-10d%-10d", round(xE), round(yE));
  }
  else if (aziGon >= 350 && aziGon < 400) {
    beta = 400 - aziGon;
    b = gegenkathAusHypothUndAlpha(dist, beta);
    xE = x - b;
    yE = y + ankathAusGegenkathUndAlpha(b, beta);
    return sprintf("%-10d%-10d", round(xE), round(yE));
  }
  else
    return -1;
}
function bildkooX(xP, yP, xE, yE, aziLi, gonInMM,    azi) {
  azi = azimut(xP, yP, xE, yE);
  return (azi - aziLi) * gonInMM;
}
function bildkooY(xP, yP, zP, xE, yE, zE, radPr,    entf, entfEbene, hDiff, hdiffEkrref, hWink) {
  hDiff = zE - zP;
  entfEbene = distanzEbene(xP, yP, xE, yE);
  hdiffEkrref = hDiff - ekrref(entfEbene);
  entf = sqrt(entfEbene ^ 2 + hdiffEkrref ^ 2);
  hWink = asin(hdiffEkrref / entf);
  return radPr * tan(hWink);
}
function dhmBeschreibung(dhmTyp,    i) {
  for (i = 1; i <= anzDhm; i++)
    if (dhmTyp == dhmKuerz[i])
      return dhmBeschr[i];
}
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
      gsub(/[ ]+$/,"",$1) 
      dhmKuerz[i] = $1;
      dhmPfad[i] = $2;
      dhmBeschr[i] = $3;
      i++;
    }
  }
  close(dhmListe);
  return i - 1;
}
function dhmKopieren(dhmTyp, dhmName,    i) {
  for (i = 1; i <= anzDhm; i++)
    if (dhmTyp == dhmKuerz[i])
      copy(dhmPfad[i], dhmName, "angegebenes Hoehenmodell existiert nicht");
}
function distanzEbene(xA, yA, xB, yB) {
  return sqrt((xA - xB) ^ 2 + (yA - yB) ^ 2);
}
function distGre(haelfteMittelsenkr, aziGon) {
  if (aziGon >=0 && aziGon < 50)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, aziGon);
  else if (aziGon >= 50 && aziGon < 100)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, 100 - aziGon);
  else if (aziGon >= 100 && aziGon < 150)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, aziGon - 100);
  else if (aziGon >= 150 && aziGon < 200)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, 200 - aziGon);
  else if (aziGon >= 200 && aziGon < 250)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, aziGon - 200);
  else if (aziGon >= 250 && aziGon < 300)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, 300 - aziGon);
  else if (aziGon >= 300 && aziGon < 350)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, aziGon - 300);
  else if (aziGon >= 350 && aziGon < 400)
    return hypothAusAnkathUndAlpha(haelfteMittelsenkr, 400 - aziGon);
  else
    return -1;
}
function ekrref(dist,    k, erdR) {
  k = 0.13;
  erdR = 6370000;
  return (1 - k) * dist^2 / (2 * erdR);
}
function extrempunkteNESW(xAkt, yAkt, azi, dist, hWink) {
  if (yAkt > exNord["y"]) {
    exNord["x"] = xAkt;
    exNord["y"] = yAkt;
    exNord["Azi"] = azi;
    exNord["Distanz"] = dist;
    exNord["Hoehenwinkel"] = hWink;
  }
  if (xAkt > exOst["x"]) {
    exOst["x"] = xAkt;
    exOst["y"] = yAkt;
    exOst["Azi"] = azi;
    exOst["Distanz"] = dist;
    exOst["Hoehenwinkel"] = hWink;
  }
  if (yAkt < exSued["y"]) {
    exSued["x"] = xAkt;
    exSued["y"] = yAkt;
    exSued["Azi"] = azi;
    exSued["Distanz"] = dist;
    exSued["Hoehenwinkel"] = hWink;
  }
  if (xAkt < exWest["x"]) {
    exWest["x"] = xAkt;
    exWest["y"] = yAkt;
    exWest["Azi"] = azi;
    exWest["Distanz"] = dist;
    exWest["Hoehenwinkel"] = hWink;
  }
}
function hoeheAusDistanzUndWinkel(z, dist, hWink,    h) {
  h = gegenkathAusHypothUndAlpha(dist, hWink);
  h = h + ekrref(dist);
  return h = h + z;
}
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
function modellhoehe(res,    mh) {
  while ((getline < res) > 0)
    if ($0 ~ /^Model/) {
      mh = substr($0, 50, 7);
      mh = mh + 0;
    }
  close(res);  
  return mh;
}
function namBeschreibung(namTyp,    i) {
  for (i = 1; i <= anzNamFiles; i++)
    if (namTyp == namKuerz[i]  ".txt")
      return namBeschr[i];
}
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
      gsub(/[ ]+$/,"",$1) 
      namKuerz[i] = $1;
      namPfad[i] = $2;
      namBeschr[i] = $3;
      i++;
    }
  }
  close(namListe);
  return i - 1;
}
function namTmpEinlesen(namTmpFile,    i) {
  new(namtName);
  new(namtZ);
  new(namtD);
  new(namtX);
  new(namtY);
  new(namtC);
  i = 0;
  while ((getline < namTmpFile) > 0) {
    i++;
    gsub(/[ ]+$/,"",$1) 
    namtName[i] = $1;
    namtZ[i] = $2;
    namtZ[i] = namtZ[i] + 0;
    namtD[i] = $3;
    namtD[i] = namtD[i] + 0;
    namtX[i] = $4;
    namtX[i] = namtX[i] + 0;
    namtY[i] = $5;
    namtY[i] = namtY[i] + 0;
    namtC[i] = $6;
	namtC[i] = namtC[i] + 0;
  }
  close(namTmpFile);
  return i;
}
function namKopieren(namTyp,    i) {
  for (i = 1; i <= anzNamFiles; i++)
    if (namTyp == namKuerz[i] ".txt")
      copy(namPfad[i], ".", "angegebenes Namensfile existiert nicht");
}
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
function prot(protFile, vers) {
  printf("Berechnet am : %s\n", strftime("%a. %d. %B %Y, %H:%M Uhr", systime()))                 > protFile;
  printf("Berechnet von: %s\n\n\n", username())                                                  > protFile;
  printf("%s\n", rep(90, "*"))                                                                   > protFile;
  printf("Berechnungsprotokoll %s\n", name)                                                      > protFile;
  printf("skyplot2pano v%s, https://github.com/ABoehlen/skyplot2pano\n", vers)                   > protFile;
  printf("%s\n", rep(90, "*"))                                                                   > protFile;
  printf("\n\nEingabe\n")                                                                        > protFile;
  printf("%s\n\n", rep(7, "*"))                                                                  > protFile;
  printf("Standort (X / Y / Z)                :  %d / %d / %d\n", x, y, z)                       > protFile;
  printf("Name                                :  %s\n", name)                                    > protFile;
  printf("Azimut links                        :  %d gon\n", aziLi)                               > protFile;
  printf("Azimut rechts                       :  %d gon\n", aziRe)                               > protFile;
  printf("Azimutale Aufloesung                :  %.3f gon\n", aufloesAzi)                        > protFile;
  printf("Bildbreite                          :  %d mm\n", bildbr)                               > protFile;
  printf("Verwendetes Hoehenmodell            :  %s\n", dhmBeschreibung(dhm))                    > protFile;
  if (namFile != "0")                                                                            
    printf("Verwendete Namendatei               :  %s\n", namBeschreibung(namFile))              > protFile;
  printf("Berechnungen ab                        %d km\n", minDist / 1000)                       > protFile;
  printf("   bis                                 %d km\n", maxDist / 1000)                       > protFile;
  printf("   im Abstand von                      %d m durchgefuehrt\n", aufloesDist)             > protFile;
  printf("\n\n\nAbgeleitete Parameter\n")                                                        > protFile;
  printf("%s\n\n", rep(21, "*"))                                                                 > protFile;
  printf("Eingegebene Hoehe                   :  %.1f m\n", z)                                   > protFile;
  printf("Interpolierte Hoehe im %-13s:  %.1f m\n", toupper(dhm), mhoehe)                        > protFile;
  printf("Differenz zum Hoehenmodell          :  %.1f m\n", z - mhoehe)                          > protFile;
  printf("Oeffnungswinkel                     :  %d gon\n", aziRe - aziLi)                       > protFile;
  printf("Projektionszylinderradius           :  %.3f mm\n", radPr)                              > protFile;
  printf("Effektive azimutale Aufloesung      :  %.5f gon\n", aufloesAziCalc)                    > protFile;
  printf("Anzahl Berechnungen                 :  %d\n", anzBer)                                  > protFile;
  printf("Berechnungsdauer                    :  %s\n", berD)                                    > protFile;
  printf("\n\n\nTopographische Extrempunkte\n")                                                  > protFile;
  printf("%s\n\n", rep(27, "*"))                                                                 > protFile;
  printf("Extrempunkt    " formatProtTxt,\
    "X", "Y", "Z", "D [km]", "Azi [gon]", "E-R [m]", "dH [m]")                                   > protFile;
  printf("%s\n", rep(68, "-"))                                                                   > protFile;
  printf("Noerdlichster: " formatProtDat,\
    exNord["x"], exNord["y"], exNord["z"], exNord["Distanz"] / 1000, exNord["Azi"], ekrref(exNord["Distanz"]), exNord["z"] - z) > protFile;
  printf("Oestlichster:  " formatProtDat,\
    exOst["x"], exOst["y"], exOst["z"], exOst["Distanz"] / 1000, exOst["Azi"], ekrref(exOst["Distanz"]), exOst["z"] - z)        > protFile;
  printf("Suedlichster:  " formatProtDat,\
    exSued["x"], exSued["y"], exSued["z"], exSued["Distanz"] / 1000, exSued["Azi"], ekrref(exSued["Distanz"]), exSued["z"] - z) > protFile;
  printf("Westlichster:  " formatProtDat,\
    exWest["x"], exWest["y"], exWest["z"], exWest["Distanz"] / 1000, exWest["Azi"], ekrref(exWest["Distanz"]), exWest["z"] - z) > protFile;
  printf("Hoechster:     " formatProtDat,\
    exHoe["x"], exHoe["y"], exHoe["z"], exHoe["Distanz"] / 1000, exHoe["Azi"], ekrref(exHoe["Distanz"]), exHoe["z"] - z)            > protFile;
  printf("Entferntester: " formatProtDat,\
    exEntf["x"], exEntf["y"], exEntf["z"], exEntf["Distanz"] / 1000, exEntf["Azi"], ekrref(exEntf["Distanz"]), exEntf["z"] - z)     > protFile;
}
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
function theoausweit(z,    k, erdRad) {
  erdRad = 6370000 ;
  k = 0.13;
  return (sqrt((2 * erdRad) / (1 - k)) * sqrt(z));
}
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
function pi() {
  return atan2(0, -1);
}
function gon2rad(gon) {
  return pi() / (400 / 2) * gon;
}
function rad2gon(rad) {
  return rad * (400 / 2) / pi();
}
function asin(x) {
  return atan2(x, sqrt(1 - x * x));
}
function tan(winkel) {
  return sin(winkel) / cos(winkel);
}
function ankathAusHypothUndAlpha(c, winkelGon) {
  return c * sin(gon2rad(100 - winkelGon));
}
function gegenkathAusHypothUndAlpha(c, winkelGon) {
  return c * sin(gon2rad(winkelGon));
}
function ankathAusGegenkathUndAlpha(a, winkelGon) {
  return a / tan(gon2rad(winkelGon));
}
function hypothAusAnkathUndAlpha(b, winkelGon) {
  return b / cos(gon2rad(winkelGon));
}