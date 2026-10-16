// SPDX-License-Identifier: GPL-2.0-or-later
#include "subtitle_source_service.hpp"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QSet>
#include <QStringDecoder>
#include <QTimer>
#include <QUrlQuery>
#include <memory>
#include <algorithm>

namespace {
QString safeName(QString name)
{
    name.replace('\\', '/'); name = QFileInfo(name).fileName();
    name.replace(QRegularExpression(QStringLiteral("[<>:\"/\\\\|?*\\x00-\\x1f]")), QStringLiteral("_"));
    while (name.endsWith('.') || name.endsWith(' ')) name.chop(1);
    name = QFileInfo(name).completeBaseName().left(96);
    if (name.isEmpty() || name == "." || name == "..") name = QStringLiteral("subtitle");
    return name + QStringLiteral(".srt");
}
QString sourceUrl(qint64 id, const QString& name)
{
    QUrl url; url.setScheme(QStringLiteral("opensubtitles"));
    url.setPath(QStringLiteral("/%1/%2").arg(id).arg(name));
    return url.toString(QUrl::FullyEncoded);
}
}

SubtitleSourceService::SubtitleSourceService(QObject* parent)
    : SubtitleSourceService(Options{}, parent) {}

SubtitleSourceService::SubtitleSourceService(const Options& options, QObject* parent)
    : QObject(parent), m_options(options), m_network(this) {}

SubtitleSourceService::~SubtitleSourceService()
{
    for (auto* reply : m_network.findChildren<QNetworkReply*>()) {
        disconnect(reply, nullptr, this, nullptr); reply->abort();
    }
}

void SubtitleSourceService::setStorageDirectory(const QString& directory)
{
    cancelSearch(); cancelPreparation();
    m_storageDirectory = QFileInfo(directory).isAbsolute() ? directory : QString();
    m_apiKey.clear();
    if (!m_storageDirectory.isEmpty()) {
        QSettings settings(QDir(directory).filePath(QStringLiteral("source-settings.ini")), QSettings::IniFormat);
        const auto key = settings.value(QStringLiteral("OpenSubtitles/api-key")).toByteArray();
        const bool valid = !key.isEmpty() && std::all_of(key.cbegin(), key.cend(), [](unsigned char ch) { return ch >= 0x21 && ch <= 0x7e; });
        if (valid) m_apiKey = key;
    }
    emit configurationChanged();
}

bool SubtitleSourceService::setApiKey(const QString& value)
{
    const auto text = value.trimmed();
    const auto key = text.toLatin1();
    if (text != QString::fromLatin1(key) || key.isEmpty() || key.size() > 512 || m_storageDirectory.isEmpty() || m_preparing) return false;
    for (const char ch : key) if (static_cast<unsigned char>(ch) < 0x21 || ch > 0x7e) return false;
    if (!QDir().mkpath(m_storageDirectory)) return false;
    const auto path = QDir(m_storageDirectory).filePath(QStringLiteral("source-settings.ini"));
    // Create the configuration with owner permissions before QSettings writes the key.
    if (!QFileInfo::exists(path)) {
        QSaveFile file(path);
        if (!file.open(QIODevice::WriteOnly)) return false;
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
        if (!file.commit()) return false;
    }
    QSettings settings(path, QSettings::IniFormat);
    settings.setValue(QStringLiteral("OpenSubtitles/api-key"), key); settings.sync();
    if (settings.status() != QSettings::NoError) return false;
    QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner);
    cancelSearch(); m_apiKey = key; emit configurationChanged(); return true;
}

QString SubtitleSourceService::networkError(int status, QNetworkReply::NetworkError error) const
{
    if (status == 401 || status == 403) return tr("OpenSubtitles rejected the API key. Open setup and check it.");
    if (status == 406 || status == 429) return tr("OpenSubtitles cannot download more files now. Try again later.");
    if (status >= 400) return tr("The subtitle server could not complete this request. Try again.");
    if (error != QNetworkReply::NoError) return tr("VLC could not connect to the subtitle server. Try again.");
    if (status >= 300) return tr("The subtitle server returned an invalid response. Try again.");
    return {};
}

QNetworkReply* SubtitleSourceService::request(const QUrl& url, const QByteArray& body,
                                              bool api, qint64 limit, ReplyCallback callback)
{
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "VLC-Juxtopposed v4.0");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
        api ? QNetworkRequest::ManualRedirectPolicy : QNetworkRequest::NoLessSafeRedirectPolicy);
    if (api) {
        request.setRawHeader("Api-Key", m_apiKey);
        request.setRawHeader("Accept", "application/json");
        if (!body.isEmpty()) request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    }
    auto* reply = body.isEmpty() ? m_network.get(request) : m_network.post(request, body);
    struct State { QByteArray bytes; bool tooLarge = false; bool timedOut = false; };
    auto state = std::make_shared<State>();
    auto* timer = new QTimer(reply); timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, this, [reply, state] { state->timedOut = true; reply->abort(); });
    connect(reply, &QNetworkReply::readyRead, this, [reply, state, limit] {
        state->bytes.append(reply->readAll());
        if (state->bytes.size() > limit) { state->tooLarge = true; reply->abort(); }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, state, timer, limit, callback = std::move(callback)] {
        timer->stop(); if (reply->isReadable()) state->bytes.append(reply->readAll());
        const auto error = state->tooLarge || state->bytes.size() > limit ? tr("This subtitle response is too large.")
            : state->timedOut ? tr("The subtitle request took too long. Try again.")
            : networkError(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), reply->error());
        reply->deleteLater(); callback(state->bytes, error);
    });
    timer->start(m_options.timeoutMs); return reply;
}

