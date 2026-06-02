TARGET = harbour-vikunja

CONFIG += sailfishapp link_pkgconfig
QT += network
PKGCONFIG += sailfishapp sailfishsecrets

CONFIG(release, debug|release): DEFINES += QT_NO_DEBUG_OUTPUT

SOURCES += src/main.cpp \
    src/settingsmanager.cpp \
    src/vikunjaapi.cpp \
    src/taskmodel.cpp

HEADERS += \
    src/settingsmanager.h \
    src/vikunjaapi.h \
    src/taskmodel.h

icons.files = icons/cover-icon.png
icons.path = $$PREFIX/share/$${TARGET}/icons
INSTALLS += icons

DISTFILES += qml/harbour-vikunja.qml \
    qml/components/SilicaTaskDelegate.qml \
    qml/cover/CoverPage.qml \
    qml/pages/LoginPage.qml \
    qml/pages/TaskOverviewPage.qml \
    qml/pages/TaskDetailPage.qml \
    qml/pages/AddEditTaskDialog.qml \
    qml/pages/SelectLabelsPage.qml \
    icons/cover-icon.png \
    rpm/harbour-vikunja.spec \
    translations/*.ts \
    harbour-vikunja.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n sailfishapp_i18n_idbased

TRANSLATIONS += translations/harbour-vikunja.ts \
                translations/harbour-vikunja-en.ts

lupdate_only {
    SOURCES += qml/*.qml \
               qml/pages/*.qml \
               qml/cover/*.qml \
               qml/components/*.qml
}
