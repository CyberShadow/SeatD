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
        root_package = new PackageData;
    }

    
    //=============================================================================================
    // Interface to the host, needs to be overridden in host specific subclass.

    /**********************************************************************************************
        Access key-value pair from the configuration
    **********************************************************************************************/
    string configProperty(string name);

    /**********************************************************************************************
        Read a fully qualified identifier from the current editor buffer at the cursor.
    **********************************************************************************************/
    string fqIdentAtCursor();
    
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
        Open the given source file in the editor.
    **********************************************************************************************/
    void openFile(string filepath);

    /**********************************************************************************************
        Set the cursor (and view) to the given position in the file
    **********************************************************************************************/
    void setCursor(uint line, uint col);

    /**********************************************************************************************
        Get the current position of the cursor.
    **********************************************************************************************/
    void getCursor(ref uint line, ref uint col);

    /**********************************************************************************************
        Access the current buffer's text data.
    **********************************************************************************************/
    string getBufferText();

    /**********************************************************************************************
        Determine whether the current buffer is to be parsed.
        Usually done using the file extension or editor settings.
    **********************************************************************************************/
    bool isParsableBuffer();

    /**********************************************************************************************
        Display a selection list.
        Will be called repeatedly, while the user types and the list shrinks.
    **********************************************************************************************/
    void showSelectionList(string[] entries);



    //=============================================================================================
    // Interface to SEATD plugin functionality. Called by host specific subclass

    /**********************************************************************************************
        Set the buffer with the given index to be the active buffer.
        Indeces are arbitrary integers. They don't need to be continuous.
        Buffers don't need to be created explicitly.
    **********************************************************************************************/
    void setBuffer(int index)
    {
        active_buffer = index;
    }

    /**********************************************************************************************
        Get the index of the currently active buffer.
    **********************************************************************************************/
    int getBuffer()
    {
        return active_buffer;
    }

    /**********************************************************************************************
        Called if the currently active editor buffer is closed.
    **********************************************************************************************/
    void clearBuffer()
    {
        buffer_file_names.remove(active_buffer);
    }

    /**********************************************************************************************
        Called when loading a file into the current buffer.
    **********************************************************************************************/
    void setBufferFile(string filename)
    {
        buffer_file_names[active_buffer] = getFullPath(filename);
    }

    /**********************************************************************************************
        Called when the user selected an item from the currently active selection list.
        The list is assumed to be hidden/closed when this event occurs.
    **********************************************************************************************/
    void onSelection(int index, string text)
    {
        if ( text.length <= 0 )
        {
            if ( index >= current_list.length ) {
                select_list_type = SelectionListT.none;
                return;
            }
            text = current_list[index];
        }
        if ( select_list_type == SelectionListT.goto_declaration )
        {
            auto decl = text in list_decls;
            if ( decl !is null )
                gotoDecl(*decl);
        }
        else if ( select_list_type == SelectionListT.goto_module )
        {
            auto mod = text in list_modules;
            if ( mod !is null )
                gotoModule(*mod);
        }
        select_list_type = SelectionListT.none;
    }

    /***********************************************************************************************
        Called when the user types text. Used to shrink the selection lists.
        Uses control character 0x08 for backspace.

        Returns:    true if the character has been processed. Usually it shouldn't be processed
                    by other parts of the editor in that case.
    ***********************************************************************************************/
    bool onChar(dchar c)
    {
        if ( select_list_type == SelectionListT.none )
            return false;

        if ( c == '.' || c == 8 || contains(FQN_CHARS, c) )
        {
            string[] prev_list;

            if ( c == 8 )
            {
                prev_list = full_list;
                if ( live_search_str.length > 0 )
                    live_search_str = live_search_str[0..$-1];
                if ( live_search_str.length == 0 ) {
                    current_list = prev_list;
                    showSelectionList(false);
                    return true;
                }
            }
            else
            {
                live_search_str ~= c;
                if ( current_list is null )
                    prev_list = full_list;
                else
                    prev_list = current_list;
            }

            current_list = null;
            foreach ( l; prev_list )
            {
                auto source = toUpper(l.dup);
                if ( locatePattern(source, live_search_str) < source.length )
                    current_list ~= l;
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
        if ( select_list_type != SelectionListT.none )
            return;
        auto modinfo = parseBuffer;

        if ( modinfo !is null )
        {
            list_decls = null;
            full_list = null;
            foreach ( Declaration decl; modinfo.decls )
            {
                string ident = decl.fqnIdent;
/+                 if ( decl.mangled_type !is null )
                    full_list ~= ident~"_"~decl.mangled_type;
                else
 +/                    full_list ~= ident;
                list_decls[ident] = decl;
            }

            showSelectionList();
            select_list_type = SelectionListT.goto_declaration;
        }
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    void listModules()
    {
        if ( select_list_type != SelectionListT.none )
            return;
        auto modinfo = parseBuffer;

        list_modules = null;
        full_list = null;
        
        Stack!(PackageData) stack;
        stack ~= root_package;
        while ( !stack.empty )
        {
            auto pak = stack.pop;
            foreach ( mod; pak.modules )
            {
                full_list ~= mod.fqname;
                list_modules[mod.fqname] = mod;
            }
            foreach ( p; pak.packages )
                stack ~= p;
        }

        showSelectionList();
        select_list_type = SelectionListT.goto_module;
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    void gotoDeclaration()
    {
        if ( select_list_type != SelectionListT.none )
            return;
        auto bufferinfo = parseBuffer(false);

        auto modinfo = bufferinfo;
        Declaration decl = root_package.findDeclaration(fqIdentAtCursor, modinfo);
        if ( decl is null )
            callTip("symbol not found");
        else
        {
            if ( modinfo !is bufferinfo )
                gotoModule(modinfo);
            gotoDecl(decl);
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

        string path;
        foreach ( c; modinfo.path )
        {
            if ( c == '\\' )
                path ~= '/';
            else
                path ~= c;
        }
        openFile(path);
    }
    
    /**********************************************************************************************
        Move the cursor to the line of the given declaration.
        Assumes that the correct file is active.
    **********************************************************************************************/
    void gotoDecl(Declaration decl)
    {
        if ( decl is null )
            return;
        setCursor(decl.line-1, decl.column-1);
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
            auto modinfo2 = root_package.findModule(imp.module_name);
            if ( modinfo2 !is null )
                continue;

            auto fname = findModuleFile(include_paths, imp.module_name, &this.log);
            if ( fname is null ) {
                log(l.convert("Unable to find module {} in include path".dup, imp.module_name));
                root_package ~= new ModuleData(imp.module_name);
                continue;
            }

            try
            {
                modinfo2 = parse(fname, cast(string)(new File(fname)).read);
                if ( modinfo2 !is null ) {
                    root_package ~= modinfo2;
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

        string* filename = active_buffer in buffer_file_names;
        string  empty = "";
        if ( filename is null )
            filename = &empty;

        if ( !isParsableBuffer )
        {
            if ( warn_non_d_file )
                callTip("semantics only available in D source files");
            return null;
        }
        
        ModuleData modinfo;

        modinfo = parse(*filename, text);
        if ( modinfo is null )
            log("parse error");
        else {
            root_package ~= modinfo;
            auto ip = bufferIncludePath(*filename, modinfo.fqname);
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
                    root_package ~= mod;
            }
            catch ( Exception e ) {
                log(filepath.toString~": "~e.msg);
            }
        }
    }

    /**********************************************************************************************
        Determine the include path for the active buffer.
    **********************************************************************************************/
    string[] bufferIncludePath(string filepath, string module_name)
    {
        auto ip = active_buffer in buffer_include_paths;
        if ( ip !is null )
            return *ip;

        auto    global_ip = configProperty("seatd.global.include"),
                local_ip = configProperty("seatd.local.include"),
                dir_home = configProperty("SciteDirectoryHome");

        if ( dir_home.length > 0 && contains("/\\", dir_home[$-1]) )
            dir_home ~= FileConst.PathSeparatorChar;

        auto paths = split(local_ip, ";");
        if ( paths.length == 0 )
            paths = determineIncludePath(filepath, module_name);
        paths ~= split(global_ip, ";");
        
        foreach ( ref p; paths )
        {
            if ( p.length <= 0 )
                continue;
            if ( contains("/\\", p[$-1]) )
                p ~= FileConst.PathSeparatorChar;
            if ( contains("/\\", p[0]) && (p.length < 2 || p[1] != ':') )
                p = dir_home~p;
        }

//        parseIncludePath(paths);
        
        buffer_include_paths[active_buffer] = paths;
        return paths;
    }

    /**********************************************************************************************

    **********************************************************************************************/
    void showSelectionList(bool init=true)
    {
        if ( init ) {
            full_list.sort;
            current_list = full_list;
            live_search_str = null;
        }

        showSelectionList(current_list);
    }



    enum SelectionListT {
        none,
        goto_declaration,
        goto_module
    }

    const dstring FQN_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"d;

protected:
    string[int]     buffer_file_names;
    string[][int]   buffer_include_paths;
    int             active_buffer;

    SelectionListT      select_list_type;
    Declaration[string] list_decls;
    ModuleData[string]  list_modules;
    string              live_search_str;
    string[]            full_list,
                        current_list;

    PackageData     root_package;
}
