/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module scite.seatd_scite;

import tango.sys.win32.Types;

import tango.stdc.string;

import tango.io.File;
import tango.io.FileScan;
import tango.io.FilePath;
import tango.io.FileConst;

import tango.text.Ascii;
import tango.text.Util;

import util;
import seatd.module_data;
import seatd.package_data;
import scite.scite_ext;
import container;

/**************************************************************************************************
    Implementation of the SciTE extension interface
**************************************************************************************************/
class SeatdScite : Extension
{
    const char*     FQN_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_\0";

    ExtensionAPI    host;

    string[int]     buffer_file_names;
    string[][int]   buffer_include_paths;
    int             active_buffer;

    enum UserListType {
        none,
        goto_declaration,
        goto_module
    }

    UserListType        user_list_type;
    Declaration[string] user_list_decls;
    ModuleData[string]  user_list_modules;
    string              live_search_str;
    string[]            full_list,
                        current_list;

    PackageData     root_package;
    
    this()
    {
        root_package = new PackageData;
    }
    
    /**********************************************************************************************
        Wrappers for convenient access to SciTE and Scintilla
    **********************************************************************************************/
    sptr_t sendEditor(uint msg, uptr_t wParam=0, sptr_t lParam=0)
    {
        return host.Send(host.Pane.paneEditor, msg, wParam, lParam);
    }

    /// ditto
    string property(string name)
    {
        auto str = host.Property((name~\0).ptr);
        if ( str is null )
            return null;
        string str2 = str[0 .. strlen(str)].dup;
        delete str;
        return str2;
    }
    
    /// ditto
    string fqIdentAtCursor()
    {
        sendEditor(SCI_SETWORDCHARS, 0, cast(sptr_t)FQN_CHARS);
        auto    pos = sendEditor(SCI_GETCURRENTPOS),
                start = sendEditor(SCI_WORDSTARTPOSITION, pos),
                end = sendEditor(SCI_WORDENDPOSITION, pos);
        if ( end <= start )
            return null;
        return host.Range(host.Pane.paneEditor, start, end)[0..end-start];
    }
    
    /// ditto
    void trace(string str)
    {
        host.Trace((str~\0).ptr);
    }

