/*  SEATD for SciTE
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module scite.seatd_scite;

import scite.scite_ext;
import abstract_plugin;

import tango.stdc.string;

version(Windows) import tango.sys.win32.Types;

/**************************************************************************************************
    SciTE specific implementation of the AbstractPlugin interface
**************************************************************************************************/
class SeatdScite : public AbstractPlugin, public Extension
{
    enum SelectionListT {
        none,
        goto_declaration,
        goto_module
    }

    ExtensionAPI    host;
    string[int]     buffer_filepaths;
    int             active_buffer;
    SelectionListT  select_list_type_;

    this()
    {
        super();
    }

// temporarily copied from abstract_plugin - becomes specialization

    /***********************************************************************************************

    ***********************************************************************************************/
    void gotoDeclarationAtCursor(string text)
    {
        auto bufferinfo = parseBuffer(text, false);

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


    string              live_search_str_;
    string[]            full_list_,
                        current_list_;

    
// temp copy end
    
    /**********************************************************************************************
        Get a list of include paths that have been set by the user in some configuration facility.
    **********************************************************************************************/
    string[] getIncludePaths()
    {
        auto    global_ip_c = host.Property("seatd.global.include"),
                local_ip_c = host.Property("seatd.local.include"),
                dir_home_c = host.Property("SciteDirectoryHome");
        auto    global_ip = global_ip_c[0 .. strlen(global_ip_c)],
                local_ip = local_ip_c[0 .. strlen(local_ip_c)],
                dir_home = dir_home_c[0 .. strlen(dir_home_c)];

        if ( dir_home.length > 0 && contains("/\\", dir_home[$-1]) )
            dir_home ~= FileConst.PathSeparatorChar;

        auto paths = split(local_ip, ";");
        paths ~= split(global_ip, ";");
        return paths;
    }

    /**********************************************************************************************
        Read a fully qualified identifier from the current editor buffer at the cursor.
    **********************************************************************************************/
    string fqIdentAtCursor()
    {
        sendEditor(SCI_SETWORDCHARS, 0, cast(sptr_t)FQN_CHARS.ptr);
        auto    pos = sendEditor(SCI_GETCURRENTPOS),
                start = sendEditor(SCI_WORDSTARTPOSITION, pos),
                end = sendEditor(SCI_WORDENDPOSITION, pos);
        if ( end <= start )
            return null;
        return host.Range(host.Pane.paneEditor, start, end)[0..end-start];
    }
    
    /**********************************************************************************************
        Output to a host logging facility, message box or similar.
    **********************************************************************************************/
    void log(string str)
    {
        host.Trace((str~\n~\0).ptr);
    }

    /**********************************************************************************************
        Display a small hint-class message for signatures, DDocs, simple messages like
        "identifier not found", or similar. Usually a small popup window.
    **********************************************************************************************/
    void callTip(string text)
    {
        sendEditor(SCI_CALLTIPCANCEL);
        auto pos = sendEditor(SCI_GETCURRENTPOS);
        sendEditor(SCI_CALLTIPSHOW, pos, cast(sptr_t)(text~\0).ptr);
    }

    /**********************************************************************************************
        Open the given source file in the editor.
    **********************************************************************************************/
    void openFile(string filepath)
    {
        host.Perform(("open:"~filepath~\0).ptr);
    }

    /**********************************************************************************************
        Set the cursor (and view) to the given position in the file
    **********************************************************************************************/
    void setCursor(int line, int col)
    {
        sendEditor(SCI_ENSUREVISIBLEENFORCEPOLICY, line);
        sendEditor(SCI_GOTOPOS, sendEditor(SCI_FINDCOLUMN, line, col));
    }

    /**********************************************************************************************
        Access the current buffer's text data.
    **********************************************************************************************/
    string getBufferText()
    {
        size_t len = sendEditor(SCI_GETLENGTH);
        string text;
        text.length = len+1;
        sendEditor(SCI_GETTEXT, text.length, cast(sptr_t)text.ptr);
        text.length = text.length-1;
        return text;
    }

    /**********************************************************************************************
        Determine whether the current buffer is to be parsed.
        Usually done using the file extension or editor settings.
    **********************************************************************************************/
    bool isParsableBuffer()
    {
        string* filename = active_buffer in buffer_file_names;
        string  empty = "";
        if ( filename is null )
            filename = &empty;
        if ( SCLEX_D != sendEditor(SCI_GETLEXER)
            || filename.length < 3
            || ((*filename)[$-2 .. $] != ".d" && (*filename)[$-3 .. $] != ".di")
        )
            return true;
        return false;
    }

    /**********************************************************************************************
        Display a selection list.
        Will be called repeatedly, while the user types and the list shrinks.
    **********************************************************************************************/
    void showSelectionList(string[] entries)
    {
        string concat_list;
        bool first = true;
        foreach ( l; entries )
        {
            if ( first )
                first = false;
            else
                concat_list ~= " ";
            concat_list ~= l;
        }

        sendEditor(SCI_USERLISTSHOW, 3, cast(sptr_t)(concat_list~\0).ptr);
    }

    sptr_t sendEditor(uint msg, uptr_t wParam=0, sptr_t lParam=0)
    {
        return host.Send(host.Pane.paneEditor, msg, wParam, lParam);
    }

    //=============================================================================================
    // Implementation of the SciTE Extension interface
    
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
        buffer_filepaths[active_buffer] = null;
        return true;
    }

