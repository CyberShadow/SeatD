#ifndef _PLUGIN_KATESEATD_H_
#define _PLUGIN_KATESEATD_H_

#include <kate/application.h>
#include <kate/documentmanager.h>
#include <kate/document.h>
#include <kate/mainwindow.h>
#include <kate/plugin.h>
#include <kate/view.h>
#include <kate/viewmanager.h>
#include <kate/toolviewmanager.h>
#include <klistview.h>
#include <klistviewsearchline.h>
#include <qlayout.h>
#include <qwidget.h>

/**************************************************************************************************

**************************************************************************************************/
class SeatdSearchLine : public KListViewSearchLine
{
    Q_OBJECT

public:
    SeatdSearchLine(QWidget* parent, Kate::MainWindow* w) : KListViewSearchLine(parent), win(w) {}
    void selectFirstVisible(QListViewItem* item = 0);
        
protected slots:
    void activateSearch();

protected:
    Kate::MainWindow*   win;

    void keyPressEvent(QKeyEvent* e);
};

/**************************************************************************************************

**************************************************************************************************/
class KatePluginSeatdView : public QObject, public KXMLGUIClient
{
    Q_OBJECT

public:
    Kate::MainWindow*   win;

    KatePluginSeatdView(void* seatd, Kate::MainWindow *w);
    virtual ~KatePluginSeatdView();

    void showSelectionList(const char** entries, size_t count);
    void toggleSearchFocus();
    void populateList(const char** entries, size_t count);
    QString getItemFQN(QListViewItem* item);

public slots:
    void viewChanged();
    void listModules(bool focus_search=true);
    void listDeclarations(bool focus_search=true);
    void gotoSymbol(QListViewItem *);
    void searchSubmit();
    void gotoDeclaration();

private:
    QWidget*            dock_;
    QWidget*            widget_;
    KListView*          listview_;
    QVBoxLayout*        vboxLayout_;
    SeatdSearchLine*    search_input_;

    bool    tree_list_;

    enum ListType {
        none,
        decls,
        modules
    };
    ListType    list_type_;

    void*           seatd_;
};


/**************************************************************************************************

**************************************************************************************************/
class KatePluginSeatd : public Kate::Plugin, Kate::PluginViewInterface
{
    Q_OBJECT

public:
    KatePluginSeatd( QObject* parent = 0, const char* name = 0, const QStringList& = QStringList() );
    virtual ~KatePluginSeatd();

    void addView (Kate::MainWindow *win);
    void removeView (Kate::MainWindow *win);

    void showSelectionList(const char** entries, size_t count);
    void getCursor(unsigned int* line, unsigned int* col);
    void setCursor(unsigned int line, unsigned int col);
    void openFile(const char* filepath);
    void getDocumentVariable(const char* name, const char** str, size_t* len);

public slots:

private:
    void*   seatd_;

    QPtrList<KatePluginSeatdView>   views_;
};

/**************************************************************************************************

**************************************************************************************************/
extern "C"
{
    void* seatdGetInstance(void*);
    bool seatdGotoSymbol(void* plugin, const char*, size_t, const char*, size_t);
    void seatdGotoDeclaration(void* plugin, const char* text, size_t len);
    void seatdGotoModule(void* plugin, const char* text, size_t len);
    void seatdOnChar(void* plugin, char c);
    void seatdSetBufferFile(void* inst, const char* filepath, size_t len);
    void seatdListDeclarations(void* inst, const char* text, size_t len, const char*** entries, size_t* count);
    void seatdListModules(void* inst, const char* text, size_t len, const char*** entries, size_t* count);
    void seatdFreeList(const char** entries);
}

static const char* const class_xpm[] = {
"16 16 10 1",
" 	c None",
".	c #000000",
"+	c #A4E8FC",
"@	c #24D0FC",
"#	c #001CD0",
"$	c #0080E8",
"%	c #C0FFFF",
"&	c #00FFFF",
"*	c #008080",
"=	c #00C0C0",
"     ..         ",
"    .++..       ",
"   .+++@@.      ",
"  .@@@@@#...    ",
"  .$$@@##.%%..  ",
"  .$$$##.%%%&&. ",
"  .$$$#.&&&&&*. ",
"   ...#.==&&**. ",
"   .++..===***. ",
"  .+++@@.==**.  ",
" .@@@@@#..=*.   ",
" .$$@@##. ..    ",
" .$$$###.       ",
" .$$$##.        ",
"  ..$#.         ",
"    ..          "};

#endif
