#include "plugin_kateseatd.h"
#include "plugin_kateseatd.moc"

#include <kaction.h>
#include <klocale.h>
#include <kgenericfactory.h>
#include <kurl.h>

#include <qmessagebox.h>

K_EXPORT_COMPONENT_FACTORY( kateseatdplugin, KGenericFactory<KatePluginSeatd>( "kateseatd" ) )

//=================================================================================================
class PluginView : public KXMLGUIClient
{             
    friend class KatePluginSeatd;

public:
    Kate::MainWindow *win;
};

//=================================================================================================
KatePluginSeatd::KatePluginSeatd(QObject* parent, const char* name, const QStringList&)
    : Kate::Plugin((Kate::Application*)parent, name), selection_list_active(false), viewChanged_connected(false)
{
    seatd_ = seatdGetInstance(this);
}

//=================================================================================================
KatePluginSeatd::~KatePluginSeatd()
{
}

//=================================================================================================
extern "C" void kateGetBufferText(void* plugin, const char** text, size_t* length)
{
    ((KatePluginSeatd*)plugin)->getBufferText(text, length);
}

//=================================================================================================
void KatePluginSeatd::getBufferText(const char** text, size_t* length)
{
    Kate::Document* doc = application()->activeMainWindow()->viewManager()->activeView()->getDoc();
    
    QString data = doc->text();
    char* buf = new char[data.length()];
    memcpy(buf, (const char*)data, data.length());
    *text = buf;
    *length = data.length();
}

//=================================================================================================
void KatePluginSeatd::addView(Kate::MainWindow *win)
{
    if ( !viewChanged_connected )
    {
        viewChanged_connected = true;
        connect(
            win->viewManager(), SIGNAL(viewChanged()),
            this, SLOT(viewChanged())
        );
    }

    // TODO: doesn't this have to be deleted?
    PluginView *view = new PluginView ();
             
    new KAction(
        i18n("List Modules"), 0, this,
        SLOT( listModules() ), view->actionCollection(),
        "tools_list_modules"
    );
             
    new KAction(
        i18n("List Declarations"), 0, this,
        SLOT( listDeclarations() ), view->actionCollection(),
        "tools_list_declarations"
    );
    
    view->setInstance (new KInstance("kate"));
    view->setXMLFile("plugins/kateseatd/ui.rc");
    win->guiFactory()->addClient(view);
    view->win = win;
    
    views_.append(view);
}   

//=================================================================================================
void KatePluginSeatd::removeView(Kate::MainWindow *win)
{
    for ( uint z = 0; z < views_.count(); z++ )
    {
        if ( views_.at(z)->win == win )
        {
            PluginView *view = views_.at(z);
            views_.remove(view);
            win->guiFactory()->removeClient(view);
            delete view;
        }  
    }
}

//=================================================================================================
void KatePluginSeatd::completionAborted()
{
    seatdSelectionAborted(seatd_);
    Kate::View *kv = application()->activeMainWindow()->viewManager()->activeView();
    disconnect(kv, SIGNAL(completionDone(KTextEditor::CompletionEntry)), this, 0);
    disconnect(kv, SIGNAL(completionAborted()), this, 0);
    disconnect(kv, SIGNAL(filterInsertString(KTextEditor::CompletionEntry*,QString*)), this, 0);
}

//=================================================================================================
void KatePluginSeatd::completionDone(KTextEditor::CompletionEntry entry)
{
    seatdSelectionDone(seatd_, entry.text, entry.text.length());
    Kate::View *kv = application()->activeMainWindow()->viewManager()->activeView();
    disconnect(kv, SIGNAL(completionDone(KTextEditor::CompletionEntry)), this, 0);
    disconnect(kv, SIGNAL(completionAborted()), this, 0);
}

//=================================================================================================
void KatePluginSeatd::filterInsertString(KTextEditor::CompletionEntry* e, QString* str)
{
    // avoid insertion of text
    *str = "";
    Kate::View *kv = application()->activeMainWindow()->viewManager()->activeView();
    disconnect(kv, SIGNAL(filterInsertString(KTextEditor::CompletionEntry*,QString*)), this, 0);
}

