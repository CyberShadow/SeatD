/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module seatd.common;

/**************************************************************************************************

**************************************************************************************************/
enum Protection
{
    Pundefined,
    Pnone,
    Pprivate,
    Ppackage,
    Pprotected,
    Ppublic,
    Pexport,
};
