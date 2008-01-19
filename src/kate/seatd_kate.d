/*  SEATD for Kate
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module kate.seatd_kate;

import abstract_plugin;

import tango.stdc.stdio;
import tango.stdc.string;
import tango.text.convert.Layout;
import tango.text.Util;

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
        return instance_;
    }
    
    /**********************************************************************************************
        Get a list of include paths that have been set by the user in some configuration facility.
    **********************************************************************************************/
    string[] getIncludePaths()
    {
        char* ptr;
        size_t len;
        kateGetDocumentVariable(kate_instance_, "SEATDIncludePath", &ptr, &len);
        auto paths = split(ptr[0 .. len].dup, ",");
        kateFreeString(ptr);
        return paths;
    }

    /**********************************************************************************************
        Output to a host logging facility, message box or similar.
    **********************************************************************************************/
    void log(string str)
    {
        Stdout.formatln("{}", str);
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
        Determine whether the current buffer is to be parsed.
        Usually done using the file extension or editor settings.
    **********************************************************************************************/
    bool isParsableBuffer()
    {
        return true;
    }


protected:
    void* kate_instance_;

    void setKateInstance(void* kate_instance)
    {
        kate_instance_ = kate_instance;
    }
}

extern(C) void kateSetCursor(void* plugin, uint line, uint col);
extern(C) void kateGetCursor(void* plugin, uint* line, uint* col);
extern(C) void kateOpenFile(void* plugin, char* filepath);
extern(C) void kateGetDocumentVariable(void* plugin, char* name, char** str, size_t* len);
extern(C) void kateFreeString(char* str);

extern(C) bool rt_init( void delegate(Exception e) dg = null );
extern(C) bool rt_term( void delegate(Exception e) dg = null );

//=============================================================================================
// C Exports for access by the C++ implementation of the Kate plugin interface
extern(C):

/**********************************************************************************************

**********************************************************************************************/
void* seatdGetInstance(void* kate_instance)
{
    fprintf(stderr, "Initiaizing Tango D Runtime\n");
    rt_init();
    fprintf(stderr, "Disabling GC\n");
    GC.disable();
    fprintf(stderr, "Instantiating D plugin class\n");
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

void seatdListModules(void* inst, char* text, size_t len, char*** entries, size_t* count)
{
    auto dtext = text[0 .. len].dup;
    debug
    {
        auto list = (cast(SeatdKate)inst).listModules(dtext);
        *count = list.length;
        auto clist = new char*[list.length];
        foreach ( i, e; list )
            clist[i] = (e~\0).ptr;
        *entries = clist.ptr;
    }
    else
    {
        try
        {
            auto list = (cast(SeatdKate)inst).listModules(dtext);
            *count = list.length;
            auto clist = new char*[list.length];
            foreach ( i, e; list )
                clist[i] = (e~\0).ptr;
            *entries = clist.ptr;
        }
        catch ( Exception e ) {
            *count = 0;
            *entries = null;
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}

void seatdFreeList(char** entries)
{
    delete entries;
}

void seatdListDeclarations(void* inst, char* text, size_t len, char*** entries, size_t* count)
{
    auto dtext = text[0 .. len].dup;
    debug {
        auto list = (cast(SeatdKate)inst).listDeclarations(dtext);
        *count = list.length;
        auto clist = new char*[list.length];
        foreach ( i, e; list )
            clist[i] = (e~\0).ptr;
        *entries = clist.ptr;
    }
    else
    {
        try {
            auto list = (cast(SeatdKate)inst).listDeclarations(dtext);
            *count = list.length;
            auto clist = new char*[list.length];
            foreach ( i, e; list )
                clist[i] = (e~\0).ptr;
            *entries = clist.ptr;
        }
        catch ( Exception e ) {
            *count = 0;
            *entries = null;
            fprintf(stderr, "D Exception: %s\n", (e.msg~\0).ptr);
        }
    }
}

bool seatdGotoSymbol(void* inst, char* text, size_t text_len, char* symbol, size_t symbol_len)
{
    debug {
        return (cast(SeatdKate)inst).gotoSymbol(text[0 .. text_len], symbol[0 .. symbol_len]);
    }
    else
    {
        try {
            return (cast(SeatdKate)inst).gotoSymbol(text[0 .. text_len], symbol[0 .. symbol_len]);
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
        (cast(SeatdKate)inst).gotoModule(text[0 .. len]);
    }
    else
    {
        try {
            (cast(SeatdKate)inst).gotoModule(text[0 .. len]);
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