//=================================================================================================
void KatePluginSeatd::listModules()
{
    if ( !application()->activeMainWindow() )
        return;

    seatdListModules(seatd_);
}

//=================================================================================================
void KatePluginSeatd::listDeclarations()
{
    if ( !application()->activeMainWindow() )
        return;

    seatdListDeclarations(seatd_);
}

//=================================================================================================
extern "C" void kateShowSelectionList(void* plugin, const char** entries, size_t count)
{
    ((KatePluginSeatd*)plugin)->showSelectionList(entries, count);
}

//=================================================================================================
void KatePluginSeatd::showSelectionList(const char** entries, size_t count)
{
    Kate::View *kv = application()->activeMainWindow()->viewManager()->activeView();
    
    if ( !selection_list_active )
    {
        connect(
            kv, SIGNAL(completionDone(KTextEditor::CompletionEntry) ),
            this, SLOT(completionDone(KTextEditor::CompletionEntry))
        );
        connect(
            kv, SIGNAL(completionAborted()),
            this, SLOT(completionAborted())
        );
        connect(
            kv, SIGNAL(filterInsertString(KTextEditor::CompletionEntry*,QString*)),
            this, SLOT(filterInsertString(KTextEditor::CompletionEntry*,QString*))
        );
    }

    QValueList<KTextEditor::CompletionEntry> list;
    KTextEditor::CompletionEntry e;
    for ( int i = 0; i < count; ++i ) {
        e.text = entries[i];
/*
        e.type = "type";
        e.comment = "comment";
        e.prefix = "prefix";
        e.postfix = "postfix";
        e.userdata = "userdata";
*/        
        list.push_back(e);
    }
    kv->showCompletionBox(list, 0, false);
}

//=================================================================================================
extern "C" void kateShowCallTip(void* plugin, const char** entries, size_t count)
{
    ((KatePluginSeatd*)plugin)->showCallTip(entries, count);
}

//=================================================================================================
void KatePluginSeatd::showCallTip(const char** entries, size_t count)
{
    Kate::View *kv = application()->activeMainWindow()->viewManager()->activeView();

    QStringList functionList;
    for ( int i = 0; i < count; ++i )
        functionList.push_back(entries[i]);
    kv->showArgHint(functionList, "wrapping", "delimiter");
}

//=================================================================================================
extern "C" void kateSetCursor(void* plugin, unsigned int line, unsigned int col)
{
    ((KatePluginSeatd*)plugin)->setCursor(line, col);
}

//=================================================================================================
void KatePluginSeatd::setCursor(unsigned int line, unsigned int col)
{
    Kate::View *kv = application()->activeMainWindow()->viewManager()->activeView();
    // cursor pos without considering tab-width
    kv->setCursorPositionReal(line, col);
}

//=================================================================================================
extern "C" void kateGetCursor(void* plugin, unsigned int* line, unsigned int* col)
{
    ((KatePluginSeatd*)plugin)->getCursor(line, col);
}

//=================================================================================================
void KatePluginSeatd::getCursor(unsigned int* line, unsigned int* col)
{
    Kate::View *kv = application()->activeMainWindow()->viewManager()->activeView();
    // cursor pos without considering tab-width
    kv->cursorPositionReal(line, col);
}

//=================================================================================================
extern "C" void kateOpenFile(void* plugin, const char* filepath)
{
    ((KatePluginSeatd*)plugin)->openFile(filepath);
}

//=================================================================================================
void KatePluginSeatd::openFile(const char* filepath)
{
    Kate::ViewManager* vm = application()->activeMainWindow()->viewManager();
    QString str = "file://";
    str += filepath;
    KURL url = KURL::fromPathOrURL(str);
    vm->openURL(url);
}

//=================================================================================================
void KatePluginSeatd::viewChanged()
{
    // TODO: check whether that files was open already and activate buffer in plugin
    // maybe better get rid of buffer-awarenes in plugin
    Kate::Document* doc = application()->documentManager()->activeDocument();
    if ( doc )
        seatdSetBufferFile(seatd_, (const char*)doc->url().path(), doc->url().path().length());
}
