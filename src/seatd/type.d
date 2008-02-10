/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module seatd.type;

import tango.io.Stdout;

import seatd.symbol;
import common;
import container;

/**************************************************************************************************

**************************************************************************************************/
enum TY
{
    Tnone = 0,
    Tvoid,
    Tint8,
    Tuint8,
    Tint16,
    Tuint16,
    Tint32,
    Tuint32,
    Tint64,
    Tuint64,
    Tfloat32,
    Tfloat64,
    Tfloat80,
    Tfloat128,

    Timaginary32,
    Timaginary64,
    Timaginary80,
    Timaginary128,

    Tcomplex32,
    Tcomplex64,
    Tcomplex80,
    Tcomplex128,

    Tbit,
    Tbool,
    Tchar,
    Twchar,
    Tdchar,

    Terror,
    Tinstance,
    Ttypeof,
    Ttuple,
    Tslice,

    Tdynamic_array,
    Tstatic_array,
    Tassoc_array,
    Tpointer,
    Treference,
    Tfunction,
    Tident,
    Tclass,
    Tstruct,
    Tenum,
    Ttypedef,
    Tdelegate,
}

string[] TYnames =
[
    "none",
    "void",
    "int8",
    "uint8",
    "int16",
    "uint16",
    "int32",
    "uint32",
    "int64",
    "uint64",
    "float32",
    "float64",
    "float80",
    "float128",

    "imaginary32",
    "imaginary64",
    "imaginary80",
    "imaginary128",

    "complex32",
    "complex64",
    "complex80",
    "complex128",

    "bit",
    "bool",
    "char",
    "wchar",
    "dchar",

    "error",
    "instance",
    "typeof",
    "tuple",
    "slice",

    "[]",
    "static_array",
    "assoc_array",
    "*",
    "reference",
    "function",
    "ident",
    "class",
    "struct",
    "enum",
    "typedef",
    "delegate"
];

/**************************************************************************************************

**************************************************************************************************/
class Type
{
public:
    static Type[] basic_types_;

    static this()
    {
        basic_types_.length = TY.Terror;
        for ( TY t = TY.Tnone; t < TY.Terror; ++t )
            basic_types_[t] = new Type(t);
    }

    static Type opCall(TY t)
    {
        if ( t < basic_types_.length )
            return basic_types_[t];
        return new Type(t);
    }

    static Type opCall(TY t, Type next)
    {
        assert(t > TY.Terror);
        return new Type(t, next);
    }

    string toString()
    {
        string str;
        switch ( ty_ )
        {
            case TY.Tident:
                auto ti = cast(TypeIdentifier)this;
                assert(ti !is null);
                str = ti.toString;
                break;
            default:
                str = TYnames[ty_];
        }
        if ( next_ !is null )
            str = next_.toString ~ str;
        return str;
    }

protected:
    this(TY t)
    {
        ty_ = t;
    }

    this(TY t, Type next)
    {
        ty_ = t;
        next_ = next;
    }

    TY      ty_;
    Type    next_;
}

/**************************************************************************************************

**************************************************************************************************/
class TypeIdentifier : public Type
{
    string[] ident_list_;

    this(string[] idents)
    {
        assert(idents.length > 0);
        super(TY.Tident);
        ident_list_ = idents;
    }

    this(string ident)
    {
        assert(ident !is null);
        super(TY.Tident);
        ident_list_ ~= ident;
    }

    Type resolve(Package root_package, ScopeSymbol sc)
    {
        if ( ident_list_.length <= 0 ) {
            Stdout.formatln("empty TypeIdentifier in {}", sc);
            return null;
        }
        Symbol sym;
        if ( ident_list_.length > 1 )
            sym = root_package.findSymbol(ident_list_);
        else
            sym = sc.lookup(ident_list_[0]);

        if ( sym !is null )
        {
            Type t;
            auto decl = cast(Declaration)sym;
            if ( decl !is null )
                t = decl.type_;
            else
            {
                auto scdecl = cast(ScopeDeclaration)sym;
                if ( scdecl !is null )
                    t = scdecl.type_;
            }

            if ( t !is null )
                return t;
        }
        return null;
    }