    /// ditto
    void callTip(string text)
    {
        sendEditor(SCI_CALLTIPCANCEL);
        auto pos = sendEditor(SCI_GETCURRENTPOS);
        sendEditor(SCI_CALLTIPSHOW, pos, cast(sptr_t)(text~\0).ptr);
    }

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
        host.Perform(("open:"~path~\0).ptr);
    }
    
    /**********************************************************************************************
        Move the cursor to the line of the given declaration.
        Assumes that the correct file is active.
    **********************************************************************************************/
    void gotoDecl(Declaration decl)
    {
        if ( decl is null )
            return;
        sendEditor(SCI_ENSUREVISIBLEENFORCEPOLICY, decl.line-1);
        sendEditor(SCI_GOTOPOS, sendEditor(SCI_FINDCOLUMN, decl.line-1, decl.column-1));
    }

    /**********************************************************************************************
        Tries to locate and parse all imports of the given module in the given include path.
        Parses only, if the module to be imported hasn't been already parsed.
    **********************************************************************************************/
    void parseImports(ModuleData modinfo, string[] include_paths)
    {
        if ( modinfo is null )
            return null;

        foreach ( imp; modinfo.imports )
        {
            auto modinfo2 = root_package.findModule(imp.module_name);
            if ( modinfo2 !is null )
                continue;

            auto fname = findModuleFile(include_paths, imp.module_name, &this.trace);
            if ( fname is null ) {
                trace(format("Unable to find module {} in include path\n", imp.module_name));
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
                    trace("parse error");
            }
            catch ( Exception e ) {
                trace(e.msg~"\n");
            }
        }
    }

    /**********************************************************************************************
        Parses the active buffer and checks whether it's imports need to be parsed.
    **********************************************************************************************/
    ModuleData parseBuffer(bool warn_non_d_file=true)
    {
        size_t len = sendEditor(SCI_GETLENGTH);
        string text;
        text.length = len+1;
        sendEditor(SCI_GETTEXT, text.length, cast(sptr_t)text.ptr);
        text.length = text.length-1;

        string* filename = active_buffer in buffer_file_names;
        string  empty = "";
        if ( filename is null )
            filename = &empty;

        if ( SCLEX_D != sendEditor(SCI_GETLEXER)
            || filename.length < 3
            || ((*filename)[$-2 .. $] != ".d" && (*filename)[$-3 .. $] != ".di")
        )
        {
            if ( warn_non_d_file )
                callTip("semantics only available in D source files");
            return null;
        }
        
        ModuleData modinfo;
        try
        {
            modinfo = parse(*filename, text);
            if ( modinfo is null )
                trace("parse error\n");
            else {
                root_package ~= modinfo;
                auto ip = bufferIncludePath(*filename, modinfo.fqname);
                parseImports(modinfo, ip);
            }
        }
        catch ( Exception e ) {
            trace(*filename~": "~e.msg~"\n");
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
                auto mod = parse(filepath.toUtf8, cast(string)(new File(filepath)).read);
                if ( mod !is null )
                    root_package ~= mod;
            }
            catch ( Exception e ) {
                trace(filepath.toUtf8~": "~e.msg~"\n");
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

        auto    global_ip = property("seatd.global.include"),
                local_ip = property("seatd.local.include"),
                dir_home = property("SciteDirectoryHome");

        if ( dir_home !is null && locate("/\\", dir_home[$-1]) < 0 )
            dir_home ~= FileConst.PathSeparatorChar;

        auto paths = split(local_ip, ";");
        if ( paths.length == 0 )
            paths = determineIncludePath(filepath, module_name);
        paths ~= split(global_ip, ";");
        
        foreach ( ref p; paths )
        {
            assert(p !is null);
            if ( locate("/\\", p[$-1]) < 0 )
                p ~= FileConst.PathSeparatorChar;
            if ( locate("/\\", p[0]) < 0 && (p.length < 2 || p[1] != ':') )
                p = dir_home~p;
        }

//        parseIncludePath(paths);
        
        buffer_include_paths[active_buffer] = paths;
        return paths;
    }

    /**********************************************************************************************
        Tells Scintilla to display a user list using the the data in current_list.
    **********************************************************************************************/
    void showUserList(bool init=true)
    {
        if ( init ) {
            full_list.sort;
            current_list = full_list;
            live_search_str = null;
        }

        string concat_list;
        bool first = true;
        foreach ( l; current_list )
        {
            if ( first )
                first = false;
            else
                concat_list ~= " ";
            concat_list ~= l;
        }

        sendEditor(SCI_USERLISTSHOW, 3, cast(sptr_t)(concat_list~\0).ptr);
    }

extern(Windows):
    /**********************************************************************************************
        Initialize the extension. Called by COMExtension in SciTE.
    **********************************************************************************************/
    bool Initialise(ExtensionAPI host_)
    {
        host = host_;
        return host !is null;
    }

    // ditto
    bool Finalise()
    {
        return true;
    }

    /**********************************************************************************************
        Buffer handling. Implementation of the SciTE Extension API.
    **********************************************************************************************/
    bool Clear()
    {
        buffer_file_names.remove(active_buffer);
        return true;
    }

    /// ditto
    bool Load(char *filename)
    {
        return true;
    }

    /// ditto
    bool InitBuffer(int index)
    {
        active_buffer = index;
        return true;
    }

    /// ditto
    bool ActivateBuffer(int index)
    {
        active_buffer = index;
        return true;
    }

    /// ditto
    bool RemoveBuffer(int index)
    {
        buffer_file_names.remove(index);
        return true;
    }

    /// ditto
    bool OnOpen(char *filename)
    {
        string fn = filename[0..strlen(filename)];
        buffer_file_names[active_buffer] = getFullPath(fn);
        return false;
    }

    /// ditto
    bool OnSwitchFile(char *filename)
    {
        string fn = filename[0..strlen(filename)];
        buffer_file_names[active_buffer] = getFullPath(fn);
        return false;
    }

    /**********************************************************************************************
        Called on selection
    **********************************************************************************************/
    bool OnUserListSelection(int index, char* text)
    {
        try
        {
            auto str = text[0..strlen(text)];
            if ( user_list_type == UserListType.goto_declaration )
            {
                auto decl = str in user_list_decls;
                if ( decl !is null )
                    gotoDecl(*decl);
            }
            else if ( user_list_type == UserListType.goto_module )
            {
                auto mod = str in user_list_modules;
                if ( mod !is null )
                    gotoModule(*mod);
            }
            user_list_type = UserListType.none;
        }
        catch ( Exception e )
            trace(e.msg~"\n");
        return true;
    }

    /***********************************************************************************************
        Called when a SciTE shortcut with id in [1500, 1599] is issued.
    ***********************************************************************************************/
    bool OnCommand(uint cmd)
    {
        try switch ( cmd )
        {
            // list declarations
            case 0:
                if ( user_list_type != UserListType.none )
                    break;
                auto modinfo = parseBuffer;

                if ( modinfo !is null )
                {
                    user_list_decls = null;
                    full_list = null;
                    foreach ( Declaration decl; modinfo.decls )
                    {
                        string ident = decl.fqnIdent;
//                        if ( decl.mangled_type !is null )
//                            full_list ~= ident~"_"~decl.mangled_type;
//                        else
                            full_list ~= ident;
                        user_list_decls[ident] = decl;
                    }

                    showUserList;
                    user_list_type = UserListType.goto_declaration;
                }
                break;
            // list modules
            case 1:
                if ( user_list_type != UserListType.none )
                    break;
                auto modinfo = parseBuffer;

                user_list_modules = null;
                full_list = null;
                
                Stack!(PackageData) stack;
                stack ~= root_package;
                while ( !stack.empty )
                {
                    auto pak = stack.pop;
                    foreach ( mod; pak.modules )
                    {
                        full_list ~= mod.fqname;
                        user_list_modules[mod.fqname] = mod;
                    }
                    foreach ( p; pak.packages )
                        stack ~= p;
                }

                showUserList;
                user_list_type = UserListType.goto_module;
                break;
            // goto declaration
            case 2:
                if ( user_list_type != UserListType.none )
                    break;
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
                break;
            default:
                break;
        }
        catch ( Exception e )
            trace(e.msg~"\n");
        return true;
    }

    bool OnRawChar(char, uint)
    {
        trace("OnRawChar");
        return false;
    }
    
    bool OnExecute(char *)
    {
        trace("OnExecute");
        return false;
    }

    /***********************************************************************************************
        Untranslated WM_KEYDOWN
    ***********************************************************************************************/
    bool OnKey(int val, int mod)
    {
        if ( user_list_type == UserListType.none )
            return false;

        try
        {
            // TODO: do virtual key translation properly - patch SciTE?
            if ( (val >= 'A' && val <= 'Z') || (val >= '0' && val <= '9') || val == 189 || val == 190 || val == SCK_BACK )
            {
                string[]    prev_list;

                if ( val == SCK_BACK )
                {
                    prev_list = full_list;
                    if ( live_search_str.length > 0 )
                        live_search_str = live_search_str[0..$-1];
                    if ( live_search_str.length == 0 ) {
                        current_list = prev_list;
                        showUserList(false);
                        return true;
                    }
                }
                else
                {
                    if ( val == 190 )
                        val = '.';
                    else if ( val == 189 )
                        val = '_';

                    live_search_str ~= val;
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

                showUserList(false);
                return true;
            }
            switch ( val )
            {
                case VK_UP:
                case VK_DOWN:
                case SCK_RETURN:
                case SCK_TAB:
                case VK_SHIFT:
                    break;
                default:
                    user_list_type = UserListType.none;
            }
        }
        catch ( Exception e )
            trace(e.msg~"\n");
        return false;
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    bool OnDwellStart(int, char *)
    {
        return false;
    }

    bool OnClose(char *)
    {
        return false;
    }

    bool OnBeforeSave(char *)
    {
        return false;
    }

    bool OnSave(char *)
    {
        return false;
    }

    bool OnChar(char)
    {
        return false;
    }

    bool OnSavePointReached()
    {
        return false;
    }

    bool OnSavePointLeft()
    {
        return false;
    }

    bool OnStyle(uint, int, int, Accessor)
    {
        return false;
    }

    bool OnDoubleClick()
    {
        return false;
    }

    bool OnUpdateUI()
    {
        return false;
    }

    bool OnMarginClick()
    {
        return false;
    }

    bool OnMacro(char *, char *)
    {
        return false;
    }

    bool SendProperty(char *)
    {
        return false;
    }
}
