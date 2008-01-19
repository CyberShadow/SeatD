/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module abstract_plugin;

import tango.io.File;
import tango.io.FileScan;
import tango.io.FilePath;
import tango.io.FileConst;

import tango.text.Ascii;
import tango.text.Util;
import tango.text.convert.Layout;

import util;
import seatd.module_data;
import seatd.package_data;
import container;

import tango.stdc.stdio;

alias char[] string;
alias dchar[] dstring;

/**************************************************************************************************
    Host independent editor plugin with basic code navigation functionality.
    Needs to be sublassed in order to implement host specific functions.
    The host specific wrapper should assume that any function that it calls from this class
    may throw Exceptions and handle them.
**************************************************************************************************/
abstract class AbstractPlugin
{
public:
    this()
    {
        root_package_ = new PackageData;
    }

    
    //=============================================================================================
    // Interface to the host, needs to be overridden in host specific subclass.

    /**********************************************************************************************
        Get a list of include paths that have been set by the user in some configuration facility.
    **********************************************************************************************/
    string[] getIncludePaths();

    /**********************************************************************************************
        Access the active file's content.
        Since it might have been modified by the host and not saved to disk, yet,
        we need to be read it directly form host memory.
    **********************************************************************************************/
    string getBufferText();

    /**********************************************************************************************
        Determine whether the current buffer is to be parsed.
        Usually done using the file extension or editor settings.
    **********************************************************************************************/
    bool isParsableBuffer();

    /**********************************************************************************************
        Read a fully qualified identifier from the current editor buffer at the cursor.
    **********************************************************************************************/
    string fqIdentAtCursor();
    
    /**********************************************************************************************
        Get the current position of the cursor.
    **********************************************************************************************/
    void getCursor(ref uint line, ref uint col);

    /**********************************************************************************************
        Set the cursor (and view) to the given position in the file
    **********************************************************************************************/
    void setCursor(uint line, uint col);

    /**********************************************************************************************
        Open the given source file in the editor.
    **********************************************************************************************/
    void openFile(string filepath);

    /**********************************************************************************************
        Output to a host logging facility, message box or similar.
    **********************************************************************************************/
    void log(string str);

    /**********************************************************************************************
        Display a small hint-class message for signatures, DDocs, simple messages like
        "identifier not found", or similar. Usually a small popup window.
    **********************************************************************************************/
    void callTip(string text);

    /**********************************************************************************************
        Display a selection list.
        Will be called repeatedly, while the user types and the list shrinks.
    **********************************************************************************************/
    void showSelectionList(string[] entries);



    //=============================================================================================
    // Interface to SEATD plugin functionality. Called by host specific subclass

    /**********************************************************************************************
        Set the filepath of the active buffer.
        This name is used together with the parsed module name to automatically determine include paths.
    **********************************************************************************************/
    void setActiveFilepath(string filename)
    {
        active_filepath_ = getFullPath(filename);
    }

