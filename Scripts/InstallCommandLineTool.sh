#!/bin/sh

# InstallCommandLineTool.sh
# Platypus
#
# Created by Sveinbjorn Thordarson on 6/17/08.
# Copyright (C) 2003-2011. All rights reserved.

# Create directories if they don't exist
mkdir -p "/usr/local/bin"
mkdir -p "/usr/local/share/platypus"
mkdir -p "/usr/local/share/man/man1"

# Change to Resources directory of Platypus application, which is first argument
cd "$1"

# Copy resources over
cp "platypus_clt" "/usr/local/bin/platypus"
cp "ScriptExec" "/usr/local/share/platypus/ScriptExec"
cp "platypus.1" "/usr/local/share/man/man1/platypus.1"
cp "PlatypusDefault.icns" "/usr/local/share/platypus/PlatypusDefault.icns"
cp -r "MainMenu.nib" "/usr/local/share/platypus/"

chmod -R 755 "/usr/local/share/platypus/"

# Create text file with version
echo "4.5" > "/usr/local/share/platypus/Version"

exit 0