    /// ditto
    bool Load(char *filename)
    {
        buffer_filepaths[active_buffer] = filename[0 .. strlen(filename)];
        setActiveFilepath(buffer_filepaths[index]);
        return true;
    }

    /// ditto
    bool InitBuffer(int index)
    {
        active_buffer = index;
        if ( (index in buffer_filepaths) !is null )
            setActiveFilepath(buffer_filepaths[index]);
        return true;
    }

    /// ditto
    bool ActivateBuffer(int index)
    {
        active_buffer = index;
        if ( (index in buffer_filepaths) !is null )
            setActiveFilepath(buffer_filepaths[index]);
        return true;
    }

    /// ditto
    bool RemoveBuffer(int index)
    {
        if ( (index in buffer_filepaths) !is null )
            buffer_filepaths[index] = null;
        return true;
    }

    /// ditto
    bool OnOpen(char *filename)
    {
        buffer_filepaths[active_buffer] = filename[0 .. strlen(filename)];
        setActiveFilepath(buffer_filepaths[active_buffer]);
        return false;
    }

    /// ditto
    bool OnSwitchFile(char *filename)
    {
        buffer_filepaths[active_buffer] = filename[0 .. strlen(filename)];
        setActiveFilepath(buffer_filepaths[active_buffer]);
        return false;
    }

    /**********************************************************************************************
        Called on selection
    **********************************************************************************************/
    bool OnUserListSelection(int index, char* text)
    {
        select_list_type_ = SelectionListT.none;
        try
        {
            auto str = text[0..strlen(text)];
            if ( select_list_type_ == SelectionListT.goto_declaration )
                gotoDeclaration(str);
            else if ( select_list_type_ == SelectionListT.goto_module )
                gotoModule(str);
        }
        catch ( Exception e )
            log(e.msg~"\n");
        return true;
    }

    /***********************************************************************************************
        Called when a SciTE shortcut with id in [1500, 1599] is issued.
    ***********************************************************************************************/
    bool OnCommand(uint cmd)
    {
        try switch ( cmd )
        {
            case 0:
                if ( select_list_type_ != SelectionListT.none ) {
                    listDeclarations();
                    select_list_type_ = SelectionListT.goto_declaration;
                }
                break;
            case 1:
                if ( select_list_type_ == SelectionListT.none ) {
                    listModules();
                    select_list_type_ = SelectionListT.goto_module;
                }
                break;
            case 2:
                if ( select_list_type_ == SelectionListT.none )
                    gotoDeclaration();
                break;
            default:
                break;
        }
        catch ( Exception e )
            log(e.msg~"\n");
        return true;
    }

    /***********************************************************************************************
        Untranslated WM_KEYDOWN
    ***********************************************************************************************/
    bool OnKey(int val, int mod)
    {
        if ( select_list_type_ == SelectionListT.none )
            return false;
        try
        {
            // TODO: do virtual key translation properly - patch SciTE?
            if ( (val >= 'A' && val <= 'Z') || (val >= '0' && val <= '9') || val == 189 || val == 190 || val == SCK_BACK )
            {
                dchar c;

                switch ( val )
                {
                    case SCK_BACK:
                        c = 8;
                        break;
                    case 189:
                        c = '_';
                        break;
                    case 190:
                        c = '.';
                        break;
                    default:
                        c = val;
                        break;
                }
                return onChar(c);
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
                    select_list_type = SelectionListT.none;
            }
        }
        catch ( Exception e )
            log(e.msg~"\n");
        return false;
    }

    /***********************************************************************************************

    ***********************************************************************************************/
    bool OnRawChar(char, uint)
    {
        return false;
    }
    
    bool OnExecute(char *)
    {
        return false;
    }

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
