/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module seatd.symbol;

import tango.io.Stdout;
import tango.io.FilePath;
import tango.text.convert.Integer;
import tango.text.Util;

import seatd.type;
import seatd.parser : SyntaxTree, DeclDefNode = _ST_DeclDef;
import common;
import container;

/**************************************************************************************************

**************************************************************************************************/
alias uint SymbolAttribute;
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

**************************************************************************************************/
struct Location
{
    Module  mod;
    uint    line,
            column;

    static Location opCall(Module m, uint l, uint c)
    {
        Location loc;
        loc.mod = m;
        loc.line = l;
        loc.column = c;
        return loc;
    }

    string toString()
    {
        if ( mod is null )
            return "unknown module("~.toString(line)~":"~.toString(column)~")";
        return mod.toString~"("~.toString(line)~":"~.toString(column)~")";
    }
}

/**************************************************************************************************

**************************************************************************************************/
class StringWrap
{
    string str_;

    this(string str) { str_ = str; }

	int opCmp(Object o)
	{
	    Symbol s = cast(Symbol)o;
	    if ( s !is null )
            return -s.opCmp(this);

        StringWrap sw = cast(StringWrap)o;
        if ( sw is null )
            return -1;
        if ( str_ == sw.str_ )
            return 0;
	    if ( str_ < sw.str_ )
            return -1;
        return 1;
	}
}

/**************************************************************************************************

**************************************************************************************************/
class Symbol
{
    ScopeSymbol     parent_;
    string          identifier_;
    SymbolAttribute attribute_;
    Location        location_;

    protected this(string ident)
    {
        identifier_ = ident;
    }

    this(string ident, Location loc)
    {
        identifier_ = ident;
        location_ = loc;
    }

    /**********************************************************************************************
        Compare symbols by their identifier.
    **********************************************************************************************/
	int opCmp(Object o)
	{
        string str = void;
	    Symbol s = cast(Symbol)o;
	    if ( s !is null )
            str = s.identifier_;
        else
        {
            StringWrap sw = cast(StringWrap)o;
            if ( sw is null )
                assert(0);
            str = sw.str_;
        }

        if ( identifier_ == str )
            return 0;
        if ( identifier_ < str )
            return -1;
        return 1;
    }

    /**********************************************************************************************
        Returns the fully qualified identifier of this declaration.
    **********************************************************************************************/
    string fqnString()
    {
        string s;
        auto a = fqn();
        if ( a.length <= 0 )
            return null;
        s ~= a[0];
        foreach ( i; a[1..$] )
            s ~= "."~i;
        return s;
    }

    /**********************************************************************************************
        Returns the fully qualified identifier of this declaration.
    **********************************************************************************************/
    string[] fqn()
    {
        string[] fqn;
        for ( auto s = this; s !is null; s = s.parent_ )
            fqn ~= s.identifier_;
        return fqn.reverse;
    }

    /**********************************************************************************************
        Returns the fully qualified identifier of this declaration without the module name.
        If the declaration is a module itself, it's name is constructed, though.
    **********************************************************************************************/
    string fqnIdentWithoutModule()
    {
        string  fqn;
        bool    no_module = cast(Module)this is null;
        for ( auto s = this; s !is null; s = s.parent_ )
        {
            if ( no_module && cast(Module)s !is null )
                break;
            if ( s !is this )
                fqn = s.identifier_~"."~fqn;
            else
                fqn = identifier_;
        }
        return fqn;
    }

    /**********************************************************************************************
        Find containing module of this symbol.
        Returns:    reference to a Module or null if this symbol has no containing module.
    **********************************************************************************************/
    Module findModule()
    {
        Module m;
        for ( auto s = this; s !is null && m is null; s = s.parent_ )
            m = cast(Module)s;
        return m;
    }

