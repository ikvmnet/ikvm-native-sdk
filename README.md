# ikvm-native-sdk

This repository builds various SDKs containing headers and libraries for targeting operating systems for building the native components of IKVM.

Each of the build scripts must be run on a modern Linux host.

# Windows

The Windows SDK is located in `windows/`. It uses the `xwin` tool to download the SDK directly from Microsoft and extract it into a normalized folder structure. Casing is fixed, etc. The resulting artifact is produced in `dist/windows` and is suitable for copying to a Linux or OS X machine.

# Linux

The Linux SDK(s) are located in `linux/'. To build the SDKs, first, crosstool-ng is used to generate a cross compiling toolchain. This tool chain runs on the host machine, but produces code for the target machine. The toolchain is then invoked to build the required libraries for the SDKs in the target architecture. The build.sh script can be invoked without any arguments and it will generate each target. Or the name of the target can be specified as the first argument.

# Mac OS X

The OS X SDK is located in `macosx/`. It downloads the MacOS X SDK package from a known URL. It would be nice to generate this locally, but we are not there yet.
