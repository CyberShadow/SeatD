#!/bin/bash

DFLAGS="-fPIC -g -release"
CFLAGS=-g
LFLAGS=-g

echo -------------------------------------------------------------------
echo Bulding D modules
echo -------------------------------------------------------------------

pushd ../..
rebuild $DFLAGS -c src/kate/seatd_kate.d -version=Tango -Isrc -oqobj
popd

echo
echo -------------------------------------------------------------------
echo Bulding C++ modules
echo -------------------------------------------------------------------

moc-qt3 plugin_kateseatd.h >plugin_kateseatd.moc
libtool --mode=compile g++ -c $CFLAGS -I/usr/include/kde/ -I/usr/include/qt3/ plugin_kateseatd.cpp

echo
echo -------------------------------------------------------------------
echo Linking modules
echo -------------------------------------------------------------------

libtool --mode=link g++ $LFLAGS -avoid-version -no-undefined -module -rpath /usr/lib/kde3/ -o kateseatdplugin.la plugin_kateseatd.lo ../../obj/*.o -lkateinterfaces -lgphobos -lpthread

echo
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

echo
echo -------------------------------------------------------------------
echo Installing to user home
echo -------------------------------------------------------------------

mkdir -p ~/.kde/lib/kde3
mkdir -p ~/.kde/share/apps/kate/plugins/kateseatd
mkdir -p ~/.kde/share/services
cp kateseatd.desktop ~/.kde/share/services/
cp -u ui.rc ~/.kde/share/apps/kate/plugins/kateseatd/
cp kateseatdplugin.la .libs/kateseatdplugin.so ~/.kde/lib/kde3/

echo done
echo
