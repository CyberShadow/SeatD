set PATH=c:\tango\bin;%PATH%
dmd @dmd.rf
link obj\abstract_plugin+obj\container+obj\avltree+obj\seatd_scite_dll+obj\seatd_scite+obj\scite_ext+obj\parser+obj\package_data+obj\module_data+obj\util,bin\seatd.dll,,user32+kernel32+tango-base-dmd+tango-user-dmd,src\scite\seatd_scite.def/noi/CODEVIEW
