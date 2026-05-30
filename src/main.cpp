#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTranslator>
#include <QLoggingCategory>
#include <cstdio>
#include "settingsmanager.h"
#include "vikunjaapi.h"
#include "taskmodel.h"

// Custom message handler: routes all Qt log messages to stderr so they
// appear in journald regardless of release-build optimisations.
static void vikunjaMessageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &msg)
{
    Q_UNUSED(ctx)
    const char *level = "[D]";
    switch (type) {
    case QtWarningMsg:  level = "[W]"; break;
    case QtCriticalMsg: level = "[C]"; break;
    case QtFatalMsg:    level = "[F]"; break;
    default: break;
    }
    fprintf(stderr, "%s %s\n", level, qPrintable(msg));
    fflush(stderr);
}

int main(int argc, char *argv[])
{
    // Enable all debug categories before QGuiApplication is constructed
    // so that qDebug() calls are never silenced in release builds.
    qputenv("QT_LOGGING_RULES", "*.debug=true");
    qInstallMessageHandler(vikunjaMessageHandler);

    QGuiApplication *app = SailfishApp::application(argc, argv);
    app->setOrganizationName("mezmerize");
    app->setApplicationName("harbour-vikunja");

    QQuickView *view = SailfishApp::createView();

    SettingsManager *settingsManager = new SettingsManager(app);
    VikunjaApi *vikunjaApi = new VikunjaApi(settingsManager, app);
    TaskModel *taskModel = new TaskModel(app);

    // Translations
    QTranslator *translator = new QTranslator(app);
    const QString translationsDir = SailfishApp::pathTo("translations").toLocalFile();
    if (!translator->load(QLocale::system(), QStringLiteral("harbour-vikunja"), QStringLiteral("-"), translationsDir)) {
        translator->load(QStringLiteral("harbour-vikunja-en"), translationsDir);
    }
    app->installTranslator(translator);

    // Connect Vikunja API task receipts to local task model
    QObject::connect(vikunjaApi, &VikunjaApi::tasksReceived, [taskModel](int projectId, const QJsonArray &tasks) {
        Q_UNUSED(projectId)
        taskModel->loadTasks(tasks);
    });

    QObject::connect(vikunjaApi, &VikunjaApi::taskUpdated, [taskModel](int taskId, bool success, const QString &errorMsg) {
        Q_UNUSED(errorMsg)
        if (success) {
            // Task status update has been confirmed by server, but usually we reactively reload
            // Or we toggle it locally for instant responsiveness
        }
    });

    QObject::connect(vikunjaApi, &VikunjaApi::taskDeleted, [taskModel](int taskId, bool success, const QString &errorMsg) {
        Q_UNUSED(errorMsg)
        if (success) {
            taskModel->removeTask(taskId);
        }
    });

    view->rootContext()->setContextProperty(QStringLiteral("settingsManager"), settingsManager);
    view->rootContext()->setContextProperty(QStringLiteral("vikunjaApi"), vikunjaApi);
    view->rootContext()->setContextProperty(QStringLiteral("taskModel"), taskModel);

    view->setSource(SailfishApp::pathTo("qml/harbour-vikunja.qml"));
    view->show();

    return app->exec();
}