    string toString()
    {
        if ( ident_list_.length <= 0 )
            return null;
        Chordc chrd;
        chrd ~= ident_list_[0];
        foreach ( id; ident_list_[1 .. $] ) {
            chrd ~= ".";
            chrd ~= id;
        }
        return chrd.toString;
    }
}

/**************************************************************************************************

**************************************************************************************************/
void resolveTypeIdentifers(Package root_package)
{
    Stack!(ScopeSymbol) stack;
    stack ~= root_package;
    while ( !stack.empty )
    {
        auto sc = stack.pop;
        foreach ( s; sc )
        {
            auto sc2 = cast(ScopeSymbol)s;
            if ( sc2 !is null )
                stack ~= sc2;
            else
            {
                TypeIdentifier ti;
                auto decl = cast(Declaration)s;
                if ( decl !is null )
                    ti = cast(TypeIdentifier)decl.type_;
                else
                {
                    auto scdecl = cast(ScopeDeclaration)s;
                    if ( scdecl !is null )
                        ti = cast(TypeIdentifier)scdecl.type_;
                }
                if ( ti !is null )
                {
                    auto t = ti.resolve(root_package, sc);
                    if ( t is null )
                    {
                        Stdout.formatln(
                            "{}: undefined identifier {} is used as a type for {}",
                            s.location_.toString, ti, s.identifier_
                        );
                    }
                }
            }
        }
    }
}

/**************************************************************************************************

**************************************************************************************************/
class TypeAssocArray : public Type
{
    this(Type key_type, Type value_type)
    {
        super(TY.Tassoc_array, value_type);
        key_type_ = key_type;
        value_type_ = value_type;
    }

    string toString()
    {
        Chordc tstr;
        tstr ~= value_type_.toString;
        tstr ~= "[";
        tstr ~= key_type_.toString;
        tstr ~= "]";
        return tstr.toString;
    }

    Type    key_type_,
            value_type_;
}

/**************************************************************************************************

**************************************************************************************************/
class TypeFunction : public Type
{
    this(Type return_type, Type[] parameters)
    {
        super(TY.Tfunction, return_type);
        return_type_ = return_type;
        parameters_ = parameters;
    }

    string toString()
    {
        Chordc tstr;
        tstr ~= return_type_.toString;
        tstr ~= " function(";
        foreach ( i, p; parameters_ )
        {
            if ( i > 0 )
                tstr ~= ", ";
            tstr ~= p.toString;
        }
        tstr ~= ")";
        return tstr.toString;
    }

    Type[]  parameters_;
    Type    return_type_;
}

/**************************************************************************************************

**************************************************************************************************/
class TypeDelegate : public Type
{
    this(Type return_type, Type[] parameters)
    {
        super(TY.Tdelegate, return_type);
        return_type_ = return_type;
        parameters_ = parameters;
    }

    string toString()
    {
        Chordc tstr;
        tstr ~= return_type_.toString;
        tstr ~= " delegate(";
        foreach ( i, p; parameters_ )
        {
            if ( i > 0 )
                tstr ~= ", ";
            tstr ~= p.toString;
        }
        tstr ~= ")";
        return tstr.toString;
    }

    Type[]  parameters_;
    Type    return_type_;
}

/**************************************************************************************************

**************************************************************************************************/
class TypeClass : public Type
{
    ClassDeclaration decl_;

    this(ClassDeclaration decl)
    {
        super(TY.Tclass);
    }

    string toString()
    {
        return decl_.toString;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class TypeStruct : public Type
{
    StructDeclaration decl_;

    this(StructDeclaration decl)
    {
        super(TY.Tstruct);
    }

    string toString()
    {
        return decl_.toString;
    }
}

/**************************************************************************************************

**************************************************************************************************/
class TypeInterface : public Type
{
    InterfaceDeclaration decl_;

    this(InterfaceDeclaration decl)
    {
        super(TY.Tclass);
    }

    string toString()
    {
        return decl_.toString;
    }
}
