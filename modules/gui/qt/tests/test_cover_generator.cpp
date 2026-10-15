// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QUrl>
#include "util/covergenerator.hpp"

class TestCoverGenerator : public QObject
{
    Q_OBJECT
private slots:
    void transparentFallbackHasNoWhiteOrAlbumPlaceholder() {
        CoverGenerator generator;
        generator.setSize({91,53});
        generator.setDefaultThumbnail({});
        for (const auto split : {CoverGenerator::Divide, CoverGenerator::Duplicate}) {
            generator.setSplit(split);
            for (const QStringList& files : {QStringList{},QStringList{QStringLiteral("/missing/cover.png")}}) {
                const auto image = generator.execute(files);
                QCOMPARE(image.size(), QSize(91,53));
                QVERIFY(image.hasAlphaChannel());
                for (int y=0;y<image.height();++y) for (int x=0;x<image.width();++x)
                    QCOMPARE(image.pixelColor(x,y).alpha(),0);
            }
        }
    }
    void missingAndInvalidImagesDoNotLeaveGapsBesideRealArtwork() {
        QTemporaryDir directory;
        QImage source(30,30,QImage::Format_RGB32); source.fill(QColor("#428b69"));
        const auto cover = directory.filePath("épisode & cover.png");
        QVERIFY(source.save(cover));
        QFile broken(directory.filePath("broken.png"));
        QVERIFY(broken.open(QIODevice::WriteOnly)); broken.write("invalid image"); broken.close();
        CoverGenerator generator;
        generator.setSize({91,53}); generator.setDefaultThumbnail({});
        const auto image=generator.execute({"/missing/cover.png",broken.fileName(),QUrl::fromLocalFile(cover).toString()});
        for (int y=0;y<image.height();++y) for (int x=0;x<image.width();++x)
            QCOMPARE(image.pixelColor(x,y),QColor("#428b69"));
    }
    void explicitDefaultAndCollageRemainAvailable() {
        QTemporaryDir directory;
        QImage source(20,20,QImage::Format_RGB32);
        const auto red=directory.filePath("red.png"), blue=directory.filePath("blue.png");
        source.fill(Qt::red); QVERIFY(source.save(red));
        source.fill(Qt::blue); QVERIFY(source.save(blue));
        CoverGenerator generator; generator.setSize({100,60}); generator.setDefaultThumbnail(blue);
        QCOMPARE(generator.execute({}).pixelColor(50,30),QColor(Qt::blue));
        generator.setDefaultThumbnail({});
        const auto collage=generator.execute({red,blue});
        QCOMPARE(collage.pixelColor(10,30),QColor(Qt::red));
        QCOMPARE(collage.pixelColor(90,30),QColor(Qt::blue));
    }
};
QTEST_GUILESS_MAIN(TestCoverGenerator)
#include "test_cover_generator.moc"
