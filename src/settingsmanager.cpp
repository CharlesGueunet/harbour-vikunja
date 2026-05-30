#include "settingsmanager.h"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <Sailfish/Secrets/secretmanager.h>
#include <Sailfish/Secrets/secret.h>
#include <Sailfish/Secrets/storesecretrequest.h>
#include <Sailfish/Secrets/storedsecretrequest.h>
#include <Sailfish/Secrets/deletesecretrequest.h>

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
    , m_secretManager(new Sailfish::Secrets::SecretManager(this))
{
    // Fix Sandboxing: Use QStandardPaths to locate AppConfigLocation which is writable in Sailjail
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir().mkpath(configDir);
    m_settings = new QSettings(configDir + QStringLiteral("/settings.ini"), QSettings::IniFormat, this);

    // Load initial values from settings fallback
    m_serverUrl = m_settings->value(QStringLiteral("serverUrl"), QString()).toString();
    m_apiToken = m_settings->value(QStringLiteral("apiToken"), QString()).toString();

    // Fetch secure storage values asynchronously
    fetchSecrets();
}

QString SettingsManager::serverUrl() const
{
    return m_serverUrl;
}

void SettingsManager::setServerUrl(const QString &url)
{
    if (m_serverUrl != url) {
        m_serverUrl = url;
        m_settings->setValue(QStringLiteral("serverUrl"), url);
        m_settings->sync();
        storeSecret(QStringLiteral("VikunjaServerUrl"), url);
        emit serverUrlChanged();
    }
}

QString SettingsManager::apiToken() const
{
    return m_apiToken;
}

void SettingsManager::setApiToken(const QString &token)
{
    if (m_apiToken != token) {
        m_apiToken = token;
        m_settings->setValue(QStringLiteral("apiToken"), token);
        m_settings->sync();
        storeSecret(QStringLiteral("VikunjaApiToken"), token);
        emit apiTokenChanged();
    }
}

void SettingsManager::clear()
{
    m_serverUrl.clear();
    m_apiToken.clear();
    m_settings->clear();
    m_settings->sync();

    deleteSecret(QStringLiteral("VikunjaServerUrl"));
    deleteSecret(QStringLiteral("VikunjaApiToken"));

    emit serverUrlChanged();
    emit apiTokenChanged();
}

void SettingsManager::fetchSecrets()
{
    // Fetch Server URL
    auto urlReq = new Sailfish::Secrets::StoredSecretRequest(this);
    urlReq->setManager(m_secretManager);
    urlReq->setIdentifier(Sailfish::Secrets::Secret::Identifier(QStringLiteral("VikunjaServerUrl"), QString(), Sailfish::Secrets::SecretManager::DefaultStoragePluginName));
    urlReq->setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
    connect(urlReq, &Sailfish::Secrets::StoredSecretRequest::statusChanged, this, [this, urlReq]() {
        if (urlReq->status() == Sailfish::Secrets::Request::Finished) {
            if (urlReq->result().code() == Sailfish::Secrets::Result::Succeeded && !urlReq->secret().data().isEmpty()) {
                QString val = QString::fromUtf8(urlReq->secret().data());
                if (m_serverUrl != val) {
                    m_serverUrl = val;
                    emit serverUrlChanged();
                }
            }
            urlReq->deleteLater();
        }
    });
    urlReq->startRequest();

    // Fetch API Token
    auto tokenReq = new Sailfish::Secrets::StoredSecretRequest(this);
    tokenReq->setManager(m_secretManager);
    tokenReq->setIdentifier(Sailfish::Secrets::Secret::Identifier(QStringLiteral("VikunjaApiToken"), QString(), Sailfish::Secrets::SecretManager::DefaultStoragePluginName));
    tokenReq->setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
    connect(tokenReq, &Sailfish::Secrets::StoredSecretRequest::statusChanged, this, [this, tokenReq]() {
        if (tokenReq->status() == Sailfish::Secrets::Request::Finished) {
            if (tokenReq->result().code() == Sailfish::Secrets::Result::Succeeded && !tokenReq->secret().data().isEmpty()) {
                QString val = QString::fromUtf8(tokenReq->secret().data());
                if (m_apiToken != val) {
                    m_apiToken = val;
                    emit apiTokenChanged();
                }
            }
            tokenReq->deleteLater();
        }
    });
    tokenReq->startRequest();
}

void SettingsManager::storeSecret(const QString &name, const QString &value)
{
    // Delete existing secret first to avoid SQLite unique constraint issues
    auto delReq = new Sailfish::Secrets::DeleteSecretRequest(this);
    delReq->setManager(m_secretManager);
    delReq->setIdentifier(Sailfish::Secrets::Secret::Identifier(name, QString(), Sailfish::Secrets::SecretManager::DefaultStoragePluginName));
    delReq->setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);

    connect(delReq, &Sailfish::Secrets::DeleteSecretRequest::statusChanged, this, [this, name, value, delReq]() {
        if (delReq->status() == Sailfish::Secrets::Request::Finished) {
            delReq->deleteLater();

            // Store new secret value
            Sailfish::Secrets::Secret secret(Sailfish::Secrets::Secret::Identifier(name, QString(), Sailfish::Secrets::SecretManager::DefaultStoragePluginName));
            secret.setData(value.toUtf8());

            auto storeReq = new Sailfish::Secrets::StoreSecretRequest(this);
            storeReq->setManager(m_secretManager);
            storeReq->setSecretStorageType(Sailfish::Secrets::StoreSecretRequest::StandaloneDeviceLockSecret);
            storeReq->setDeviceLockUnlockSemantic(Sailfish::Secrets::SecretManager::DeviceLockKeepUnlocked);
            storeReq->setAccessControlMode(Sailfish::Secrets::SecretManager::OwnerOnlyMode);
            storeReq->setEncryptionPluginName(Sailfish::Secrets::SecretManager::DefaultEncryptionPluginName);
            storeReq->setSecret(secret);
            storeReq->setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);

            connect(storeReq, &Sailfish::Secrets::StoreSecretRequest::statusChanged, this, [storeReq]() {
                if (storeReq->status() == Sailfish::Secrets::Request::Finished) {
                    storeReq->deleteLater();
                }
            });
            storeReq->startRequest();
        }
    });
    delReq->startRequest();
}

void SettingsManager::deleteSecret(const QString &name)
{
    auto delReq = new Sailfish::Secrets::DeleteSecretRequest(this);
    delReq->setManager(m_secretManager);
    delReq->setIdentifier(Sailfish::Secrets::Secret::Identifier(name, QString(), Sailfish::Secrets::SecretManager::DefaultStoragePluginName));
    delReq->setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
    connect(delReq, &Sailfish::Secrets::DeleteSecretRequest::statusChanged, this, [delReq]() {
        if (delReq->status() == Sailfish::Secrets::Request::Finished) {
            delReq->deleteLater();
        }
    });
    delReq->startRequest();
}
