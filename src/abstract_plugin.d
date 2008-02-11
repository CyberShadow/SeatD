/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module abstract_plugin;

import tango.io.File;
import tango.io.FileScan;
import tango.io.FilePath;
import tango.io.FileConst;
import tango.io.Stdout;

import tango.text.Ascii;
import tango.text.Util;
import tango.text.convert.Layout;

import seatd.symbol;
import util;
import container;
import common;

import tango.stdc.stdio;

struct HistoryLocation
{
    string  filepath;
    uint    line,
            column;
}


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
        root_package_ = new Package(null);
    }

    //=============================================================================================
    // Interface to the host, needs to be overridden in host specific subclass.

    /**********************************************************************************************
        Get a list of include paths that have been set by the user in some configuration facility.
    **********************************************************************************************/
    string[] getIncludePaths();

    /**********************************************************************************************
        Determine whether the current buffer is to be parsed.
        Usually done using the file extension or editor settings.
    **********************************************************************************************/
    bool isParsableBuffer();

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


    //=============================================================================================
    // Interface to SEATD plugin functionality. Called by host specific subclass

    /**********************************************************************************************
        Set the filepath of the active buffer.
        This name is used together with the parsed module name to automatically determine include paths.
    **********************************************************************************************/
    void setActiveFilepath(string filename)
    {
        active_filepath_ = filename;
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    string[] listDeclarations(string text)
    {
        auto modinfo = parseBuffer(text);

        string[] list;
        list_decls_ = null;

        if ( modinfo !is null )
        {
            foreach ( Declaration decl; modinfo.decls )
            {
                string ident = decl.fqnIdentWithoutModule;
/+                 if ( decl.mangled_type !is null )
                    full_list ~= ident~"_"~decl.mangled_type;
                else
 +/                    list ~= ident;
                list_decls_[ident] = decl;
            }
        }

        return list;
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    string[] listModules(string text)
    {
        auto modinfo = parseBuffer(text);

        string[] list;
        list_modules_ = null;
        list_modules_by_filepath_ = null;

        Stack!(PackageData) stack;
        stack ~= root_package_;
        while ( !stack.empty )
        {
            auto pak = stack.pop;
            foreach ( mod; pak.modules )
            {
                list ~= mod.fqname;
                list_modules_[mod.fqname] = mod;
                list_modules_by_filepath_[mod.filepath.toString] = mod;
            }
            foreach ( p; pak.packages )
                stack ~= p;
        }

        return list;
    }

    // TODO: implement
    void markModuleDirty(string filepath)
    {
        auto mod = filepath in list_modules_by_filepath_;
        if ( mod !is null )
            mod.externally_modified_ = true;
    }


    //=============================================================================================
    // internal helper functions

    /**********************************************************************************************
        Open the source file of the given module in the editor.
    **********************************************************************************************/
    void gotoModule(ModuleData modinfo, bool save_current=true)
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

        if ( save_current )
            saveCurrentLocation();
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
    void gotoDeclaration(Declaration decl, bool save_current=true)
    {
        if ( decl is null )
            return;
        if ( save_current )
            saveCurrentLocation();
        setCursor(decl.line-1, decl.column-1);
    }

    void gotoDeclaration(string text)
    {
        auto decl = text in list_decls_;
        if ( decl !is null )
            gotoDeclaration(*decl);
    }

    bool gotoSymbol(string text, string symbol)
    {
        auto bufferinfo = parseBuffer(text, false);

        auto modinfo = bufferinfo;
        Declaration decl = root_package_.findDeclaration(symbol, modinfo);
        if ( decl is null )
            return false;
        else
        {
            saveCurrentLocation();
            if ( modinfo !is bufferinfo )
                gotoModule(modinfo, false);
            gotoDeclaration(decl, false);
        }
        return true;
    }

    /**********************************************************************************************

    **********************************************************************************************/
    void gotoPrevious()
    {
        if ( next_history_index_ <= 0 )
            return;
        if ( next_history_index_ >= history_top_ ) {
            saveCurrentLocation();
            --next_history_index_;
        }
        --next_history_index_;

        debug Stdout.formatln("Goto {}({}:{}) {} of {}",
            history_[next_history_index_].filepath, history_[next_history_index_].line,
            history_[next_history_index_].column, next_history_index_, history_top_
        );
        openFile(history_[next_history_index_].filepath);
        setCursor(history_[next_history_index_].line, history_[next_history_index_].column);
    }

    /**********************************************************************************************

    **********************************************************************************************/
    void gotoNext()
    {
        if ( next_history_index_ >= history_top_-1 )
            return;
        ++next_history_index_;

        debug Stdout.formatln("Goto {}({}:{}) {} of {}",
            history_[next_history_index_].filepath, history_[next_history_index_].line,
            history_[next_history_index_].column, next_history_index_, history_top_
        );
        openFile(history_[next_history_index_].filepath);
        setCursor(history_[next_history_index_].line, history_[next_history_index_].column);
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
                doSemantics(root_package_, modinfo2, SemanticsPass.collect);
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
    ModuleData parseBuffer(string text, bool warn_non_d_file=true)
    {
        if ( !isParsableBuffer )
            return null;

        ModuleData modinfo;

        modinfo = parse(active_filepath_, text);
        doSemantics(root_package_, modinfo, SemanticsPass.collect);
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
                doSemantics(root_package_, mod, SemanticsPass.collect);
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
        Saves the current location in the history.
    **********************************************************************************************/
    void saveCurrentLocation()
    {
        uint line, col;
        getCursor(line, col);
        if ( next_history_index_ >= history_.length )
            history_.length = history_.length*2+1;
        if ( next_history_index_ > 0 )
        {
            HistoryLocation loc = history_[next_history_index_-1];
            if ( loc.filepath == active_filepath_ && loc.line == line )
                return;
        }

        debug Stdout.formatln("Saving {}({}:{}) {}", active_filepath_, line, col, next_history_index_);
        history_[next_history_index_] = HistoryLocation(active_filepath_, line, col);
        history_[next_history_index_++] = HistoryLocation(active_filepath_, line, col);
        history_top_ = next_history_index_;
    }


protected:
    string              active_filepath_;
    string[][string]    buffer_include_paths_;

    Declaration[string] list_decls_;
    Module[string]      list_modules_,
                        list_modules_by_filepath_;

    Package             root_package_;

    HistoryLocation[]   history_;
    uint                next_history_index_,
                        history_top_;
}
