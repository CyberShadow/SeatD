/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module seatd.symbol;

import tango.io.Stdout;
import tango.io.FilePath;
import tango.text.convert.Integer;
import tango.text.Util;

public import seatd.common;
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

    int opCmp(Location loc)
    {
        if ( line == loc.line )
            return column - loc.column;
        return line - loc.line;
    }

    string toString()
    {
        if ( mod is null )
            return "unknown module("~.toString(line)~":"~.toString(column)~")";
        return mod.toString~"("~.toString(line)~":"~.toString(column)~")";
    }
}

class LocationTree
{
    alias AVLTree!(Symbol,"a.location_ < b.location_").AVLTree loctree_t;

    struct ModuleLocation
    {
        Module      mod;
        loctree_t   loctree;
    }

    alias AVLTree!(
        ModuleLocation,
        "a.mod is null ? true : ( b.mod is null ? false : (a.mod.fqnString < b.mod.fqnString) )"
    ).AVLTree modtree_t;

    this()
    {
        modtree_ = new modtree_t;
    }

    bool insert(Module m, Symbol s)
    {
        return insert(m).insert(s);
    }

    loctree_t insert(Module m)
    {
        ModuleLocation ml;
        ml.mod = m;
        if ( !modtree_.find(ml, ml) ) {
            ml.mod = m;
            ml.loctree = new loctree_t;
            modtree_ ~= ml;
        }
        return ml.loctree;
    }

    Symbol find(Location loc)
    {
        if ( loc.mod is null )
            return null;
        ModuleLocation ml;
        ml.mod = loc.mod;
        if ( !modtree_.find(ml, ml) )
            return null;
        Stdout.formatln("found {}", ml.mod.toString);
        Symbol  sym = new Symbol(null, loc),
                sym2;
        ml.loctree.findLE(sym, sym2);
        Stdout("finished search").newline;
        return sym2;
    }

    modtree_t modtree_;
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
    string          fqn_string_;
    string[]        fqn_;

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
        if ( fqn_string_.length <= 0 )
        {
            auto a = fqn();
            if ( a.length <= 0 )
                return null;
            fqn_string_ ~= a[0];
            foreach ( i; a[1..$] )
                fqn_string_ ~= "."~i;
        }
        return fqn_string_;
    }

    /**********************************************************************************************
        Returns the fully qualified identifier of this declaration.
    **********************************************************************************************/
    string[] fqn()
    {
        if ( fqn_.length <= 0 )
        {
            for ( auto s = this; s !is null; s = s.parent_ )
                fqn_ ~= s.identifier_;
            fqn_.reverse;
        }
        return fqn_;
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
        members_ = new typeof(members_);
    }

    protected this(string ident)
    {
        super(ident);
        members_ = new typeof(members_);
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

    /**********************************************************************************************

    **********************************************************************************************/
    int opApply(int delegate(ref Symbol s) dg)
    {
        return members_.opApply(dg);
    }

    /**********************************************************************************************

    **********************************************************************************************/
    LocationTree buildLocationTree()
    {
        auto t = new LocationTree;
        t.loctree_t loctree;
        Stack!(ScopeSymbol) stack;
        stack ~= this;
        while ( !stack.empty )
        {
            auto sc = stack.pop;
            auto mod = cast(Module)sc;
            if ( mod !is null )
                loctree = t.insert(mod);
            else if ( cast(Package)sc is null ) {
                assert(loctree !is null);
                loctree ~= sc;
            }

            foreach ( m; sc )
            {
                auto sc2 = cast(ScopeSymbol)m;
                if ( sc2 !is null )
                    stack ~= sc2;
                else {
                    assert(loctree !is null);
                    loctree ~= m;
                }
            }
        }
        return t;
    }

private:
    AVLTree!(Symbol).AVLTree    members_;
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
        if ( type_ is null )
            return "<unresolved type> "~identifier_;
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
struct BaseDeclaration
{
    string[]    id_list;
    Protection  prot;
}

class ClassDeclaration : public ScopeDeclaration
{
    BaseDeclaration[]       base_decls_;
    ClassDeclaration        base_class_decl_;
    InterfaceDeclaration[]  iface_decls_;

    this(string ident, BaseDeclaration[] base_list, Location loc, DeclDefNode decl_def_node)
    {
        super(new TypeClass(this), ident, loc, decl_def_node);
        base_decls_ = base_list;
    }

    string toString()
    {
        return "class "~identifier_;
    }

    void resolveBaseDecls(Package root_package)
    {
        foreach ( base; base_decls_ )
        {
            if ( base.id_list.length <= 0 ) {
                Stdout.formatln("empty BaseDecl in {}", toString);
                continue;
            }
            Symbol sym;
            if ( base.id_list.length > 1 )
                sym = root_package.findSymbol(base.id_list);
            else
                sym = lookup(base.id_list[0]);

            if ( sym !is null )
            {
                Type t;
                auto cdecl = cast(ClassDeclaration)sym;
                auto idecl = cast(InterfaceDeclaration)sym;
                if ( cdecl is null && idecl is null ) {
                    Stdout.formatln("{}: BaseDecl {} is not a class or interface", location_.toString, sym.toString);
                    continue;
                }

                if ( cdecl !is null )
                {
                    if ( base_class_decl_ !is null ) {
                        Stdout.formatln("{}: Multiple base classes specified: {} and {}", location_.toString);
                        continue;
                    }
                    base_class_decl_ = cdecl;
                }
                else
                    iface_decls_ ~= idecl;
            }
        }
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
        auto str = fqnString;
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
        auto str = fqnString;
        if ( filepath_ !is null )
            str ~= " "~filepath_.toString;
        return str;
    }
}
