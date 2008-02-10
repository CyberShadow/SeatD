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
    connect(application()->documentManager(), SIGNAL(documentChanged()), view, SLOT(documentChanged()));
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
KatePluginSeatdView::KatePluginSeatdView(void* seatd, Kate::MainWindow *w)
    : seatd_(seatd), win(w), list_type_(none), tree_list_(false), hide_doc_on_defocus_(false)
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
             
    new KAction(
        i18n("Goto Declaration"), 0, this,
        SLOT( gotoDeclaration() ), actionCollection(),
        "view_goto_declaration"
    );
             
    new KAction(
        i18n("Goto Previous Location"), 0, this,
        SLOT( gotoPrevious() ), actionCollection(),
        "view_goto_previous"
    );
             
    new KAction(
        i18n("Goto Next Location"), 0, this,
        SLOT( gotoNext() ), actionCollection(),
        "view_goto_next"
    );
             
    new KAction(
        i18n("Duplicate Selection or Line"), 0, this,
        SLOT( duplicateSelection() ), actionCollection(),
        "edit_duplicate"
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
    listview_->setSorting(0);

    connect(search_input_, SIGNAL(returnPressed()), this, SLOT(searchSubmit()));
    connect(listview_, SIGNAL(executed(QListViewItem *)), this, SLOT(gotoSymbol(QListViewItem *)));
    connect(listview_, SIGNAL(returnPressed(QListViewItem *)), this, SLOT(gotoSymbol(QListViewItem *)));
    connect(listview_, SIGNAL(spacePressed(QListViewItem *)), this, SLOT(gotoSymbol(QListViewItem *)));
}

//=================================================================================================
KatePluginSeatdView::~KatePluginSeatdView()
{
    win->guiFactory()->removeClient(this);
    delete dock_;
}

//=================================================================================================
void KatePluginSeatdView::documentModified()
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;
    printf("documentChanged %s\n", (const char*)doc->url().path());
    seatdMarkModuleDirty(seatd_, (const char*)doc->url().path(), doc->url().path().length());
}

//=================================================================================================
void KatePluginSeatdView::duplicateSelection()
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;

    unsigned int line, col;
    view->cursorPositionReal(&line, &col);
    // TODO: how to insert text without moving the cursor? messes with undo...
    if ( doc->hasSelection() ) {
        QString text = doc->selection();
        doc->insertText(line, col, text);
    }
    else {
        QString text = doc->textLine(line);
        doc->insertLine(line, text);
    }
    view->setCursorPositionReal(line, col);
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
void KatePluginSeatdView::documentChanged()
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;
    seatdSetBufferFile(seatd_, (const char*)doc->url().path(), doc->url().path().length());
    listview_->clear();
/*
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
*/
}

//=================================================================================================
void KatePluginSeatdView::gotoDeclaration()
{
    Kate::View* view = win->viewManager()->activeView();
    if ( !view )
        return;
    Kate::Document* doc = view->getDoc();
    if ( !doc )
        return;

    bool found = seatdGotoSymbol(
        seatd_, (const char*)doc->text(), doc->text().length(),
        view->currentWord(), view->currentWord().length()
    );
    if ( !found ) {
        QStringList entries("Symbol not found");
        view->showArgHint(entries, "", "");
    }
}

//=================================================================================================
void KatePluginSeatdView::gotoPrevious()
{
    seatdGotoPrevious(seatd_);
}

//=================================================================================================
void KatePluginSeatdView::gotoNext()
{
    seatdGotoNext(seatd_);
}

//=================================================================================================
void KatePluginSeatdView::listModules(bool manual_invoke)
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

    populateList(entries, count);
    search_input_->updateSearch();
    search_input_->selectAll();
    search_input_->selectFirstVisible();

    list_type_ = modules;

    if ( manual_invoke )
    {
        if ( !dock_->isVisible() ) {
            hide_doc_on_defocus_ = true;
            win->toolViewManager()->showToolView(dock_);
        }
        search_input_->setFocus();
    }
}

