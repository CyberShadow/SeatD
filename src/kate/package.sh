#!/bin/bash

echo -------------------------------------------------------------------
echo Building installation package
echo -------------------------------------------------------------------

mkdir -p install/lib/kde3
mkdir -p install/share/apps/kate/plugins/kateseatd
mkdir -p install/share/services

cp {INSTALL,README,KNOWN_ISSUES}.txt install
cp kateseatd.desktop install/share/services/
cp ui.rc install/share/apps/kate/plugins/kateseatd/
cp kateseatdplugin.la .libs/kateseatdplugin.so install/lib/kde3/

pushd install
tar cvj * > ../seatd_kate_0.02-x86-64-alpha-preview.tar.bz2
popd
rm -rf install
