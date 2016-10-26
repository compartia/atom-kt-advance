# KT-Advance C Analyzer Atom Package for Linter

## Installation and First Run

1. Make sure Java 8 is installed on your computer and is available on $PATH. In Terminal, type `java -version`, if it says `command not found`, stop reading this doc.  Java 8 installation kits can be found at [Oracle](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html).   
2. The `atom-kt-advance` package is based on the `linter` package. So, install it from https://atom.io/packages/linter
3. Download the `atom-kt-advance` code from https://github.com/compartia/atom-kt-advance and put it (or a symlink) to your Atom packages directory
(e.g `~/.atom/packages/`)  so you have `/.atom/packages/atom-kt-advance`
4. Remove all exiting `kt_analysis_export` dirs if any (this is relevant when upgrading to newer version)
5. Relaunch Atom
6. By pressing Cmd+Shift+P, bring up the Command Palette. Run the command "Update Package Dependencies: Update"
7. In Atom, open a sample KT-Advance-analyzed C project (for example, this one: https://github.com/mrbkt/kestreltech/tree/master/src/test/resources/test_project/itc-benchmarks/01.w_Defects)
8. In Atom, open Developer's Tools Console (by pressing `command-alt-i`) and make sure there's a line logged `kt-advance: activate`
![Image](https://github.com/compartia/atom-kt-advance/blob/master/screenshots/Screen%20Shot%202016-09-29%20at%2010.35.31.png)

Right after it is activated, the plugin spawns a java process to scan the C project for the `ch_analysis` dir. After the scan in complete, ensure that `kt_analysis_export` dir is created and contains some files.

9. Open a random C file and press `command-S` to save it (linter is triggered every time a C file is saved)
![Image](https://github.com/compartia/atom-kt-advance/blob/master/screenshots/Screen%20Shot%202016-09-29%20at%2010.44.02.png)

## Dependencies
1.  This package depends on https://github.com/compartia/kt-advance-to-json which in turn depends on https://github.com/mrbkt/kestreltech/tree/atom-tools
2. Linter package: https://atom.io/packages/linter