void SubtitleSourceService::cancelSearch()
{
    ++m_searchGeneration;
    if (m_searchReply) m_searchReply->abort();
    m_searchReply = nullptr;
}

QVariantList SubtitleSourceService::parseSources(const QByteArray& bytes, QString& error)
{
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    if (parse.error != QJsonParseError::NoError || !document.isObject() || !document.object().value("data").isArray()) {
        error = tr("OpenSubtitles returned an invalid response. Try again."); return {};
    }
    QVariantList sources; QSet<qint64> seen;
    for (const auto& entry : document.object().value("data").toArray()) {
        const auto attributes = entry.toObject().value("attributes").toObject();
        for (const auto& value : attributes.value("files").toArray()) {
            const auto file = value.toObject();
            const auto id = file.value("file_id").toInteger();
            if (id <= 0 || seen.contains(id)) continue;
            const auto name = safeName(file.value("file_name").toString(attributes.value("release").toString()));
            const auto url = sourceUrl(id, name); seen.insert(id); m_records.insert(url, {id, name});
            sources.append(QVariantMap{{"url", url}, {"name", name},
                {"language", attributes.value("language").toString()},
                {"release", attributes.value("release").toString()},
                {"hearingImpaired", attributes.value("hearing_impaired").toBool()},
                {"forced", attributes.value("foreign_parts_only").toBool()}});
            if (sources.size() >= 500) return sources;
        }
    }
    return sources;
}

quint64 SubtitleSourceService::search(const QString& text, const QString& language)
{
    cancelSearch(); const auto generation = m_searchGeneration;
    const auto query = text.trimmed();
    static const QRegularExpression code(QStringLiteral("^[a-z]{2,3}(?:-[a-z]{2,3})?$"));
    if (!configured() || query.isEmpty() || query.size() > 512 || (!language.isEmpty() && !code.match(language).hasMatch())) {
        const auto error = !configured() ? tr("OpenSubtitles is not set up. Add an API key to use this source.")
                                        : tr("Enter a title and select a subtitle language.");
        QTimer::singleShot(0, this, [this, generation, error] {
            if (generation == m_searchGeneration) emit searchFinished(generation, {{"success", false}, {"error", error}});
        }); return generation;
    }
    auto url = m_options.apiBase.resolved(QUrl(QStringLiteral("subtitles")));
    QUrlQuery parameters; parameters.addQueryItem(QStringLiteral("query"), query);
    if (!language.isEmpty()) parameters.addQueryItem(QStringLiteral("languages"), language);
    url.setQuery(parameters);
    m_searchReply = request(url, {}, true, m_options.maxJsonBytes,
        [this, generation](const QByteArray& bytes, QString error) {
            if (generation != m_searchGeneration) return;
            m_searchReply = nullptr;
            auto sources = error.isEmpty() ? parseSources(bytes, error) : QVariantList{};
            emit searchFinished(generation, {{"success", error.isEmpty()}, {"error", error}, {"sources", sources}});
        });
    return generation;
}

QString SubtitleSourceService::cachePath(const Record& record) const
{
    return QDir(m_storageDirectory).filePath(QStringLiteral("opensubtitles/%1/%2").arg(record.id).arg(record.name));
}

QByteArray SubtitleSourceService::subtitleText(const QByteArray& bytes) const
{
    const auto encoding = QStringConverter::encodingForData(bytes).value_or(QStringConverter::Utf8);
    QStringDecoder decode(encoding); const QString text = decode(bytes);
    if (decode.hasError() || text.contains(QChar::Null)) return {};
    static const QRegularExpression timing(QStringLiteral(
        "^\\s*\\d{1,3}:[0-5]\\d:[0-5]\\d[,.]\\d{3}\\s*-->\\s*\\d{1,3}:[0-5]\\d:[0-5]\\d[,.]\\d{3}"),
        QRegularExpression::MultilineOption);
    if (!timing.match(text).hasMatch()) return {};
    return text.toUtf8();
}

bool SubtitleSourceService::downloadUrlAllowed(const QUrl& url) const
{
    if (!url.isValid() || url.host().isEmpty() || !url.userInfo().isEmpty()) return false;
    if (url.scheme() == "https") return true;
    // A local HTTP endpoint lets the same client run against a controlled test server.
    return m_options.apiBase.scheme() == "http" && url.scheme() == "http"
        && url.host() == m_options.apiBase.host() && url.port() == m_options.apiBase.port()
        && (url.host() == "127.0.0.1" || url.host() == "localhost" || url.host() == "::1");
}

