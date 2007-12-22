/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module seatd.package_data;

import tango.text.Util;

import seatd.module_data;
import container;


/**************************************************************************************************
    A package node for the package/module hierarchy.
**************************************************************************************************/
class PackageData
{
    string              fqname;
    ModuleData[string]  modules;
    PackageData[string] packages;
    
    this(string fqn=null)
    {
        fqname = fqn;
    }
    
    /**********************************************************************************************
        Find a module in the tree by it's fqname.
    **********************************************************************************************/
    ModuleData findModule(string module_name)
    {
        auto module_name_elms = split(module_name, ".");
        auto pak = this;
        foreach ( i, elm; module_name_elms )
        {
            if ( i < module_name_elms.length-1 )
            {
                auto p = elm in pak.packages; 
                if ( p is null )
                    return null;
                else
                    pak = *p;
            }
            else
            {
                auto m = elm in pak.modules;
                if ( m is null )
                    return null;
                return *m;
            }
        }
        assert(0);
    }
    
    /**********************************************************************************************
        Find module that contains a fq identifier.
    **********************************************************************************************/
    ModuleData findContainingModule(string fqname)
    {
        auto fqname_elms = split(fqname, ".");
        auto pak = this;
        foreach ( elm; fqname_elms )
        {
            auto p = elm in pak.packages; 
            if ( p is null )
            {
                auto m = elm in pak.modules;
                if ( m is null )
                    return null;
                return *m;
            }
            else
                pak = *p;
        }
        return null;
    }

    /**********************************************************************************************
        Insert a module into the tree.
    **********************************************************************************************/
    void opCatAssign(ModuleData mod)
    {
        auto elements = split(mod.fqname, ".");
        auto pak = this;
        foreach ( i, elm; elements )
        {
            if ( i < elements.length-1 )
            {
                auto p = elm in pak.packages; 
                if ( p is null ) {
                    auto tmp = new PackageData(pak.fqname~"."~elm);
                    pak.packages[elm] = tmp;
                    pak = tmp;
                }
                else
                    pak = *p;
            }
            else
            {
                // TODO: overwrite optional?
                pak.modules[elm] = mod;
            }
        }
    }

    /**************************************************************************************************
        Find a declaration within the package/module hierarchy, considering the scope of the
        reference for visibility determination.

        Params: ident               = identifier to find (fq or not)
                scope_mod           = module the containing the reference
                scope_decl          = declaration containing the reference
                no_imports          = used internally, keep default
    **************************************************************************************************/
    Declaration findDeclaration(
        string ident, ref ModuleData scope_mod, Declaration scope_decl=null, bool no_imports=false
    )
    {
        assert(ident !is null);

        if ( ident[0] == '.' )
            scope_decl = null;
        else
        {
            if ( locate(ident, '.') > 0 )
            {
                auto mod = findContainingModule(ident);
                if ( mod !is null ) {
                    scope_mod = mod;
                    no_imports = true;
                }
            }
        }
        
        if ( scope_decl !is null )
        {
            Declaration current_scope = scope_decl;
            while ( current_scope !is null )
            {
                foreach ( decl; current_scope.children )
                {
                    if ( ident == decl.ident )
                        return decl;
                }
                current_scope = current_scope.parent;
            }
        }
        else
        {
            // TODO: search partial declaration if fqident
            // TODO: only use top-level declarations here, when scope search works
            Declaration proto, result;
            proto = new Declaration(ident);
            if ( scope_mod is null )
            {
                Stack!(PackageData) stack;
                stack ~= this;
                while ( !stack.empty )
                {
                    auto pak = stack.pop;
                    foreach ( mod; pak.modules )
                    {
                        if ( mod.decls.find(proto, result) )
                        {
                            scope_mod = mod;
                            return result;
                        }
                    }
                    stack ~= pak.packages.values;
                }
            }
            else if ( scope_mod.decls.find(proto, result) )
                return result;
        }

        if ( no_imports )
            return null;
        if ( scope_mod is null )
            return null;

        ModuleData[string]  import_infos;
        auto worklist = scope_mod.imports.dup;
        for ( size_t i = 0; i < worklist.length; ++i )
        {
            auto imp = worklist[i];
            if ( (imp.module_name in import_infos) !is null )
                continue;
            auto impinfo = findModule(imp.module_name);
            if ( impinfo is null )
                continue;
            import_infos[imp.module_name] = impinfo;
            foreach ( imp2; impinfo.imports )
            {
                if ( imp2.isPublic )
                    worklist ~= imp2;
            }
        }
        
        foreach ( impinfo; import_infos )
        {
            auto decl = findDeclaration(ident, impinfo, null, true);
            if ( decl !is null ) {
                scope_mod = impinfo;
                return decl;
            }
        }

        return null;
    }
}
