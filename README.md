# KT-Advance C Ananlyser Atom package for linter

## Installation and first run

1. Make sure java 8 is installed on your computer and is available on $PATH. In Terminal, type `java -version`, if it says `command not found`, stop reading this doc.
2. The `atom-kt-advance` is based on linter package. So, install it from https://atom.io/packages/linter
3. Download the `atom-kt-advance` code from https://github.com/compartia/atom-kt-advance and put it (or symlink) to your Atom packages directory
(e.g `~/.atom/packages/`)  so you have `/.atom/packages/atom-kt-advance`
4. Relaunch Atom
5. In Atom, open a sample KT-analyzed C project (for example, this one: https://github.com/mrbkt/kestreltech/tree/master/src/test/resources/test_project/itc-benchmarks/01.w_Defects)
6. In Atom, open Developer's Tools Console (by pressing `command-alt-i`) and make sure there's a line logged `kt-advance: activate` 
![Image](https://raw.githubusercontent.com/compartia/atom-kt-advance/master/screenshots/Screen%20Shot%202016-09-29%20at%2010.35.31.png?token=AHUl_XfcnsC0ambxNQiD_EugHV02nKz-ks5X9gdqwA%3D%3D)

Right after it is activated, the plugin spawns a java process to scan the C project for the `ch_analysis` dir. After the scan in complete, ensure that `kt_analysis_export/kt.json` is created.
7. Open a random C file and press `command-S` to save it (linter is triggered every time a C file is saved)

![Image](https://raw.githubusercontent.com/compartia/atom-kt-advance/master/screenshots/Screen%20Shot%202016-09-29%20at%2010.44.02.png?token=AHUl_RO9hQH6CP2aLpinGhKo8v9mLNzaks5X9ghQwA%3D%3D)

