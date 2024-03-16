# skyplot2pano

## Purpose
skyplot2pano is an AWK script which uses the function of SCOP.SKYPLOT of the TU Wien (Vienna University of Technology) from 1999 for the calculation of panoramas with silhouettes and the determination of visibility parameters. SCOP.SKYPLOT is a small utility programme of the SCOP programme system.
The results of skyplot2pano are two text files: The prot file is the log containing the given arguments and various derived information. The sil file is a comma-separated text file that can be visualized by a geographic information system (e.g. ArcGIS, QGIS...) using the X and Y fields. The DistRel field can be used to symbolise the points. The nearest points have the value 0, the furthest points the values 8 or 9. Using the calculated position coordinates, it is possible to localize the displayed peaks.

## Background

According to the TU Wien documentation, SCOP.SKYPLOT calculates the visibility limit through the topography for a given position based on a digital terrain model. \[1\] The result is a list containing the three columns azimuth, elevation angle of the visibility limit and distance of the visibility limit point. This information can be used to calculate a visual panorama view and to derive the coordinates of the points. \[2\] In this way, statements can also be made as to which is the most distant, northernmost, easternmost etc. visible point from the location.

## System requirements
The programme requires Gawk 4.0 or higher. It's best used on Windows within _git for Windows_ or _Cygwin_. The SCOP utility skyplot.exe and at least one digital elevation model in the native SCOP format RDH (*.dtm) are also required.

## Installation
Download the repository into your desired directory:

```
cd <directory>
git clone https://github.com/ABoehlen/skyplot2pano
cd grid2mlt
```

Then you just type…

```
./skyplot2pano.awk
```

…for getting the usage:

```
Usage: skyplot2pano.awk  <X> <Y> <Z> <Name> <DHM> <Aufloes-Azi> <Azi links> <Azi rechts> <Bildbreite> <Min-Dist> <Max-Dist> <Aufloes-Dist>
```

## Usage

The meanings of the various arguments are described in the usage (in German). For further details please take a look at the detailed documentation (also in German): https://aboehlen.github.io/dok/skyplot2pano.html

## Test file

You can use the enclosed file dhm1000.dtm for test purposes. This is a version of the DHM25 digital elevation model with a 1000 m grid. 

Reference:
Federal Office of Topography swisstopo
©swisstopo 

## License

This project is licensed under the MIT License - see the LICENSE file for details

## Literature
\[1\] SCOP.SKYPLOT (Abschattungsberechnungen aus einem Geländemodell), Benutzerhandbuch. Wien 1999 (in German)

\[2\] Rickenbacher, Martin: Panorama vom Wittnauer Homberg, Wittnau 1991 (in German): http://www.martinrickenbacher.ch/panoramen/Adlerauge_1991_Panorama_vom_Wittnauer_Homberg_ocr.pdf