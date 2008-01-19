#!/bin/bash

echo -------------------------------------------------------------------
echo Bulding D modules
echo -------------------------------------------------------------------

pushd ../..
rebuild -c src/kate/seatd_kate.d -fPIC -g -release -Isrc -version=Tango -oqobj
popd

echo
echo -------------------------------------------------------------------
echo Bulding C++ modules
echo -------------------------------------------------------------------

moc-qt3 plugin_kateseatd.h >plugin_kateseatd.moc
libtool --mode=compile g++ -c -g -I/usr/include/kde/ -I/usr/include/qt3/ plugin_kateseatd.cpp

echo
echo -------------------------------------------------------------------
echo Linking modules
echo -------------------------------------------------------------------

libtool --mode=link g++ -g -avoid-version -no-undefined -module -rpath /usr/lib/kde3/ -o kateseatdplugin.la plugin_kateseatd.lo ../../obj/*.o -lkateinterfaces -lgphobos -lpthread

echo
echo -------------------------------------------------------------------
echo Building installation package
echo -------------------------------------------------------------------

mkdir -p install/lib/kde3
mkdir -p install/share/apps/kate/plugins/kateseatd
mkdir -p install/share/services

pushd install
tar cvj * > ../seatd_kate_x86-64_experimental.tar.bz2
popd

echo
echo -------------------------------------------------------------------
echo Installing to user home
echo -------------------------------------------------------------------

cp kateseatd.desktop install/share/services/
cp ui.rc install/share/apps/kate/plugins/kateseatd/
cp kateseatdplugin.la .libs/kateseatdplugin.so install/lib/kde3/

echo done
echo
