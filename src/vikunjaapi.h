#ifndef VIKUNJAAPI_H
#define VIKUNJAAPI_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include "settingsmanager.h"

class VikunjaApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit VikunjaApi(SettingsManager *settings, QObject *parent = nullptr);

    bool busy() const;

    Q_INVOKABLE void testConnection(const QString &url, const QString &token);
    Q_INVOKABLE void fetchProjects();
    Q_INVOKABLE void fetchTasks(int projectId = -1);
    Q_INVOKABLE void fetchTask(int taskId);
    Q_INVOKABLE void createTask(int projectId, const QString &title, const QString &description = QString(), const QString &dueDate = QString());
    Q_INVOKABLE void updateTask(int taskId, bool done, const QString &title, const QString &description = QString(), const QString &dueDate = QString());
    Q_INVOKABLE void deleteTask(int taskId);
    Q_INVOKABLE void fetchLabels();
    Q_INVOKABLE void associateLabel(int taskId, int labelId);
    Q_INVOKABLE void dissociateLabel(int taskId, int labelId);

signals:
    void busyChanged();
    void connectionTested(bool success, const QString &errorMessage);
    void projectsReceived(const QJsonArray &projects);
    void tasksReceived(int projectId, const QJsonArray &tasks);
    void taskReceived(int taskId, const QJsonObject &task);
    void taskCreated(bool success, const QString &errorMsg);
    void taskUpdated(int taskId, bool success, const QString &errorMsg);
    void taskDeleted(int taskId, bool success, const QString &errorMsg);
    void labelsReceived(const QJsonArray &labels);
    void labelAssociated(int taskId, int labelId, bool success, const QString &errorMsg);
    void labelDissociated(int taskId, int labelId, bool success, const QString &errorMsg);

private:
    QNetworkRequest createRequest(const QString &endpoint, const QString &overrideUrl = QString(), const QString &overrideToken = QString());
    void setBusy(bool busy);

    SettingsManager *m_settings;
    QNetworkAccessManager *m_nam;
    bool m_busy;
};

#endif // VIKUNJAAPI_H
