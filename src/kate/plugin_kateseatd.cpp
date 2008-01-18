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
    : Kate::Plugin((Kate::Application*)parent, name)
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
    views_.at(0)->getBufferText(text, length);
}

//=================================================================================================
void KatePluginSeatd::addView(Kate::MainWindow *win)
{
    KatePluginSeatdView *view = new KatePluginSeatdView(seatd_, win);
    views_.append(view);
}   

//=================================================================================================
void KatePluginSeatd::removeView(Kate::MainWindow *win)
{
    for ( uint z = 0; z < views_.count(); z++ )
    {
        if ( views_.at(z)->win == win )
        {
            KatePluginSeatdView* view = views_.at(z);
            views_.remove(view);
            win->guiFactory()->removeClient(view);
            delete view;
        }  
    }
}

//=================================================================================================
extern "C" void kateShowSelectionList(void* plugin, const char** entries, size_t count)
{
    ((KatePluginSeatd*)plugin)->showSelectionList(entries, count);
}

//=================================================================================================
void KatePluginSeatd::showSelectionList(const char** entries, size_t count)
{
    views_.at(0)->showSelectionList(entries, count);
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
KatePluginSeatdView::KatePluginSeatdView(void* seatd, Kate::MainWindow *w) : seatd_(seatd), win(w), list_type_(none)
{
    setInstance(new KInstance("kate"));
    setXMLFile("plugins/kateseatd/ui.rc");
    w->guiFactory()->addClient(this);

    new KAction(
        i18n("List Modules"), 0, this,
        SLOT( listModules() ), actionCollection(),
        "tools_list_modules"
    );
             
    new KAction(
        i18n("List Declarations"), 0, this,
        SLOT( listDeclarations() ), actionCollection(),
        "tools_list_declarations"
    );

    dock_ = win->toolViewManager()->createToolView("kate_plugin_seatd", Kate::ToolViewManager::Left, QPixmap((const char**)class_xpm), i18n("SEATD Lists"));
    listview_ = new KListView(dock_);

    connect(listview_, SIGNAL(executed(QListViewItem *)), this, SLOT(gotoSymbol(QListViewItem *)));
//    connect(listview_, SIGNAL(rightButtonClicked(QListViewItem *, const QPoint&, int)),
//           SLOT(slotShowContextMenu(QListViewItem *, const QPoint&, int)));
//    connect(win->viewManager(), SIGNAL(viewChanged()), this, SLOT(slotDocChanged()));
    //connect(symbols, SIGNAL(resizeEvent(QResizeEvent *)), this, SLOT(slotViewChanged(QResizeEvent *)));

    //symbols->addColumn(i18n("Symbols"), symbols->parentWidget()->width());
    listview_->addColumn(i18n("Name"));
    listview_->addColumn(i18n("Position"));
    listview_->setColumnWidthMode(1, QListView::Manual);
    listview_->setColumnWidth ( 1, 0 );
    listview_->setSorting(-1, FALSE);
    listview_->setRootIsDecorated(0);
    listview_->setTreeStepSize(10);
    listview_->setShowToolTips(TRUE);

    connect(
        win->viewManager(), SIGNAL(viewChanged()),
        this, SLOT(viewChanged())
    );
}

//=================================================================================================
KatePluginSeatdView::~KatePluginSeatdView()
{
    win->guiFactory()->removeClient (this);
}

//=================================================================================================
void KatePluginSeatdView::viewChanged()
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;
    seatdSetBufferFile(seatd_, (const char*)doc->url().path(), doc->url().path().length());

    switch ( list_type_ )
    {
        default:
        case decls:
            listDeclarations();
            break;
        case modules:
            listModules();
            break;
    }
}

//=================================================================================================
void KatePluginSeatdView::listModules()
{
    seatdListModules(seatd_);
    list_type_ = modules;
}

//=================================================================================================
void KatePluginSeatdView::listDeclarations()
{
    seatdListDeclarations(seatd_);
    list_type_ = decls;
}

//=================================================================================================
void KatePluginSeatdView::getBufferText(const char** text, size_t* length)
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;
    
    QString data = doc->text();
    char* buf = new char[data.length()];
    memcpy(buf, (const char*)data, data.length());
    *text = buf;
    *length = data.length();
}

//=================================================================================================
void KatePluginSeatdView::showSelectionList(const char** entries, size_t count)
{
    listview_->clear();
    for ( int i = 0; i < count; ++i )
        new QListViewItem(listview_, listview_->lastItem(), entries[i]);
}

//=================================================================================================
void KatePluginSeatdView::gotoSymbol(QListViewItem* item)
{
    switch ( list_type_ )
    {
        case decls:
            seatdGotoDeclaration(seatd_, item->text(0), item->text(0).length());
            break;
        case modules:
            seatdGotoModule(seatd_, item->text(0), item->text(0).length());
            break;
        default:
            break;
    }
}
