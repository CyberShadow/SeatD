#!/bin/bash

pushd ../..
echo Bulding D modules
rebuild -c src/kate/seatd_kate.d -fPIC -g -release -Isrc -version=Tango -oqobj
popd
echo -------------------------------------------------------------------

moc-qt3 plugin_kateseatd.h >plugin_kateseatd.moc
libtool --mode=compile g++ -c -g -I/usr/include/kde/ -I/usr/include/qt3/ plugin_kateseatd.cpp
libtool --mode=link g++ -g -avoid-version -no-undefined -module -rpath /usr/lib/kde3/ -o kateseatdplugin.la plugin_kateseatd.lo ../../obj/*.o -lkateinterfaces -lgphobos -lpthread

# sudo mkdir /usr/share/apps/kate/plugins/kateseatd
# sudo cp ui.rc /usr/share/apps/kate/plugins/kateseatd/
# sudo cp kateseatd.desktop /usr/share/services/
# sudo cp kateseatdplugin.la .libs/kateseatdplugin.so /usr/lib/kde3/

cp kateseatd.desktop ~/.kde/share/services/
#cp ui.rc ~/.kde/share/apps/kate/plugins/kateseatd/
cp kateseatdplugin.la .libs/kateseatdplugin.so ~/.kde/lib/kde3/