    /***********************************************************************************************
        Called when the user types text. Used to shrink the selection lists.
        Uses control character 0x08 for backspace.

        Returns:    true if the character has been processed. Usually it shouldn't be processed
                    by other parts of the editor in that case.
    ***********************************************************************************************/
    bool onChar(dchar c)
    {
        if ( c == '.' || c == 8 || contains(FQN_CHARS, c) )
        {
            string[] prev_list;

            if ( c == 8 )
            {
                prev_list = full_list_;
                if ( live_search_str_.length > 0 )
                    live_search_str_ = live_search_str_[0..$-1];
                if ( live_search_str_.length == 0 ) {
                    current_list_ = prev_list;
                    showSelectionList(false);
                    return true;
                }
            }
            else
            {
                live_search_str_ ~= c;
                if ( current_list_ is null )
                    prev_list = full_list_;
                else
                    prev_list = current_list_;
            }

            current_list_ = null;
            foreach ( l; prev_list )
            {
                auto source = toUpper(l.dup);
                if ( locatePattern(source, live_search_str_) < source.length )
                    current_list_ ~= l;
            }

            showSelectionList(false);
            return true;
        }

        return false;
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    void listDeclarations()
    {
        auto modinfo = parseBuffer;

        if ( modinfo !is null )
        {
            list_decls_ = null;
            full_list_ = null;
            foreach ( Declaration decl; modinfo.decls )
            {
                string ident = decl.fqnIdent;
/+                 if ( decl.mangled_type !is null )
                    full_list ~= ident~"_"~decl.mangled_type;
                else
 +/                    full_list_ ~= ident;
                list_decls_[ident] = decl;
            }

            showSelectionList();
        }
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    void listModules()
    {
        auto modinfo = parseBuffer;

        list_modules_ = null;
        full_list_ = null;
        
        Stack!(PackageData) stack;
        stack ~= root_package_;
        while ( !stack.empty )
        {
            auto pak = stack.pop;
            foreach ( mod; pak.modules )
            {
                full_list_ ~= mod.fqname;
                list_modules_[mod.fqname] = mod;
            }
            foreach ( p; pak.packages )
                stack ~= p;
        }

        showSelectionList();
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    void gotoDeclarationAtCursor()
    {
        auto bufferinfo = parseBuffer(false);

        auto modinfo = bufferinfo;
        Declaration decl = root_package_.findDeclaration(fqIdentAtCursor, modinfo);
        if ( decl is null )
            callTip("symbol not found");
        else
        {
            if ( modinfo !is bufferinfo )
                gotoModule(modinfo);
            gotoDeclaration(decl);
        }
    }


    //=============================================================================================
    // internal helper functions

    /**********************************************************************************************
        Open the source file of the given module in the editor.
    **********************************************************************************************/
    void gotoModule(ModuleData modinfo)
    {
        if ( modinfo is null )
            return;

        string fname;
        if ( modinfo.filepath is null )
        {
            auto include_paths = bufferIncludePath(modinfo.fqname);
            fname = findModuleFile(include_paths, modinfo.fqname, &this.log);
            if ( fname is null ) {
                auto ipstr = join(include_paths, ",");
                Layout!(char) l;
                log(l.convert("Unable to find module {} in include path {}".dup, modinfo.fqname, ipstr));
                return;
            }
        }
        else
            fname = modinfo.filepath.toString;

        openFile(fname);
    }

    void gotoModule(string text)
    {
        auto mod = text in list_modules_;
        if ( mod !is null )
            gotoModule(*mod);
    }
    
    /**********************************************************************************************
        Move the cursor to the line of the given declaration.
        Assumes that the correct file is active.
    **********************************************************************************************/
    void gotoDeclaration(Declaration decl)
    {
        if ( decl is null )
            return;
        setCursor(decl.line-1, decl.column-1);
    }

    void gotoDeclaration(string text)
    {
        auto decl = text in list_decls_;
        if ( decl !is null )
            gotoDeclaration(*decl);
    }

    /**********************************************************************************************
        Tries to locate and parse all imports of the given module in the given include path.
        Parses only, if the module to be imported hasn't been already parsed.
    **********************************************************************************************/
    void parseImports(ModuleData modinfo, string[] include_paths)
    {
        if ( modinfo is null )
            return null;
        Layout!(char) l;

        foreach ( imp; modinfo.imports )
        {
            auto modinfo2 = root_package_.findModule(imp.module_name);
            if ( modinfo2 !is null )
                continue;

            auto fname = findModuleFile(include_paths, imp.module_name, &this.log);
            if ( fname is null ) {
                auto ipstr = join(include_paths, ",");
                log(l.convert("Unable to find module {} in include path {}".dup, imp.module_name, ipstr));
                root_package_ ~= new ModuleData(imp.module_name);
                continue;
            }

            try
            {
                modinfo2 = parse(fname, cast(string)(new File(fname)).read);
                if ( modinfo2 !is null ) {
                    root_package_ ~= modinfo2;
                    parseImports(modinfo2, include_paths);
                }
                else
                    log("parse error");
            }
            catch ( Exception e ) {
                log(e.msg);
            }
        }
    }

    /**********************************************************************************************
        Parses the active buffer and checks whether it's imports need to be parsed.
    **********************************************************************************************/
    ModuleData parseBuffer(bool warn_non_d_file=true)
    {
        string text = getBufferText();

        if ( !isParsableBuffer )
        {
            if ( warn_non_d_file )
                callTip("semantics only available in D source files");
            return null;
        }
        
        ModuleData modinfo;

        modinfo = parse(active_filepath_, text);
        if ( modinfo is null )
            log("parse error");
        else {
            root_package_ ~= modinfo;
            auto ip = bufferIncludePath(modinfo.fqname);
            parseImports(modinfo, ip);
        }

        return modinfo;
    }

    /**********************************************************************************************
        Parses all D source files found in the given include path.
    **********************************************************************************************/
    void parseIncludePath(string[] ips)
    {
        auto scan = new FileScan;
        FilePath[]  filepaths;
        foreach ( ip; ips ) {
            filepaths ~= scan.sweep(ip, ".d").files;
            filepaths ~= scan.sweep(ip, ".di").files;
        }
        
        foreach ( filepath; filepaths )
        {
            try
            {
                auto mod = parse(filepath.toString, cast(string)(new File(filepath)).read);
                if ( mod !is null )
                    root_package_ ~= mod;
            }
            catch ( Exception e ) {
                log(filepath.toString~": "~e.msg);
            }
        }
    }

    /**********************************************************************************************
        Determine the include path for the active buffer.
    **********************************************************************************************/
    string[] bufferIncludePath(string module_name)
    {
        auto ip = active_filepath_ in buffer_include_paths_;
        if ( ip !is null )
            return *ip;

        auto paths = getIncludePaths();
        paths ~= determineIncludePath(active_filepath_, module_name);

        foreach ( ref p; paths )
        {
            if ( p.length <= 0 )
                continue;
            if ( contains("/\\", p[$-1]) )
                p ~= FileConst.PathSeparatorChar;
        }

//        parseIncludePath(paths);
        
        buffer_include_paths_[active_filepath_] = paths;
        return paths;
    }

    /**********************************************************************************************

    **********************************************************************************************/
    void showSelectionList(bool init=true)
    {
        if ( init ) {
            full_list_.sort;
            current_list_ = full_list_;
            live_search_str_ = null;
        }

        showSelectionList(current_list_);
    }



    const dstring FQN_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"d;

protected:
    string              active_filepath_;
    string[][string]    buffer_include_paths_;

    Declaration[string] list_decls_;
    ModuleData[string]  list_modules_;
    string              live_search_str_;
    string[]            full_list_,
                        current_list_;

    PackageData     root_package_;
}
