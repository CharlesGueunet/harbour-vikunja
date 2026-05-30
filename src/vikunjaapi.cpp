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
    qDebug() << "[VikunjaApi] testConnection url=" << url;
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/user"), url, token);
    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        qDebug() << "[VikunjaApi] testConnection response: http=" << httpStatus
                 << "error=" << reply->error() << reply->errorString();
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
    qDebug() << "[VikunjaApi] fetchProjects";
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/projects"));
    qDebug() << "[VikunjaApi] fetchProjects url=" << req.url().toString();
    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        qDebug() << "[VikunjaApi] fetchProjects response: http=" << httpStatus
                 << "error=" << reply->error();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            qDebug() << "[VikunjaApi] fetchProjects data:" << data.left(200);
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isArray()) {
                qDebug() << "[VikunjaApi] fetchProjects count=" << doc.array().size();
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
    qDebug() << "[VikunjaApi] fetchTasks projectId=" << projectId;
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
    qDebug() << "[VikunjaApi] fetchTasks url=" << req.url().toString();

    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, projectId, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        qDebug() << "[VikunjaApi] fetchTasks response: http=" << httpStatus
                 << "error=" << reply->error();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            qDebug() << "[VikunjaApi] fetchTasks data (first 200 bytes):" << data.left(200);
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isArray()) {
                qDebug() << "[VikunjaApi] fetchTasks count=" << doc.array().size();
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
    qDebug() << "[VikunjaApi] createTask projectId=" << projectId
             << "title=" << title
             << "description=" << description
             << "dueDate=" << dueDate;

    if (projectId <= 0) {
        qWarning() << "[VikunjaApi] createTask: invalid projectId=" << projectId;
        emit taskCreated(false, tr("Invalid Project ID"));
        return;
    }

    // Vikunja API: PUT /api/v1/projects/{projectId}/tasks
    QString endpoint = QStringLiteral("api/v1/projects/") + QString::number(projectId) + QStringLiteral("/tasks");
    setBusy(true);
    QNetworkRequest req = createRequest(endpoint);
    qDebug() << "[VikunjaApi] createTask url=" << req.url().toString();

    QJsonObject body;
    body.insert(QStringLiteral("title"), title);
    if (!description.isEmpty()) {
        body.insert(QStringLiteral("description"), description);
    }
    if (!dueDate.isEmpty()) {
        body.insert(QStringLiteral("due_date"), dueDate);
    }

    QByteArray payload = QJsonDocument(body).toJson();
    qDebug() << "[VikunjaApi] createTask payload=" << payload;
    // Vikunja API: PUT /api/v1/projects/{projectId}/tasks
    QNetworkReply *reply = m_nam->put(req, payload);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray responseData = reply->readAll();
        qDebug() << "[VikunjaApi] createTask response: http=" << httpStatus
                 << "error=" << reply->error() << reply->errorString();
        qDebug() << "[VikunjaApi] createTask response body:" << responseData.left(400);
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            emit taskCreated(true, QString());
        } else {
            emit taskCreated(false, reply->errorString());
        }
    });
}

void VikunjaApi::updateTask(int taskId, bool done, const QString &title, const QString &description, const QString &dueDate)
{
    qDebug() << "[VikunjaApi] updateTask taskId=" << taskId
             << "done=" << done
             << "title=" << title
             << "dueDate=" << dueDate;
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/tasks/%1").arg(taskId));
    qDebug() << "[VikunjaApi] updateTask url=" << req.url().toString();

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

    QByteArray payload = QJsonDocument(body).toJson();
    qDebug() << "[VikunjaApi] updateTask payload=" << payload;
    // Vikunja handles task updates via POST to /api/v1/tasks/{id}
    QNetworkReply *reply = m_nam->post(req, payload);

    connect(reply, &QNetworkReply::finished, this, [this, taskId, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray responseData = reply->readAll();
        qDebug() << "[VikunjaApi] updateTask response: http=" << httpStatus
                 << "error=" << reply->error() << reply->errorString();
        qDebug() << "[VikunjaApi] updateTask response body:" << responseData.left(200);
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            emit taskUpdated(taskId, true, QString());
        } else {
            emit taskUpdated(taskId, false, reply->errorString());
        }
    });
}

void VikunjaApi::deleteTask(int taskId)
{
    qDebug() << "[VikunjaApi] deleteTask taskId=" << taskId;
    setBusy(true);
    QNetworkRequest req = createRequest(QStringLiteral("api/v1/tasks/%1").arg(taskId));
    qDebug() << "[VikunjaApi] deleteTask url=" << req.url().toString();
    QNetworkReply *reply = m_nam->deleteResource(req);

    connect(reply, &QNetworkReply::finished, this, [this, taskId, reply]() {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        qDebug() << "[VikunjaApi] deleteTask response: http=" << httpStatus
                 << "error=" << reply->error() << reply->errorString();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() == QNetworkReply::NoError) {
            emit taskDeleted(taskId, true, QString());
        } else {
            emit taskDeleted(taskId, false, reply->errorString());
        }
    });
}
