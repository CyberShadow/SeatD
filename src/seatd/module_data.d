/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module seatd.module_data;

import tango.io.File;
import tango.io.FilePath;
import tango.text.Util;

import tango.text.convert.Layout;

private static Layout!(char) layout;

static this()
{
    layout = new Layout!(char);
}

string format(string fmt, ...)
{
    return layout.convert(_arguments, _argptr, fmt);
}

alias char[] string;

import avltree;

import util;


alias uint DeclAttribute;
const   atDeprecated    = 0x1;
const   atPrivate       = 0x2;
const   atPackage       = 0x4;
const   atProtected     = 0x8;
const   atPublic        = 0x10;
const   atExport        = 0x20;
const   atStatic        = 0x40;
const   atFinal         = 0x80;
const   atOverride      = 0x100;
const   atAbstract      = 0x200;
const   atConst         = 0x400;
const   atAuto          = 0x800;
const   atScope         = 0x1000;
const   atExtern        = 0x2000;
const   atAlignAttribute= 0x4000;
const   atPragma        = 0x8000;
const   atInvariant     = 0x10000;
const   atSynchronized  = 0x20000;

/**************************************************************************************************
    Represents any declaration in a module.
**************************************************************************************************/
class Declaration
{
    static const string[] TYPE_NAMES = [
        "module",
        "function",
        "class",
        "struct",
        "enum",
        "template",
        "interface",
        "variable"
    ];
    enum Type
    {
        dtModule,
        dtFunction,
        dtClass,
        dtStruct,
        dtUnion,
        dtEnum,
        dtEnumMember,
        dtTemplate,
        dtInterface,
        dtVariable,
        dtParamater
    }

    Declaration     parent;
    Declaration[]   children;
    DeclAttribute   attributes;
    string          ident,
                    mangled_type;
    Type            dtType;
    uint            line, column;

    this(string id)
    {
        ident = id;
    }
    
    this(Declaration p, Type t, DeclAttribute attrs, string id, uint ln, uint col)
    {
        parent = p;
        if ( p !is null )
            p.children ~= this;
        ident = id;
        dtType = t;
        attributes = attrs;
        line = ln;
        column = col;
    }
    
    /**********************************************************************************************
        Compare declarations by their identifiers.
    **********************************************************************************************/
    int opCmp(Declaration d)
    {
        if ( ident == d.ident )
            return 0;
        if ( ident < d.ident )
            return -1;
        return 1;
    }

    /**********************************************************************************************
        Returns the fully qualified identifier of this declaration.
    **********************************************************************************************/
    string fqnIdent()
    {
        string fqn;
        for ( auto d = this; d !is null; d = d.parent )
        {
            if ( d !is this )
                fqn = d.ident~"."~fqn;
            else
                fqn = ident;
        }
        return fqn;
    }
}
alias AVLTree!(Declaration) DeclAVL;


/**************************************************************************************************
    Represents an import in a module.
    TODO: imports may be descendants of declarations
**************************************************************************************************/
class Import
{
    string  module_name;
    DeclAttribute attributes;
    
    this(DeclAttribute attrs)
    {
        attributes = attrs;
    }
    
    bool isPublic()
    {
        return (attributes & atPublic) > 0;
    }
}


/**************************************************************************************************
    Represents a D source module.
**************************************************************************************************/
class ModuleData
{
    string      fqname,
                path,
                file_name;
    long        modified_time;
    Import[]    imports;
    DeclAVL     decls;

    this(string fqn)
    {
        fqname = fqn;
        decls = new DeclAVL;
    }

    this(string fp, string fn, long mod)
    {
        path = fp;
        file_name = fn;
        modified_time = mod;
        decls = new DeclAVL;
    }

    string toString()
    {
        string str = format("Module name: {}\n", fqname);
        foreach ( imp; imports )
            str ~= format("Import: {}\n", imp.module_name);
        foreach ( Declaration decl; decls )
        {
            str ~= format("Declaration: {} {} ({}:{})", Declaration.TYPE_NAMES[decl.dtType], decl.ident, decl.line, decl.column);
            for ( Declaration p = decl.parent; p !is null; p = p.parent )
                str ~= format(" {}", p.ident);
            str ~= "\n";
        }
        return str;
    }
}
