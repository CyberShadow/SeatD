// Ported to D by Jascha Wetzel
// SciTE - Scintilla based Text Editor
/** @file Extender.h
 ** SciTE extension interface.
 **/
// Copyright 1998-2001 by Neil Hodgson <neilh@scintilla.org>
// The License.txt file describes the conditions under which this software may be distributed.

//#include "Scintilla.h"
//class Accessor;
module scite.scite_ext;

public import scite.scintilla;
public import scite.scilexer;

alias void* Accessor;
alias int sptr_t;
alias uint uptr_t;

extern(Windows):

interface ExtensionAPI
{
extern(Windows):
    enum Pane { paneEditor=1, paneOutput=2, paneFindOutput=3 };
    sptr_t Send(Pane p, uint msg, uptr_t wParam=0, sptr_t lParam=0);
    char *Range(Pane p, int start, int end);
    void Remove(Pane p, int start, int end);
    void Insert(Pane p, int pos, char *s);
    void Trace(char *s);
    char *Property(char *key);
    void SetProperty(char *key, char *val);
    void UnsetProperty(char *key);
    uptr_t GetInstance();
    void ShutDown();
    void Perform(char *actions);
    void DoMenuCommand(int cmdID);
    void UpdateStatusBar(bool bUpdateSlowData);
}

/**
 * Methods in extensions return true if they have completely handled and event and
 * false if default processing is to continue.
 */
interface Extension
{
extern(Windows):
    bool Initialise(ExtensionAPI host_);
    bool Finalise();
    bool Clear();
    bool Load(char *filename);

    bool InitBuffer(int);
    bool ActivateBuffer(int);
    bool RemoveBuffer(int);

    bool OnOpen(char *);
    bool OnSwitchFile(char *);
    bool OnBeforeSave(char *);
    bool OnSave(char *);
    bool OnChar(char);
    bool OnRawChar(char, uint);
    bool OnExecute(char *);
    bool OnCommand(uint);
    bool OnSavePointReached();
    bool OnSavePointLeft();
    bool OnStyle(uint, int, int, Accessor);
    bool OnDoubleClick();
    bool OnUpdateUI();
    bool OnMarginClick();
    bool OnMacro(char *, char *);
    bool OnUserListSelection(int, char *);

    bool SendProperty(char *);

    bool OnKey(int, int);
    bool OnDwellStart(int, char *);
    bool OnClose(char *);
}
