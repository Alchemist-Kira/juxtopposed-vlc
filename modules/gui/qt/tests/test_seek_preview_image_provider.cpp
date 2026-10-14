// SPDX-License-Identifier: GPL-2.0-or-later
#include "config.h"
#include <QTest>
#include <QBuffer>
#include <QQmlEngine>
#include <QQmlComponent>
#include "../plugins.hpp"
#include "../util/seek_preview_image_provider.hpp"

class SeekPreviewImageProviderTest : public QObject
{
    Q_OBJECT
    QByteArray m_png;
private slots:
    void initTestCase()
    {
        QImage image(16, 9, QImage::Format_RGBA8888);
        image.fill(Qt::red);
        image.setPixelColor(15, 8, Qt::blue);
        QBuffer buffer(&m_png);
        QVERIFY(buffer.open(QIODevice::WriteOnly));
        QVERIFY(image.save(&buffer, "PNG"));
    }

    void preservesPixelsAndIntrinsicSize()
    {
        SeekPreviewImageProvider provider;
        const auto url = SeekPreviewImageProvider::url(m_png);
        QSize size;
        const auto image = provider.requestImage(url.path().mid(1), &size, {});
        QCOMPARE(size, QSize(16, 9));
        QCOMPARE(image.pixelColor(0, 0), QColor(Qt::red));
        QCOMPARE(image.pixelColor(15, 8), QColor(Qt::blue));
    }

    void scalesWithoutChangingAspectRatio()
    {
        SeekPreviewImageProvider provider;
        QSize size;
        const auto image = provider.requestImage(SeekPreviewImageProvider::url(m_png).path().mid(1), &size, QSize(8, 8));
        QCOMPARE(size, QSize(16, 9));
        QCOMPARE(image.size(), QSize(8, 4));
    }

    void rejectsInvalidImages()
    {
        SeekPreviewImageProvider provider;
        QVERIFY(provider.requestImage(QStringLiteral("not-a-png"), nullptr, {}).isNull());
    }

    void loadsAndClearsThroughQml()
    {
        QQmlEngine engine;
        engine.addImageProvider(QStringLiteral("seekpreview"), new SeekPreviewImageProvider());
        QQmlComponent component(&engine);
        component.setData("import QtQuick\nImage { cache: false; property bool ready: status === Image.Ready }", QUrl());
        QVERIFY2(!component.isError(), qPrintable(component.errorString()));
        QScopedPointer<QObject> image(component.create());
        QVERIFY(image);
        QVERIFY(image->setProperty("source", SeekPreviewImageProvider::url(m_png)));
        QTRY_VERIFY(image->property("ready").toBool());
        QCOMPARE(image->property("implicitWidth").toInt(), 16);
        QCOMPARE(image->property("implicitHeight").toInt(), 9);
        QVERIFY(image->setProperty("source", QUrl()));
        QTRY_COMPARE(image->property("status").toInt(), 0);
    }
};

QTEST_MAIN(SeekPreviewImageProviderTest)
#include "test_seek_preview_image_provider.moc"
