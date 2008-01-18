/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module util;

import tango.text.Util;
import tango.io.FilePath;
import tango.io.FileConst;

version(Windows) import win32.winbase;

import seatd.module_data;
import seatd.package_data;
static import seatd.parser;

/**************************************************************************************************
    Determine absolute path from given path.
**************************************************************************************************/
string getFullPath(string filename)
{
    version(Windows) {
        char[]	fullpath;
        char*	filepart;
        fullpath.length = 4096;
        int len = GetFullPathName(
            (filename~\0).ptr,
            fullpath.length,
            fullpath.ptr,
            &filepart
        );
        if ( len <= 0 )
            return null;
        fullpath.length = len;

        char[]	longfullpath;
        longfullpath.length = 4096;
        len = GetLongPathName(
            (fullpath~\0).ptr,
            longfullpath.ptr,
            longfullpath.length
        );
        longfullpath.length = len;
        return longfullpath;
    }
    else {
        return filename;
    }
}

/**************************************************************************************************
    Search incldue path for D source file for the given module_name.
**************************************************************************************************/
string findModuleFile(string[] include_paths, string module_name, void delegate(string) trace=null)
{
    auto elms = split(module_name, ".");
    if ( elms.length == 0 )
        return null;

    FilePath[] potential_paths;
    foreach ( ip; include_paths )
        potential_paths ~= new FilePath(ip);
    foreach ( i, elm; elms )
    {
        auto tmp_paths = potential_paths;
        potential_paths = null;
        foreach ( path; tmp_paths )
        {
            if ( i < elms.length-1 )
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
                return getFullPath(fp.cString);
            }
        }
    }

    return null;
}

/**************************************************************************************************
    Determine include path from a filepath and a module name.
**************************************************************************************************/
string[] determineIncludePath(string filepath_str, string module_name)
{
    string[]    include_path,
                elms = split(module_name, ".");

    auto filepath = new FilePath(filepath_str);
    if ( filepath.parent.length > 0 ) {
        include_path ~= filepath.parent;
        filepath = new FilePath(filepath.parent);
    }

    if ( elms.length > 1 )
    {
        foreach_reverse ( elm; elms[0 .. $-1] )
        {
            if ( elm == filepath.name ) {
                include_path ~= filepath.parent;
                filepath = new FilePath(filepath.parent);
            }
            else
                break;
        }
    }
    
    return include_path;
}

/**********************************************************************************************
    Parse a D source file.
    Params: input       = D source to parse
            filepath    = path of the file for identification
                        and modification time determination
**********************************************************************************************/
ModuleData parse(string filepath_str, string input, bool detailed=false, bool recover=true, uint tab_width=4)
{
    seatd.parser.SyntaxTree* root;
    ModuleData modinfo;

    if ( input is null )
        return null;
    if ( input[0 .. 4] == "Ddoc" )
        return null;
        
    // TODO: GC appears to free constant initializer data
//    std.gc.disable;
    bool success = seatd.parser.parse(filepath_str, input, root, detailed, recover, tab_width);
//    std.gc.enable;

    if ( !success )
        return null;

    long ctime, atime, mtime;
    string path, filename;
    auto filepath = new FilePath(filepath_str);
    if ( filepath.exists )
    {
//        getTimes(filepath, ctime, atime, mtime);
        path = getFullPath(filepath_str);
        filepath = new FilePath(path);
        filename = filepath.name;
    }
/+  else
        mtime = std.date.getUTCtime;
 +/
    modinfo = new ModuleData(path, filename, mtime);
    bool has_module_decl;
    root.Module(modinfo, has_module_decl);
    if ( !has_module_decl )
    {
        auto dot_pos = locatePrior(filename, '.');
        if ( dot_pos < 0 )
            dot_pos = filename.length;
        auto decl = new Declaration(null, Declaration.Type.dtModule, 0, filename[0 .. dot_pos], 1, 1);
        modinfo.decls.insert(decl);
    }

    if ( modinfo.fqname is null )
    {
        auto pos = locatePrior(filename, '.');
        modinfo.fqname = filename[0 .. pos];
    }
    
    return modinfo;
}