void SubtitleSourceService::cancelPreparation()
{
    ++m_prepareGeneration;
    if (m_downloadReply) m_downloadReply->abort();
    m_downloadReply = nullptr;
    const bool preparing = m_preparing; m_preparing = false;
    m_pending.clear(); m_rows.clear(); m_ready.clear();
    if (preparing) emit preparingChanged();
}

void SubtitleSourceService::resetSession()
{
    cancelSearch(); cancelPreparation(); m_records.clear();
}

quint64 SubtitleSourceService::prepareRows(const QVariantList& rows)
{
    cancelPreparation(); const auto generation = m_prepareGeneration;
    m_rows = rows; m_preparing = true; emit preparingChanged();
    for (const auto& item : rows) for (const auto& value : item.toMap().value("tracks").toList()) {
        const auto url = value.toUrl();
        if (url.scheme() == "opensubtitles" && !m_pending.contains(url.toString(QUrl::FullyEncoded)))
            m_pending.append(url.toString(QUrl::FullyEncoded));
    }
    QTimer::singleShot(0, this, [this, generation] { downloadNext(generation); });
    return generation;
}

void SubtitleSourceService::downloadNext(quint64 generation)
{
    if (generation != m_prepareGeneration || !m_preparing) return;
    if (m_pending.isEmpty()) { finishPreparation(generation); return; }
    const auto source = m_pending.first();
    const auto record = m_records.constFind(source);
    if (record == m_records.cend() || !configured() || m_storageDirectory.isEmpty()) {
        finishPreparation(generation, tr("Search for these subtitles again before Save.")); return;
    }
    const auto path = cachePath(*record);
    QFile cached(path);
    if (cached.size() <= m_options.maxFileBytes && cached.open(QIODevice::ReadOnly) && !subtitleText(cached.readAll()).isEmpty()) {
        m_ready.insert(source, QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded));
        m_pending.removeFirst(); QTimer::singleShot(0, this, [this, generation] { downloadNext(generation); }); return;
    }
    const auto body = QJsonDocument(QJsonObject{{"file_id", record->id}, {"sub_format", "srt"}}).toJson(QJsonDocument::Compact);
    m_downloadReply = request(m_options.apiBase.resolved(QUrl(QStringLiteral("download"))), body, true,
        m_options.maxJsonBytes, [this, generation, source, path](const QByteArray& bytes, QString error) {
            if (generation != m_prepareGeneration) return;
            if (!error.isEmpty()) { finishPreparation(generation, error); return; }
            const auto document = QJsonDocument::fromJson(bytes);
            const QUrl link(document.object().value("link").toString());
            if (!downloadUrlAllowed(link)) { finishPreparation(generation, tr("The subtitle server returned an invalid download link.")); return; }
            // The temporary file link receives no API key or account credentials.
            m_downloadReply = request(link, {}, false, m_options.maxFileBytes,
                [this, generation, source, path](const QByteArray& data, QString error) {
                    if (generation != m_prepareGeneration) return;
                    if (!error.isEmpty()) { finishPreparation(generation, error); return; }
                    const auto text = subtitleText(data);
                    if (text.isEmpty()) { finishPreparation(generation, tr("This download does not contain valid subtitles.")); return; }
                    if (!QDir().mkpath(QFileInfo(path).absolutePath())) {
                        finishPreparation(generation, tr("VLC could not create the subtitle folder.")); return;
                    }
                    QSaveFile output(path);
                    if (!output.open(QIODevice::WriteOnly)) { finishPreparation(generation, tr("VLC could not save these subtitles.")); return; }
                    output.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
                    if (output.write(text) != text.size() || !output.commit()) {
                        finishPreparation(generation, tr("VLC could not save these subtitles.")); return;
                    }
                    m_ready.insert(source, QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded)); m_pending.removeFirst();
                    QTimer::singleShot(1000, this, [this, generation] { downloadNext(generation); });
                });
        });
}

void SubtitleSourceService::finishPreparation(quint64 generation, const QString& error)
{
    if (generation != m_prepareGeneration) return;
    m_downloadReply = nullptr;
    QVariantList rows;
    if (error.isEmpty()) for (const auto& item : m_rows) {
        auto row = item.toMap(); QStringList tracks;
        for (const auto& value : row.value("tracks").toList()) {
            const auto url = value.toUrl().toString(QUrl::FullyEncoded);
            tracks.append(m_ready.value(url, url));
        }
        row.insert("tracks", tracks); rows.append(row);
    }
    m_rows.clear(); m_pending.clear(); m_ready.clear();
    m_preparing = false; emit preparingChanged();
    emit preparationFinished(generation, {{"success", error.isEmpty()}, {"error", error}, {"rows", rows}});
}