    /**********************************************************************************************

    **********************************************************************************************/
    string toString()
    {
        return identifier_~" "~location_.toString;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class ScopeSymbol : public Symbol
{
    this(string ident, Location loc)
    {
        super(ident, loc);
        members_ = new AVLTree!(Symbol);
    }

    protected this(string ident)
    {
        super(ident);
        members_ = new AVLTree!(Symbol);
    }

    ScopeSymbol opCatAssign(Symbol s)
    {
        members_.insert(s);
        s.parent_ = this;
        return this;
    }

    ScopeSymbol addImport(ScopeSymbol ss)
    {
        imports_ ~= ss;
        ss.parent_ = this;
        return this;
    }

    /**********************************************************************************************
        Look up a symbol using D's visibility rules.
    **********************************************************************************************/
    Symbol lookup(string ident)
    {
        scope sw = new StringWrap(ident);
        return lookup(sw);
    }

    /** ditto */
    // TODO: consider imports
    Symbol lookup(StringWrap sw)
    {
        Symbol sym;
        // direct members
        members_.find(sw, sym);
        if ( sym !is null )
            return sym;

        // imports
        foreach ( sc; imports_ )
        {
            sym = sc.lookup(sw);
            if ( sym !is null )
                return sym;
        }

        // parent scope
        if ( parent_ !is null )
            return parent_.lookup(sw);
        return null;
    }

    /**********************************************************************************************
        Find a symbol within this scope using a fully qualified name.
    **********************************************************************************************/
    Symbol findSymbol(string[] ident_list)
    {
        if ( ident_list.length == 0 )
            return null;
        Symbol s = this;
        scope StringWrap sw = new StringWrap(null);
        foreach ( id; ident_list )
        {
            if ( s is null )
                break;
            auto ss = cast(ScopeSymbol)s;
            if ( ss is null )
                break;
            sw.str_ = id;
            ss.members_.find(sw, s);
        }
        return s;
    }

    /**********************************************************************************************
        Find a symbol within this scope as a direct member.
    **********************************************************************************************/
    Symbol findSymbol(string id)
    {
        scope StringWrap sw = new StringWrap(id);
        Symbol s;
        members_.find(sw, s);
        return s;
    }

    int opApply(int delegate(ref Symbol s) dg)
    {
        return members_.opApply(dg);
    }

private:
    AVLTree!(Symbol)    members_;
    ScopeSymbol[]       imports_;
}

/**************************************************************************************************

**************************************************************************************************/
class Import : public Symbol
{
    string[]    package_idents_;

    this(string[] ident_list)
    {
        assert(ident_list.length > 0);
        super(ident_list[$-1]);
        package_idents_ = ident_list;
    }

    string moduleName()
    {
        string tmp;
        foreach ( pi; package_idents_ )
        {
            if ( tmp.length > 0 )
                tmp ~= ".";
            tmp ~= pi;
        }
        return tmp;
    }

    string toString()
    {
        return "import "~moduleName;
    }

    void mod(Module mod)
    {
        module_ = mod;
        parent_.addImport(mod);
    }

    Module mod()
    {
        return module_;
    }

private:
    Module      module_;
}

/**************************************************************************************************

**************************************************************************************************/
class Declaration : public Symbol
{
    this(Type type, string ident, Location loc, DeclDefNode decl_def_node)
    {
        super(ident, loc);
        type_ = type;
        decl_def_node_ = decl_def_node;
    }

    string getDDoc()
    {
        return decl_def_node_.getDDocString;
    }

    string toString()
    {
        return type_.toString~" "~identifier_;
    }

    Type        type_;
    DeclDefNode decl_def_node_;
}

/**************************************************************************************************

**************************************************************************************************/
class ScopeDeclaration : public ScopeSymbol
{
    this(Type type, string ident, Location loc, DeclDefNode decl_def_node)
    {
        super(ident, loc);
        type_ = type;
        decl_def_node_ = decl_def_node;
    }

    string getDDoc()
    {
        return decl_def_node_.getDDocString;
    }

    string toString()
    {
        return type_.toString~" "~identifier_;
    }

    Type        type_;
    DeclDefNode decl_def_node_;
}

/**************************************************************************************************

**************************************************************************************************/
class ClassDeclaration : public ScopeDeclaration
{
    this(string ident, Location loc, DeclDefNode decl_def_node)
    {
        super(new TypeClass(this), ident, loc, decl_def_node);
    }

    string toString()
    {
        return "class "~identifier_;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class InterfaceDeclaration : public ScopeDeclaration
{
    this(string ident, Location loc, DeclDefNode decl_def_node)
    {
        super(new TypeInterface(this), ident, loc, decl_def_node);
    }

    string toString()
    {
        return "interface "~identifier_;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class StructDeclaration : public ScopeDeclaration
{
    this(string ident, Location loc, DeclDefNode decl_def_node)
    {
        super(new TypeStruct(this), ident, loc, decl_def_node);
    }

    string toString()
    {
        return "struct "~identifier_;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class FunctionDeclaration : public Declaration
{
    this(Type type, string ident, Location loc, DeclDefNode decl_def_node)
    {
        super(type, ident, loc, decl_def_node);
    }

    string toString()
    {
        return type_.toString~" "~identifier_;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class Package : public ScopeSymbol
{
    FilePath    filepath_;

    this(string ident)
    {
        super(ident);
    }

    string toString()
    {
        auto str = "package "~identifier_;
        if ( filepath_ !is null )
            str ~= " "~filepath_.toString;
        return str;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class Module : public Package
{
    SyntaxTree  syntax_tree_;
    long        modified_time_;

    this(FilePath fp)
    {
        super(null);
        location_.mod = this;
        filepath_ = fp;
    }

    string toString()
    {
        auto str = "module "~identifier_;
        if ( filepath_ !is null )
            str ~= " "~filepath_.toString;
        return str;
    }
}
