/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module scite.seatd_scite_dll;

import tango.stdc.stdlib;

import tango.sys.win32.Types;
import tango.sys.win32.UserGdi;

import scite.scite_ext;
import scite.seatd_scite;


HINSTANCE g_hInst;

extern (C)
{
    void gc_init();
    void gc_term();
    void _minit();
    void _moduleCtor();
    void _moduleUnitTests();
}

extern (C) bool rt_init( void delegate( Exception ) dg = null );
extern (C) bool rt_term( void delegate( Exception ) dg = null );

extern (Windows) BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
            rt_init();
/+             gc_init();
            _minit();
            _moduleCtor();
            _moduleUnitTests();
 +/            break;
        case DLL_PROCESS_DETACH:
            rt_term();
//            gc_term();
            break;
        case DLL_THREAD_ATTACH:
        case DLL_THREAD_DETACH:
        default:
            return false;
    }
    g_hInst=hInstance;
    return true;
}

SeatdScite seatd;

export extern(C) Extension get_SciTE_extension(uint major, uint minor)
{
    if ( major != 1 || minor != 74 ) {
        MessageBoxA(null, "This version of SEATD for SciTE requires SciTE v1.74!\0", "SEATD ERROR\0", MB_OK);
        return null;
    }
    
    seatd = new SeatdScite;
    return cast(Extension)seatd;
}
