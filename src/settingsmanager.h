#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QSettings>

namespace Sailfish {
namespace Secrets {
class SecretManager;
}
}

class SettingsManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QString apiToken READ apiToken WRITE setApiToken NOTIFY apiTokenChanged)

public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString serverUrl() const;
    void setServerUrl(const QString &url);

    QString apiToken() const;
    void setApiToken(const QString &token);

    Q_INVOKABLE void clear();

signals:
    void serverUrlChanged();
    void apiTokenChanged();

private:
    void fetchSecrets();
    void storeSecret(const QString &name, const QString &value);
    void deleteSecret(const QString &name);

    QSettings *m_settings;
    QString m_serverUrl;
    QString m_apiToken;
    Sailfish::Secrets::SecretManager *m_secretManager;
};

#endif // SETTINGSMANAGER_H
