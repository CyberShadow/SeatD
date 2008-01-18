/*  SEATD for Kate
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module kate.seatd_kate;

import abstract_plugin;

import tango.stdc.stdio;
import tango.stdc.string;
import tango.text.convert.Layout;

import tango.core.Memory;

import tango.io.Stdout;

/**************************************************************************************************

**************************************************************************************************/
class SeatdKate : public AbstractPlugin
{
private:
    static SeatdKate instance_;

    this()
    {
        super();
    }

public:
    static SeatdKate getInstance()
    {
        if ( instance_ is null )
            instance_ = new SeatdKate;
        int new_decl;
        try {
            int hidden_decl;
        
        }
        catch ( Exception e ) {}
        return instance_;
    }
    
    /**********************************************************************************************
        Access key-value pair from the configuration
    **********************************************************************************************/
    string configProperty(string name)
    {
        return "";
    }

    /**********************************************************************************************
        Read a fully qualified identifier from the current editor buffer at the cursor.
    **********************************************************************************************/
    string fqIdentAtCursor()
    {
        return "";
    }
    
    /**********************************************************************************************
        Output to a host logging facility, message box or similar.
    **********************************************************************************************/
    void log(string str)
    {
        Stdout.formatln("{}", str);
    }

    /**********************************************************************************************
        Display a small hint-class message for signatures, DDocs, simple messages like
        "identifier not found", or similar. Usually a small popup window.
    **********************************************************************************************/
    void callTip(string text)
    {
        char*[] entries;
        entries ~= (text~\0).ptr;
        kateShowCallTip(kate_instance_, entries.ptr, 1);
    }

    /**********************************************************************************************
        Open the given source file in the editor.
    **********************************************************************************************/
    void openFile(string filepath)
    {
        kateOpenFile(kate_instance_, (filepath~\0).ptr);
    }

    /**********************************************************************************************
        Set the cursor (and view) to the given position in the file
    **********************************************************************************************/
    void setCursor(uint line, uint col)
    {
        kateSetCursor(kate_instance_, line, col);
    }

    /**********************************************************************************************
        Get the current position of the cursor.
    **********************************************************************************************/
    void getCursor(ref uint line, ref uint col)
    {
        kateGetCursor(kate_instance_, &line, &col);
    }

    /**********************************************************************************************
        Access the current buffer's text data.
    **********************************************************************************************/
    string getBufferText()
    {
        char*   buf;
        size_t  len;
        kateGetBufferText(kate_instance_, &buf, &len);
        return buf[0 .. len];
    }

    /**********************************************************************************************
        Determine whether the current buffer is to be parsed.
        Usually done using the file extension or editor settings.
    **********************************************************************************************/
    bool isParsableBuffer()
    {
        return true;
    }

    /**********************************************************************************************
        Display a selection list.
        Will be called repeatedly, while the user types and the list shrinks.
    **********************************************************************************************/
    void showSelectionList(string[] entries)
    {
        auto clist = new char*[entries.length];
        foreach ( i, e; entries )
            clist[i] = (e~\0).ptr;
        kateShowSelectionList(kate_instance_, clist.ptr, clist.length);
    }


protected:
    void* kate_instance_;

    void setKateInstance(void* kate_instance)
    {
        kate_instance_ = kate_instance;
    }
}

extern(C) void kateGetBufferText(void* plugin, char** text, size_t* length);
extern(C) void kateShowSelectionList(void* plugin, char** entries, size_t count);
extern(C) void kateShowCallTip(void* plugin, char** entries, size_t count);
extern(C) void kateSetCursor(void* plugin, uint line, uint col);
extern(C) void kateGetCursor(void* plugin, uint* line, uint* col);
extern(C) void kateOpenFile(void* plugin, char* filepath);

extern(C) bool rt_init( void delegate(Exception e) dg = null );
extern(C) bool rt_term( void delegate(Exception e) dg = null );

//=============================================================================================
// C Exports for access by the C++ implementation of the Kate plugin interface
extern(C):

/**********************************************************************************************

**********************************************************************************************/
void* seatdGetInstance(void* kate_instance)
{
    fprintf(stderr, "INIT'ING D RUNTIME\n");
    rt_init();
    GC.disable();
    SeatdKate sk;
    try {
        sk = SeatdKate.getInstance();
        sk.setKateInstance(kate_instance);
    }
    catch ( Exception e ) {
        fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        sk = null;
    }
    return cast(void*)sk;
}

void seatdListModules(void* inst)
{
    debug {
        (cast(SeatdKate)inst).listModules();
    }
    else
    {
        try {
            (cast(SeatdKate)inst).listModules();
        }
        catch ( Exception e ) {
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}

void seatdListDeclarations(void* inst)
{
    debug {
        (cast(SeatdKate)inst).listDeclarations();
    }
    else
    {
        try {
            (cast(SeatdKate)inst).listDeclarations();
        }
        catch ( Exception e ) {
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}

void seatdGotoDeclaration(void* inst, char* text, size_t len)
{
    debug {
        (cast(SeatdKate)inst).gotoDeclaration(text[0 .. len]);
    }
    else
    {
        try {
            (cast(SeatdKate)inst).gotoDeclaration(text[0 .. len]);
        }
        catch ( Exception e ) {
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}

void seatdGotoModule(void* inst, char* text, size_t len)
{
    debug {
        (cast(SeatdKate)inst).gotoDeclaration(text[0 .. len]);
    }
    else
    {
        try {
            (cast(SeatdKate)inst).gotoDeclaration(text[0 .. len]);
        }
        catch ( Exception e ) {
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}

void seatdOnChar(void* inst, char c)
{
    debug {
        (cast(SeatdKate)inst).onChar(c);
    }
    else
    {
        try {
            (cast(SeatdKate)inst).onChar(c);
        }
        catch ( Exception e ) {
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}

void seatdSetBufferFile(void* inst, char* filepath, size_t len)
{
    debug {
        (cast(SeatdKate)inst).setActiveFilepath(filepath[0 .. len]);
    }
    else
    {
        try {
            (cast(SeatdKate)inst).setActiveFilepath(filepath[0 .. len]);
        }
        catch ( Exception e ) {
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}