//=================================================================================================
void KatePluginSeatdView::listDeclarations(bool manual_invoke)
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

    populateList(entries, count);
    search_input_->updateSearch();
    search_input_->selectAll();
    search_input_->selectFirstVisible();

    list_type_ = decls;

    if ( manual_invoke )
    {
        if ( !dock_->isVisible() ) {
            hide_doc_on_defocus_ = true;
            win->toolViewManager()->showToolView(dock_);
        }
        search_input_->setFocus();
    }
}

//=================================================================================================
void KatePluginSeatdView::populateList(const char** entries, size_t count)
{
    listview_->clear();
    if ( tree_list_ )
    {
        for ( int i = 0; i < count; ++i )
        {
            QStringList nodes = QStringList::split('.', entries[i]);
            
            QListViewItem* parent = 0;
            QListViewItem* n;

            const int jend = nodes.size();
            for ( int j = 0; j < jend; ++j, parent = n )
            {
                n = listview_->findItem(nodes[j], 0);
                if ( !n )
                {
                    if ( !parent ) {
                        parent = new QListViewItem(listview_, nodes[j++]);
                        parent->setOpen(true);
                    }
                    for ( ; j < jend; ++j ) {
                        parent = new QListViewItem(parent, nodes[j]);
                        parent->setOpen(true);
                    }
                    break;
                }
            }
        }
    }
    else
    {
        for ( int i = 0; i < count; ++i ) {
            new QListViewItem(listview_, listview_->lastItem(), entries[i]);
        }
    }
    seatdFreeList(entries);
}

//=================================================================================================
QString KatePluginSeatdView::getItemFQN(QListViewItem* item)
{
    QString name = item->text(0);
    
    if ( tree_list_ )
    {
        for ( item = item->parent(); item; item = item->parent() )
            name = item->text(0)+"."+name;
    }
    
    return name;
}

//=================================================================================================
void KatePluginSeatdView::gotoSymbol(QListViewItem* item)
{
    switch ( list_type_ )
    {
        case decls:
            {
                QString name = getItemFQN(item);
                seatdGotoDeclaration(seatd_, name, name.length());
            }
            break;
        case modules:
            {
                QString name = getItemFQN(item);
                seatdGotoModule(seatd_, name, name.length());
            }
            break;
        default:
            break;
    }

    if ( hide_doc_on_defocus_ ) {
        hide_doc_on_defocus_ = false;
        win->toolViewManager()->hideToolView(dock_);
    }
    
    Kate::View* view = win->viewManager()->activeView();
    if ( view )
        view->setFocus();
}

//=================================================================================================
void SeatdSearchLine::activateSearch()
{
    KListViewSearchLine::activateSearch();
    selectFirstVisible(listView()->selectedItem());
}

//=================================================================================================
void SeatdSearchLine::selectFirstVisible(QListViewItem* item)
{
    if ( !item )
        item = listView()->firstChild();
        
    for ( ; item; item = item->itemBelow() )
    {
        if ( item->isVisible() ) {
            listView()->setSelected(item, true);
            break;
        }
    }
    listView()->update();
}

//=================================================================================================
void SeatdSearchLine::keyPressEvent(QKeyEvent* e)
{
    switch ( e->key() )
    {
        case Qt::Key_Down:
            {
                QListViewItem* item = listView()->selectedItem();
                if ( item )
                    item = item->itemBelow();
                if ( !item )
                    item = listView()->firstChild();
                if ( item && item->isVisible() )
                    listView()->setSelected(item, true);
                
                for ( ; item; item = item->itemBelow() )
                {
                    if ( item->isVisible() ) {
                        listView()->setSelected(item, true);
                        break;
                    }
                }
                listView()->setFocus();
            }
            break;
        case Qt::Key_Up:
            {
                QListViewItem* item = listView()->selectedItem();
                if ( item )
                    item = item->itemAbove();
                if ( !item )
                    item = listView()->lastItem();
                if ( item && item->isVisible() )
                    listView()->setSelected(item, true);

                for ( ; item; item = item->itemAbove() )
                {
                    if ( item->isVisible() ) {
                        listView()->setSelected(item, true);
                        break;
                    }
                }
                listView()->setFocus();
            }
            break;
        case Qt::Key_Escape:
            {
/*                if ( hide_doc_on_defocus_ ) {
                    hide_doc_on_defocus_ = false;
                    win->toolViewManager()->hideToolView(dock_);
                }
*/
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
