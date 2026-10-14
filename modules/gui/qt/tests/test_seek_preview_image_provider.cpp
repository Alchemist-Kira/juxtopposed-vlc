// SPDX-License-Identifier: GPL-2.0-or-later
#include "config.h"
#include <QTest>
#include <QBuffer>
#include <QQmlEngine>
#include <QQmlComponent>
#include "../plugins.hpp"
#include "../util/seek_preview_image_provider.hpp"
#include "../util/seek_preview_cache.hpp"

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

    void samplesCoverTheTimelineWithinBounds()
    {
        QVERIFY(SeekPreviewCache::samplesFor(0).isEmpty());
        QVERIFY(SeekPreviewCache::samplesFor(-1).isEmpty());
        QCOMPARE(SeekPreviewCache::samplesFor(1), QVector<qint64>{0});
        for (qint64 length : {qint64(500001), qint64(30000000), qint64(10800000000)}) {
            const auto points = SeekPreviewCache::samplesFor(length);
            QVERIFY(points.size() <= SeekPreviewCache::MaximumSamples);
            QCOMPARE(points.front(), qint64(0));
            QCOMPARE(points[1], (length - 1) / SeekPreviewCache::Bucket * SeekPreviewCache::Bucket);
            auto sorted = points;
            std::sort(sorted.begin(), sorted.end());
            QVERIFY(std::adjacent_find(sorted.begin(), sorted.end()) == sorted.end());
            for (const auto time : points) {
                QVERIFY(time >= 0 && time < length);
                QCOMPARE(time % SeekPreviewCache::Bucket, qint64(0));
            }
            if (points.size() > 2)
                QVERIFY(std::abs(points[2] - length / 2) < length / 10 + SeekPreviewCache::Bucket);
        }
        QCOMPARE(SeekPreviewCache::samplesFor(10800000000).size(), SeekPreviewCache::MaximumSamples);
    }

    void cacheUsesDecodedTimesAndDoesNotStoreFailures()
    {
        SeekPreviewCache cache;
        QVERIFY(!cache.insert(0, QUrl(), 0, true));
        QVERIFY(!cache.nearest(0));
        const QUrl first(QStringLiteral("image://seekpreview/first"));
        const QUrl second(QStringLiteral("image://seekpreview/second"));
        QVERIFY(cache.insert(0, first, 2000000, true));
        QVERIFY(cache.insert(10000000, second, 8000000, false));
        QCOMPARE(cache.nearest(3000000)->image, first);
        QCOMPARE(cache.nearest(7000000)->image, second);
        QCOMPARE(cache.nearest(7000000)->time, qint64(8000000));
        QVERIFY(!cache.exact(0)); // Coarse seeks still need a precise refinement.
        QVERIFY(cache.exact(10000000));
        QVERIFY(!cache.insert(10000000, QUrl(), 0, false));
        QCOMPARE(cache.exact(10000000)->image, second);
    }

    void preciseEvictionPreservesCoarseCoverage()
    {
        SeekPreviewCache cache;
        const QUrl coarse(QStringLiteral("image://seekpreview/coarse"));
        QVERIFY(cache.insert(0, coarse, 0, true));
        for (int i = 1; i <= 100; ++i)
            QVERIFY(cache.insert(i * SeekPreviewCache::Bucket,
                QUrl(QStringLiteral("image://seekpreview/%1").arg(i)), i * SeekPreviewCache::Bucket, false));
        QCOMPARE(cache.count(true), 1);
        QCOMPARE(cache.count(false), 32);
        QVERIFY(!cache.exact(SeekPreviewCache::Bucket));
        QCOMPARE(cache.nearest(0)->image, coarse);
        cache.clear();
        QCOMPARE(cache.count(true), 0);
        QCOMPARE(cache.count(false), 0);
        QVERIFY(!cache.nearest(0));
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
