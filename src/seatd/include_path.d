/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module seatd.include_path;

import tango.text.Util;
import tango.text.convert.Layout;
import tango.io.File;
import tango.io.FilePath;
import tango.io.Stdout;

import common;
import util;
import seatd.symbol;

class IncludePath
{
    FilePath[]  paths_;

    this()
    {
    }

    this(string[] paths)
    {
        foreach ( p; paths )
            paths_ ~= new FilePath(p);
    }

    void clear()
    {
        paths_.length = 0;
    }

    /**************************************************************************************************

    **************************************************************************************************/
    IncludePath opCatAssign(string[] paths)
    {
        foreach ( p; paths )
            paths_ ~= new FilePath(p);
        return this;
    }

    /**************************************************************************************************
        Search include path for D source file for the given module_name.
    **************************************************************************************************/
    FilePath findModuleFile(string module_name)
    {
        auto ident_list = split(module_name, ".");
        if ( ident_list.length == 0 )
            return null;
        return findModuleFile(ident_list);
    }

    FilePath findModuleFile(string[] ident_list)
    {
        auto potential_paths = paths_;
        foreach ( i, elm; ident_list )
        {
            auto tmp_paths = potential_paths;
            potential_paths = null;
            foreach ( path; tmp_paths )
            {
                if ( i < ident_list.length-1 )
                {
                    auto fp = new FilePath(path.toString);
                    fp = fp.append(elm);
                    if ( fp.exists )
                        potential_paths ~= fp;
                }
                else
                {
                    auto fp = new FilePath(path.toString);
                    fp.append(elm);
                    fp.suffix("d");
                    if ( !fp.exists )
                    {
                        fp.suffix("di");
                        if ( !fp.exists )
                            continue;
                    }
                    return fp;
                }
            }
        }

        return null;
    }

    /**************************************************************************************************
        Determine include path from a filepath and a module name.
    **************************************************************************************************/
    IncludePath extract(FilePath filepath, string[] module_name)
    {
        if ( filepath.parent.length > 0 )
        {
            filepath = new FilePath(filepath.parent);
            foreach ( p; paths_ )
            {
                if ( p == filepath )
                    goto Lhave;
            }
            paths_ ~= filepath;
        Lhave:;
        }

        if ( module_name.length > 1 )
        {
            Louter: foreach_reverse ( elm; module_name[0 .. $-1] )
            {
                if ( elm == filepath.name )
                {
                    filepath = new FilePath(filepath.parent);
                    foreach ( p; paths_ )
                    {
                        if ( p == filepath )
                            continue Louter;
                    }
                    paths_ ~= filepath;
                }
                else
                    break;
            }
        }

        return this;
    }

    /**********************************************************************************************
        Parse all imports of given module and update symbol table (default semantic pass).
        Returns:    SyntaxTrees of parsed imports indexed by Import objects.
    **********************************************************************************************/
    Import[] parseImports(
        Package root_package, Module mod,
        bool extract_ips, bool detailed=false, bool recover=true, uint tab_width=4 )
    {
        Import[] imps;
        auto l = new Layout!(char);

        foreach ( sym; mod )
        {
            auto imp = cast(Import)sym;
            if ( imp is null )
                continue;
            auto fp = findModuleFile(imp.package_idents_);
            if ( fp is null ) {
                // TODO: error logging facility for non-fatal errorss
                Stdout.formatln("Couldn't find source file for {}", imp.toString);
                continue;
            }
            // check whether module has already been parsed
            auto mod = root_package.findSymbol(imp.package_idents_);
            // if so, check timestamp
            if ( mod !is null )
            {
                // TODO: do it
                continue;
            }

            if ( extract_ips )
                extract(fp, imp.package_idents_);
            imp.mod = new Module(fp);
            imp.mod.syntax_tree_ = parse(fp, cast(string)(new File(fp)).read, detailed, recover, tab_width);
            imp.mod.syntax_tree_.seatdModule(root_package, imp.mod);

            parseImports(root_package, imp.mod, extract_ips, detailed, recover, tab_width);

            imps ~= imp;
        }
        return imps;
    }
}
