# KT-Advance C Analyser Atom Package for Linter

## Installation and First Run

1. Make sure Java 8 is installed on your computer and is available on $PATH. In Terminal, type `java -version`, if it says `command not found`, stop reading this doc.  Java 8 installation kits can be found at [Oracle](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html).   
2. The `atom-kt-advance` package is based on the `linter` package. So, install it from https://atom.io/packages/linter
3. Download the `atom-kt-advance` code from https://github.com/compartia/atom-kt-advance and put it (or a symlink) to your Atom packages directory
(e.g `~/.atom/packages/`)  so you have `/.atom/packages/atom-kt-advance`
4. Relaunch Atom
5. In Atom, open a sample KT-Advance-analyzed C project (for example, this one: https://github.com/mrbkt/kestreltech/tree/master/src/test/resources/test_project/itc-benchmarks/01.w_Defects)
6. In Atom, open Developer's Tools Console (by pressing `command-alt-i`) and make sure there's a line logged `kt-advance: activate`
![Image](https://github.com/compartia/atom-kt-advance/blob/master/screenshots/Screen%20Shot%202016-09-29%20at%2010.35.31.png)

Right after it is activated, the plugin spawns a java process to scan the C project for the `ch_analysis` dir. After the scan in complete, ensure that `kt_analysis_export/kt.json` is created.

7. Open a random C file and press `command-S` to save it (linter is triggered every time a C file is saved)
![Image](https://github.com/compartia/atom-kt-advance/blob/master/screenshots/Screen%20Shot%202016-09-29%20at%2010.44.02.png)

