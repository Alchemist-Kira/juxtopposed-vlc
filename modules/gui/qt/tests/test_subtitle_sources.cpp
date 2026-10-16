// SPDX-License-Identifier: GPL-2.0-or-later
#include <QTest>
#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSslSocket>
#include <QtPlugin>
#include <QFile>
#include <QDir>
#include <QUrlQuery>
#include "util/subtitle_source_service.hpp"

#if defined(Q_OS_WIN) && defined(QT_STATIC)
Q_IMPORT_PLUGIN(QSchannelBackend)
#endif

struct HttpRequest { QByteArray method; QUrl url; QMap<QByteArray,QByteArray> headers; QByteArray body; };
class Server : public QTcpServer {
public:
    QList<HttpRequest> requests;
    std::function<void(const HttpRequest&,QTcpSocket*)> respond;
    Server() {
        if (!listen(QHostAddress::LocalHost)) qFatal("Cannot start local subtitle test server");
        connect(this,&QTcpServer::newConnection,this,[this] {
            while (hasPendingConnections()) {
                auto* socket=nextPendingConnection(); auto buffer=std::make_shared<QByteArray>();
                connect(socket,&QTcpSocket::disconnected,socket,&QObject::deleteLater);
                connect(socket,&QTcpSocket::readyRead,this,[this,socket,buffer] {
                    buffer->append(socket->readAll()); const auto end=buffer->indexOf("\r\n\r\n"); if(end<0)return;
                    const auto lines=buffer->left(end).split('\n'); const auto first=lines.first().trimmed().split(' ');
                    HttpRequest request;request.method=first[0];request.url=QUrl::fromEncoded(first[1]);
                    for(const auto& line:lines.mid(1)) {const auto colon=line.indexOf(':');if(colon>0)request.headers.insert(line.left(colon).toLower(),line.mid(colon+1).trimmed());}
                    const auto length=request.headers.value("content-length").toInt(); if(buffer->size()<end+4+length)return;
                    request.body=buffer->mid(end+4,length);disconnect(socket,&QTcpSocket::readyRead,this,nullptr);
                    requests.append(request);if(respond)respond(request,socket);
                });
            }
        });
    }
    QUrl base() const { return QUrl(QString("http://127.0.0.1:%1/api/").arg(serverPort())); }
    static void send(QTcpSocket* socket,QByteArray body,int status=200,QByteArray extra={}) {
        socket->write("HTTP/1.1 "+QByteArray::number(status)+" Result\r\nContent-Length: "+QByteArray::number(body.size())+"\r\nConnection: close\r\n"+extra+"\r\n"+body);socket->disconnectFromHost();
    }
};
static QByteArray results() {
    return R"({"data":[{"attributes":{"language":"en","release":"The Wand S01E04","hearing_impaired":true,"files":[{"file_id":42,"file_name":"The_Wand_S01E04.en.srt"},{"file_id":43,"file_name":"../../other.srt"}]}}]})";
}
static QByteArray captions() { return "1\n00:00:01,000 --> 00:00:03,000\nTest captions\n"; }
class TestSubtitleSources : public QObject {
    Q_OBJECT
    static SubtitleSourceService::Options options(Server& server) { SubtitleSourceService::Options o;o.apiBase=server.base();o.timeoutMs=1000;return o; }
    static QVariantMap result(QSignalSpy& spy) { if(!spy.wait(5000))qFatal("Subtitle client did not finish");return spy.last()[1].toMap(); }
    static QVariantList search(SubtitleSourceService& client) { QSignalSpy spy(&client,&SubtitleSourceService::searchFinished);client.search("The Wand S01E04","en");return result(spy).value("sources").toList(); }
    static QVariantList row(const QStringList& tracks) { return {QVariantMap{{"url","file:///movie.mkv"},{"baseline",QStringList{}},{"initialTracks",QStringList{}},{"tracks",tracks}}}; }
private slots:
    void configurationAndMissingKey() {
        QTemporaryDir directory;Server server;SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());
        QSignalSpy spy(&client,&SubtitleSourceService::searchFinished);client.search("Film","en");
        QVERIFY(!result(spy).value("success").toBool());QVERIFY(server.requests.isEmpty());
        QVERIFY(!client.setApiKey("bad\r\nkey"));QVERIFY(!client.setApiKey(QString::fromUtf8("秘密")));
        QVERIFY(client.setApiKey("unit-secret"));QVERIFY(client.configured());
        SubtitleSourceService next(options(server));next.setStorageDirectory(directory.path());QVERIFY(next.configured());
#ifndef Q_OS_WIN
        QVERIFY(!(QFile::permissions(directory.filePath("source-settings.ini"))&QFile::WriteOther));
#endif
    }
    void searchParsesFilesAndQuery() {
        QTemporaryDir directory;Server server;server.respond=[](const HttpRequest&,QTcpSocket* socket){Server::send(socket,results());};
        SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        const auto sources=search(client);QCOMPARE(sources.size(),2);
        QCOMPARE(sources[0].toMap().value("name").toString(),"The_Wand_S01E04.en.srt");
        QCOMPARE(sources[1].toMap().value("name").toString(),"other.srt");
        QVERIFY(sources[0].toMap().value("hearingImpaired").toBool());
        QCOMPARE(server.requests.size(),1);QCOMPARE(server.requests[0].url.path(),"/api/subtitles");
        QCOMPARE(QUrlQuery(server.requests[0].url).queryItemValue("query"),"The Wand S01E04");
        QCOMPARE(QUrlQuery(server.requests[0].url).queryItemValue("languages"),"en");
        QCOMPARE(server.requests[0].headers.value("api-key"),QByteArray("unit-secret"));QVERIFY(!server.requests[0].headers.value("user-agent").isEmpty());
    }
    void serverErrors_data() {
        QTest::addColumn<int>("status");QTest::addColumn<QByteArray>("body");
        QTest::newRow("key")<<403<<QByteArray("{}");QTest::newRow("quota")<<429<<QByteArray("{}");
        QTest::newRow("server")<<503<<QByteArray("{}");QTest::newRow("bad-json")<<200<<QByteArray("<html>error</html>");
    }
    void serverErrors() {
        QFETCH(int,status);QFETCH(QByteArray,body);QTemporaryDir directory;Server server;
        server.respond=[&](const HttpRequest&,QTcpSocket* socket){Server::send(socket,body,status);};
        SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        QSignalSpy spy(&client,&SubtitleSourceService::searchFinished);client.search("Film","en");const auto answer=result(spy);
        QVERIFY(!answer.value("success").toBool());QVERIFY(!answer.value("error").toString().isEmpty());QVERIFY(!answer.value("error").toString().contains("unit-secret"));
    }
    void timeoutAndCancellation() {
        QTemporaryDir directory;Server server;server.respond=[](const HttpRequest&,QTcpSocket*){};
        auto o=options(server);o.timeoutMs=80;SubtitleSourceService client(o);client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        QSignalSpy spy(&client,&SubtitleSourceService::searchFinished);client.search("Film","en");QVERIFY(!result(spy).value("success").toBool());
        spy.clear();client.search("Old film","en");client.cancelSearch();QTest::qWait(100);QCOMPARE(spy.count(),0);
        server.respond=[](const HttpRequest&,QTcpSocket* socket){Server::send(socket,results());};
        client.search("New film","en");QVERIFY(result(spy).value("success").toBool());QCOMPARE(spy.count(),1);
    }
    void selectedFilesDownloadAndCache() {
        QTemporaryDir directory;Server server;
        server.respond=[&](const HttpRequest& request,QTcpSocket* socket){
            if(request.url.path()=="/api/subtitles")Server::send(socket,results());
            else if(request.url.path()=="/api/download")Server::send(socket,QJsonDocument(QJsonObject{{"link",server.base().resolved(QUrl("../file.srt")).toString()}}).toJson());
            else Server::send(socket,captions());
        };
        SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        const auto sources=search(client);const auto selected=sources[0].toMap().value("url").toString();
        QSignalSpy spy(&client,&SubtitleSourceService::preparationFinished);client.prepareRows(row({selected,selected}));auto answer=result(spy);
        QVERIFY(answer.value("success").toBool());QCOMPARE(server.requests.size(),3);
        const auto body=QJsonDocument::fromJson(server.requests[1].body).object();QCOMPARE(body.value("file_id").toInt(),42);QCOMPARE(body.value("sub_format").toString(),"srt");
        QVERIFY(!server.requests[2].headers.contains("api-key"));QVERIFY(!server.requests[2].headers.contains("authorization"));
        const auto tracks=answer.value("rows").toList()[0].toMap().value("tracks").toStringList();QCOMPARE(tracks.size(),2);QCOMPARE(tracks[0],tracks[1]);
        QFile file(QUrl(tracks[0]).toLocalFile());QVERIFY(file.open(QIODevice::ReadOnly));QCOMPARE(file.readAll(),captions());
        spy.clear();client.prepareRows(row({selected}));QVERIFY(result(spy).value("success").toBool());QCOMPARE(server.requests.size(),3);
        const auto cached=search(client)[0].toMap().value("url").toString();QCOMPARE(cached,tracks[0]);
    }
    void languageListIsValidatedAndCached() {
        QTemporaryDir directory;Server server;
        server.respond=[](const HttpRequest&,QTcpSocket* socket){Server::send(socket,R"json({"data":[{"language_code":"en","language_name":"English"},{"language_code":"pt-br","language_name":"Portuguese (Brazil)"},{"language_code":"en","language_name":"Duplicate"},{"language_code":"../../bad","language_name":"Bad"}]})json");};
        SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        QSignalSpy spy(&client,&SubtitleSourceService::languagesChanged);client.fetchLanguages();QVERIFY(spy.wait());
        QCOMPARE(client.languages().size(),2);QCOMPARE(server.requests.size(),1);QCOMPARE(server.requests[0].url.path(),"/api/infos/languages");
        client.fetchLanguages();QTest::qWait(40);QCOMPARE(server.requests.size(),1);
    }
    void partialDownloadCanBeRetriedWithoutSpendingQuotaAgain() {
        QTemporaryDir directory;Server server;bool fail=true;
        server.respond=[&](const HttpRequest& request,QTcpSocket* socket){
            if(request.url.path()=="/api/subtitles")Server::send(socket,results());
            else if(request.url.path()=="/api/download") {
                const auto id=QJsonDocument::fromJson(request.body).object().value("file_id").toInt();
                if(id==43 && fail)Server::send(socket,"{}",429);
                else Server::send(socket,QJsonDocument(QJsonObject{{"link",server.base().resolved(QUrl("../file.srt")).toString()}}).toJson());
            } else Server::send(socket,captions());
        };
        SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        const auto sources=search(client);const auto a=sources[0].toMap().value("url").toString(),b=sources[1].toMap().value("url").toString();
        QSignalSpy spy(&client,&SubtitleSourceService::preparationFinished);client.prepareRows(row({a,b}));auto answer=result(spy);
        QVERIFY(!answer.value("success").toBool());QCOMPARE(answer.value("resolved").toMap().size(),1);QVERIFY(answer.value("rows").toList().isEmpty());
        QCOMPARE(server.requests.size(),4);fail=false;spy.clear();client.prepareRows(row({a,b}));answer=result(spy);
        QVERIFY(answer.value("success").toBool());QCOMPARE(server.requests.size(),6);QCOMPARE(answer.value("resolved").toMap().size(),2);
    }
    void cancelDownloadDoesNotEmitOrWriteAFile() {
        QTemporaryDir directory;Server server;
        server.respond=[](const HttpRequest& request,QTcpSocket* socket){if(request.url.path()=="/api/subtitles")Server::send(socket,results());};
        SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        const auto selected=search(client)[0].toMap().value("url").toString();QSignalSpy spy(&client,&SubtitleSourceService::preparationFinished);client.prepareRows(row({selected}));
        QTRY_COMPARE(server.requests.size(),2);client.cancelPreparation();QTest::qWait(40);QVERIFY(!client.preparing());QCOMPARE(spy.count(),0);
        QVERIFY(!QFileInfo::exists(directory.filePath("opensubtitles/42/The_Wand_S01E04.en.srt")));
    }
    void tlsBackendIsAvailable() {
        QVERIFY2(QSslSocket::supportsSsl(),"The subtitle source needs a working TLS backend");
    }
    void rejectsBadFilesAndLimits_data() {
        QTest::addColumn<QByteArray>("body");QTest::addColumn<qint64>("limit");
        QTest::newRow("html")<<QByteArray("<html>not subtitles</html>")<<qint64(1024);
        QTest::newRow("size")<<(captions()+QByteArray(2048,'x'))<<qint64(1024);
    }
    void rejectsBadFilesAndLimits() {
        QFETCH(QByteArray,body);QFETCH(qint64,limit);QTemporaryDir directory;Server server;
        server.respond=[&](const HttpRequest& request,QTcpSocket* socket){
            if(request.url.path()=="/api/subtitles")Server::send(socket,results());
            else if(request.url.path()=="/api/download")Server::send(socket,QJsonDocument(QJsonObject{{"link",server.base().resolved(QUrl("../file.srt")).toString()}}).toJson());
            else Server::send(socket,body);
        };
        auto o=options(server);o.maxFileBytes=limit;SubtitleSourceService client(o);client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        const auto selected=search(client)[0].toMap().value("url").toString();QSignalSpy spy(&client,&SubtitleSourceService::preparationFinished);client.prepareRows(row({selected}));
        QVERIFY(!result(spy).value("success").toBool());QVERIFY(!QFileInfo::exists(directory.filePath("opensubtitles/42/The_Wand_S01E04.en.srt")));
    }
    void apiRedirectDoesNotSendKey() {
        QTemporaryDir directory;Server server;server.respond=[](const HttpRequest&,QTcpSocket* socket){Server::send(socket,{},302,"Location: http://127.0.0.1:1/leak\r\n");};
        SubtitleSourceService client(options(server));client.setStorageDirectory(directory.path());QVERIFY(client.setApiKey("unit-secret"));
        QSignalSpy spy(&client,&SubtitleSourceService::searchFinished);client.search("Film","en");QVERIFY(!result(spy).value("success").toBool());QCOMPARE(server.requests.size(),1);
    }
};
QTEST_GUILESS_MAIN(TestSubtitleSources)
#include "test_subtitle_sources.moc"
