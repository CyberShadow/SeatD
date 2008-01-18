#ifndef _PLUGIN_KATESEATD_H_
#define _PLUGIN_KATESEATD_H_

#include <kate/application.h>
#include <kate/documentmanager.h>
#include <kate/document.h>
#include <kate/mainwindow.h>
#include <kate/plugin.h>
#include <kate/view.h>
#include <kate/viewmanager.h>

class KatePluginSeatd : public Kate::Plugin, Kate::PluginViewInterface
{
    Q_OBJECT

public:
    KatePluginSeatd( QObject* parent = 0, const char* name = 0, const QStringList& = QStringList() );
    virtual ~KatePluginSeatd();

    void addView (Kate::MainWindow *win);
    void removeView (Kate::MainWindow *win);

    void getBufferText(const char** text, size_t* length);
    void showSelectionList(const char** entries, size_t count);
    void showCallTip(const char** entries, size_t count);
    void getCursor(unsigned int* line, unsigned int* col);
    void setCursor(unsigned int line, unsigned int col);
    void openFile(const char* filepath);

public slots:
    void listModules();
    void listDeclarations();
    void completionAborted();
//    void completionDone();
    void completionDone(KTextEditor::CompletionEntry);
    void filterInsertString(KTextEditor::CompletionEntry*,QString*);
    void viewChanged();

private:
    QPtrList<class PluginView> views_;
    bool    selection_list_active,
            viewChanged_connected;

    void* seatd_;
};


extern "C"
{
    void* seatdGetInstance(void*);
    void seatdListModules(void*);
    void seatdSelectionAborted(void* plugin);
    void seatdSelectionDone(void* plugin, const char* text, size_t len);
    void seatdOnChar(void* plugin, char c);
    void seatdSetBufferFile(void* inst, const char* filepath, size_t len);
    void seatdListDeclarations(void* inst);
}

#endif
