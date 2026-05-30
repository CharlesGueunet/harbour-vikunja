#include "vikunjaapi.h"
#include <QDebug>
#include <QUrlQuery>

VikunjaApi::VikunjaApi(SettingsManager *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_nam(new QNetworkAccessManager(this))
    , m_busy(false)
{
}

bool VikunjaApi::busy() const
{
    return m_busy;
}

void VikunjaApi::setBusy(bool busy)
{
    if (m_busy != busy) {
        m_busy = busy;
        emit busyChanged();
    }
}

QNetworkRequest VikunjaApi::createRequest(const QString &endpoint, const QString &overrideUrl, const QString &overrideToken)
{
    QString baseUrl = overrideUrl.isEmpty() ? m_settings->serverUrl() : overrideUrl;
    QString token = overrideToken.isEmpty() ? m_settings->apiToken() : overrideToken;

    if (!baseUrl.endsWith(QStringLiteral("/"))) {
        baseUrl += QStringLiteral("/");
    }

    QUrl url(baseUrl + endpoint);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    
    if (!token.isEmpty()) {
        request.setRawHeader("Authorization", "Bearer " + token.toUtf8());
    }

    return request;
}

void VikunjaApi::testConnection(const QString &url, const QString &token)
{
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/user"), url, token);
    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            emit connectionTested(true, QString());
        } else {
            QString errorMsg = reply->errorString();
            if (httpStatus == 401) {
                errorMsg = tr("Unauthorized: Invalid API Token");
            }
            emit connectionTested(false, errorMsg);
        }
    });
}

void VikunjaApi::fetchProjects()
{
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/projects"));
    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isArray()) {
                emit projectsReceived(doc.array());
            } else {
                qWarning() << "[VikunjaApi] fetchProjects: response is not a JSON array";
                emit projectsReceived(QJsonArray());
            }
        } else {
            qWarning() << "[VikunjaApi] fetchProjects failed:" << reply->errorString();
            emit projectsReceived(QJsonArray());
        }
    });
}

void VikunjaApi::fetchTasks(int projectId)
{
    setBusy(true);
    QString endpoint = (projectId > 0)
        ? (QStringLiteral("api/v1/projects/") + QString::number(projectId) + QStringLiteral("/tasks"))
        : QStringLiteral("api/v1/tasks");

    QNetworkRequest req = createRequest(endpoint);

    // Use QUrlQuery to properly encode parameters
    QUrl url = req.url();
    QUrlQuery query;
    // We try to request 1000 tasks max
    query.addQueryItem(QStringLiteral("per_page"), QStringLiteral("1000"));
    // Add the filter for active tasks
    query.addQueryItem(QStringLiteral("filter"), QStringLiteral("done = false"));
    url.setQuery(query);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, projectId, reply]() {
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isArray()) {
                emit tasksReceived(projectId, doc.array());
            } else {
                qWarning() << "[VikunjaApi] fetchTasks: response is not a JSON array";
                emit tasksReceived(projectId, QJsonArray());
            }
        } else {
            qWarning() << "[VikunjaApi] fetchTasks failed:" << reply->errorString();
            emit tasksReceived(projectId, QJsonArray());
        }
    });
}

void VikunjaApi::createTask(int projectId, const QString &title, const QString &description, const QString &dueDate)
{
    if (projectId <= 0) {
        qWarning() << "[VikunjaApi] createTask: invalid projectId=" << projectId;
        emit taskCreated(false, tr("Invalid Project ID"));
        return;
    }

    // Vikunja API: PUT /api/v1/projects/{projectId}/tasks
    QString endpoint = QStringLiteral("api/v1/projects/") + QString::number(projectId) + QStringLiteral("/tasks");
    setBusy(true);
    QNetworkRequest req = createRequest(endpoint);

    QJsonObject body;
    body.insert(QStringLiteral("title"), title);
    if (!description.isEmpty()) {
        body.insert(QStringLiteral("description"), description);
    }
    if (!dueDate.isEmpty()) {
        body.insert(QStringLiteral("due_date"), dueDate);
    }

    QByteArray payload = QJsonDocument(body).toJson();
    QNetworkReply *reply = m_nam->put(req, payload);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            emit taskCreated(true, QString());
        } else {
            qWarning() << "[VikunjaApi] createTask failed: http=" << httpStatus << reply->errorString();
            emit taskCreated(false, reply->errorString());
        }
    });
}

void VikunjaApi::updateTask(int taskId, bool done, const QString &title, const QString &description, const QString &dueDate)
{
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/tasks/%1").arg(taskId));

    QJsonObject body;
    body.insert(QStringLiteral("done"), done);
    if (!title.isEmpty()) {
        body.insert(QStringLiteral("title"), title);
    }
    if (!description.isEmpty()) {
        body.insert(QStringLiteral("description"), description);
    }
    if (!dueDate.isEmpty()) {
        body.insert(QStringLiteral("due_date"), dueDate);
    }

    // Vikunja handles task updates via POST to /api/v1/tasks/{id}
    QNetworkReply *reply = m_nam->post(req, QJsonDocument(body).toJson());

    connect(reply, &QNetworkReply::finished, this, [this, taskId, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            emit taskUpdated(taskId, true, QString());
        } else {
            qWarning() << "[VikunjaApi] updateTask failed: http=" << httpStatus << reply->errorString();
            emit taskUpdated(taskId, false, reply->errorString());
        }
    });
}

void VikunjaApi::deleteTask(int taskId)
{
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/tasks/%1").arg(taskId));
    QNetworkReply *reply = m_nam->deleteResource(req);

    connect(reply, &QNetworkReply::finished, this, [this, taskId, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            emit taskDeleted(taskId, true, QString());
        } else {
            qWarning() << "[VikunjaApi] deleteTask failed: http=" << httpStatus << reply->errorString();
            emit taskDeleted(taskId, false, reply->errorString());
        }
    });
}
