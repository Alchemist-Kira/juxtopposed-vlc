// SPDX-License-Identifier: GPL-2.0-or-later
#include <QQuickItem>
#include <QTest>

#include "../maininterface/compositor_x11_uisurface.hpp"

class SurfaceSizeTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        qputenv("QT_QUICK_BACKEND", "software");
    }

    void initialLayout_data()
    {
        QTest::addColumn<QSize>("restoredSize");
        QTest::newRow("default") << QSize(960, 540);
        QTest::newRow("large") << QSize(1600, 1000);
        QTest::newRow("portrait") << QSize(720, 1280);
    }

    void initialLayout()
    {
        QFETCH(QSize, restoredSize);
        QWindow mainWindow;
        mainWindow.resize(restoredSize);
        vlc::CompositorX11UISurface surface(&mainWindow);
        surface.create();
        auto* root = new QQuickItem;

        // No expose or resize event has reached the new QML surface yet.
        surface.setContent(root);
        QCOMPARE(root->size(), QSizeF(restoredSize));
        QCOMPARE(surface.getOffscreenWindow()->size(), restoredSize);
    }
};

QTEST_MAIN(SurfaceSizeTest)
#include "test_x11_surface_size.moc"
