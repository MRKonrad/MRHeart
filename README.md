
# MRHeart

[![DOI of an article about MRHeart](https://img.shields.io/badge/DOI-10.24255%2Fhbj%2F100671-blue.svg)](https://doi.org/10.24255/hbj/100671)
[![DOI of the software](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.1227712-blue.svg)](https://zenodo.org/badge/latestdoi/130806489)

MRHeart is an image segmentation tool for OsiriX and Horos, originally developed by Konrad Werys.

Original project:  
https://github.com/MRKonrad/MRHeart

Original MRHeart documentation:  
http://mrkonrad.github.io/MRKonrad/MRHeart

Demo:  
https://youtu.be/IiGqJnodx6A

## Apple Silicon / Horos compatibility update

This repository provides an updated build configuration for running MRHeart with Horos on Apple Silicon Macs.

The original MRHeart source code and calculation methods have been preserved. The changes in this version are limited to compatibility and build configuration.

### Main changes

- Replaced legacy `OsiriXAPI` imports with `Horos` framework imports.
- Updated the project to build against `Horos.framework`.
- Added native Apple Silicon (`arm64`) build configuration.
- Updated the macOS deployment target.
- Removed legacy architecture settings incompatible with the current build environment.

No changes were made to the MRHeart segmentation or ventricular volume calculation algorithms.

## Tested environment

This update has been successfully built and functionally tested with:

- Horos 4.0.1
- Apple Silicon (`arm64`)
- macOS 26.6.1
- Xcode 26.6
- Native execution without Rosetta

These versions represent the environment in which the plugin was tested and should not be interpreted as minimum system requirements.

Compatibility with other Horos versions, Intel Macs, or other macOS/Xcode versions has not been systematically tested.

## Building

`Horos.framework` is required to compile the plugin but is not distributed with this repository.

For Horos 4.0.1, the framework can be obtained from the local Horos installation at:

`/Applications/Horos.app/Contents/Frameworks/Horos.framework`

Copy `Horos.framework` to the root directory of the MRHeart project before building.

The project directory should contain:

- `Horos.framework`
- `MRHeart.xcodeproj`
- `MRHeartFilter.h`
- `MRHeartFilter.m`

Open `MRHeart.xcodeproj` in Xcode and build the `MRHeart` target for `arm64`.

The resulting plugin bundle will be named `MRHeart.osirixplugin`.

## Installation

Close Horos before installing or replacing the plugin.

Copy `MRHeart.osirixplugin` to:

`~/Library/Application Support/Horos/Plugins/`

Then reopen Horos.

## License and attribution

MRHeart was originally developed by Konrad Werys and is distributed under the MIT License.

This repository preserves the original copyright notice and MIT License.

This update is intended to maintain compatibility of the original MRHeart plugin with the tested Horos and Apple Silicon environment while preserving its original functionality.
