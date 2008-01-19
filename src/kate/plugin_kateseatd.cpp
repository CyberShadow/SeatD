#include "plugin_kateseatd.h"
#include "plugin_kateseatd.moc"

#include <kaction.h>
#include <klocale.h>
#include <kgenericfactory.h>
#include <kurl.h>
#include <qheader.h>

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
extern "C" void kateGetDocumentVariable(void* plugin, const char* name, const char** str, size_t* len)
{
    ((KatePluginSeatd*)plugin)->getDocumentVariable(name, str, len);
}

//=================================================================================================
extern "C" void kateFreeString(const char* str)
{
    delete str;
}

//=================================================================================================
void KatePluginSeatd::getDocumentVariable(const char* name, const char** str, size_t* len)
{
    Kate::DocumentManager* dm = application()->documentManager();
    QString qname = name,
            concat_val;
    for ( int i = dm->documents()-1; i >= 0; --i )
    {
        Kate::DocumentExt* doc = documentExt(dm->document(i));
        if ( !doc )
            continue;
        QString val = doc->variable(qname);
        if ( val.length() > 0 )
        {
            if ( concat_val.length() > 0 )
                concat_val += ",";
            concat_val += val;
        }
    }
    
    char* buf = new char[concat_val.length()];
    memcpy(buf, (const char*)concat_val, concat_val.length());
    *str = buf;
    *len = concat_val.length();
}

//=================================================================================================
KatePluginSeatdView::KatePluginSeatdView(void* seatd, Kate::MainWindow *w) : seatd_(seatd), win(w), list_type_(none)
{
    new KAction(
        i18n("List Modules"), 0, this,
        SLOT( listModules() ), actionCollection(),
        "view_list_modules"
    );
             
    new KAction(
        i18n("List Declarations"), 0, this,
        SLOT( listDeclarations() ), actionCollection(),
        "view_list_declarations"
    );

    setInstance(new KInstance("kate"));
    setXMLFile("plugins/kateseatd/ui.rc");
    w->guiFactory()->addClient(this);

    dock_ = win->toolViewManager()->createToolView("kate_plugin_seatd", Kate::ToolViewManager::Left, QPixmap((const char**)class_xpm), i18n("SEATD Lists"));
    widget_ = new QWidget(dock_);
    vboxLayout_ = new QVBoxLayout(widget_);
    search_input_ = new SeatdSearchLine(widget_, win);
    listview_ = new KListView(widget_);
    search_input_->setListView(listview_);
    vboxLayout_->addWidget(search_input_);
    vboxLayout_->addWidget(listview_);

    listview_->addColumn(i18n("Name"));
    listview_->setColumnWidthMode(1, QListView::Manual);
    listview_->setColumnWidth ( 1, 0 );
    listview_->setSorting(-1, FALSE);
    listview_->setRootIsDecorated(0);
    listview_->setTreeStepSize(10);
    listview_->setShowToolTips(TRUE);
    listview_->header()->hide();

    connect(search_input_, SIGNAL(returnPressed()), this, SLOT(searchSubmit()));
    connect(listview_, SIGNAL(executed(QListViewItem *)), this, SLOT(gotoSymbol(QListViewItem *)));
    connect(listview_, SIGNAL(returnPressed(QListViewItem *)), this, SLOT(gotoSymbol(QListViewItem *)));
    connect(listview_, SIGNAL(spacePressed(QListViewItem *)), this, SLOT(gotoSymbol(QListViewItem *)));
    connect(win->viewManager(), SIGNAL(viewChanged()), this, SLOT(viewChanged()));
}

//=================================================================================================
KatePluginSeatdView::~KatePluginSeatdView()
{
    win->guiFactory()->removeClient(this);
    delete dock_;
}

//=================================================================================================
void KatePluginSeatdView::searchSubmit()
{
    const int iend = listview_->childCount()-1;
    for ( int i = 0; i < iend; ++i )
    {
        QListViewItem* item = listview_->itemAtIndex(i);
        if ( item->isVisible() ) {
            gotoSymbol(item);
            break;
        }
    }
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
            listDeclarations(false);
            break;
        case modules:
            listModules(false);
            break;
    }
}

//=================================================================================================
void KatePluginSeatdView::toggleSearchFocus()
{
    if ( search_input_->hasFocus() )
    {
        Kate::View* view = win->viewManager()->activeView();
        if ( view )
            view->setFocus();
    }
    else
        search_input_->setFocus();
}

//=================================================================================================
void KatePluginSeatdView::listModules(bool focus_search)
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;

    const char**    entries;
    size_t          count;
    seatdListModules(seatd_, (const char*)doc->text(), doc->text().length(), &entries, &count);

    listview_->clear();
    search_input_->clear();
    for ( int i = 0; i < count; ++i )
        new QListViewItem(listview_, listview_->lastItem(), entries[i]);
    seatdFreeList(entries);

    list_type_ = modules;

    if ( focus_search )
        toggleSearchFocus();
}

//=================================================================================================
void KatePluginSeatdView::listDeclarations(bool focus_search)
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;

    const char**    entries;
    size_t          count;
    seatdListDeclarations(seatd_, (const char*)doc->text(), doc->text().length(), &entries, &count);

    listview_->clear();
    search_input_->clear();
    for ( int i = 0; i < count; ++i )
        new QListViewItem(listview_, listview_->lastItem(), entries[i]);
    seatdFreeList(entries);

    list_type_ = decls;

    if ( focus_search )
        toggleSearchFocus();
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
    Kate::View* view = win->viewManager()->activeView();
    if ( view )
        view->setFocus();
}

//=================================================================================================
void SeatdSearchLine::activateSearch()
{
    KListViewSearchLine::activateSearch();
    
    const int iend = listView()->childCount()-1;
    for ( int i = 0; i < iend; ++i )
    {
        QListViewItem* item = listView()->itemAtIndex(i);
        if ( item->isVisible() ) {
            listView()->setSelected(item, true);
            break;
        }
    }
}

//=================================================================================================
void SeatdSearchLine::keyPressEvent(QKeyEvent* e)
{
    switch ( e->key() )
    {
        case Qt::Key_Down:
            {
                const int iend = listView()->childCount();
                for ( int j = 0, i = 0; i < iend; ++i )
                {
                    QListViewItem* item = listView()->itemAtIndex(i);
                    if ( item->isVisible() )
                    {
                        if ( j <= 0 ) {
                            ++j;
                            continue;
                        }
                        listView()->setSelected(item, true);
                        break;
                    }
                }
                listView()->setFocus();
            }
            break;
        case Qt::Key_Up:
            for ( int i = listView()->childCount()-1; i >= 0; --i )
            {
                QListViewItem* item = listView()->itemAtIndex(i);
                if ( item->isVisible() ) {
                    listView()->setSelected(item, true);
                    break;
                }
            }
            listView()->setFocus();
            break;
        case Qt::Key_Escape:
            {
                Kate::View* view = win->viewManager()->activeView();
                if ( view )
                    view->setFocus();
            }
            break;
        default:
            KListViewSearchLine::keyPressEvent(e);
            break;
    }
}
