// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QUrl>
#include <QVariantList>
#include <QHash>
#include <functional>

class SubtitleSourceService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool configured READ configured NOTIFY configurationChanged FINAL)
    Q_PROPERTY(bool preparing READ preparing NOTIFY preparingChanged FINAL)
public:
    struct Options {
        QUrl apiBase = QUrl(QStringLiteral("https://api.opensubtitles.com/api/v1/"));
        int timeoutMs = 20000;
        qint64 maxJsonBytes = 2 * 1024 * 1024;
        qint64 maxFileBytes = 16 * 1024 * 1024;
    };
    explicit SubtitleSourceService(QObject* parent = nullptr);
    explicit SubtitleSourceService(const Options& options, QObject* parent = nullptr);
    ~SubtitleSourceService() override;
    void setStorageDirectory(const QString& directory);
    bool configured() const { return !m_apiKey.isEmpty(); }
    bool preparing() const { return m_preparing; }
    Q_INVOKABLE bool setApiKey(const QString& key);
    Q_INVOKABLE quint64 search(const QString& query, const QString& language);
    Q_INVOKABLE void cancelSearch();
    Q_INVOKABLE void resetSession();
    Q_INVOKABLE quint64 prepareRows(const QVariantList& rows);
    Q_INVOKABLE void cancelPreparation();
signals:
    void configurationChanged();
    void preparingChanged();
    void searchFinished(quint64 request, const QVariantMap& result);
    void preparationFinished(quint64 request, const QVariantMap& result);
private:
    struct Record { qint64 id; QString name; };
    using ReplyCallback = std::function<void(const QByteArray&, const QString&)>;
    QNetworkReply* request(const QUrl& url, const QByteArray& body, bool api,
                           qint64 limit, ReplyCallback callback);
    QString networkError(int status, QNetworkReply::NetworkError error) const;
    QVariantList parseSources(const QByteArray& data, QString& error);
    QString cachePath(const Record& record) const;
    QByteArray subtitleText(const QByteArray& bytes) const;
    void downloadNext(quint64 request);
    void finishPreparation(quint64 request, const QString& error = {});
    bool downloadUrlAllowed(const QUrl& url) const;
    Options m_options;
    QNetworkAccessManager m_network;
    QString m_storageDirectory;
    QByteArray m_apiKey;
    QPointer<QNetworkReply> m_searchReply;
    QPointer<QNetworkReply> m_downloadReply;
    quint64 m_searchGeneration = 0;
    quint64 m_prepareGeneration = 0;
    bool m_preparing = false;
    QHash<QString, Record> m_records;
    QVariantList m_rows;
    QStringList m_pending;
    QHash<QString, QString> m_ready;
};
