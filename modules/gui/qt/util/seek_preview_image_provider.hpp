// SPDX-License-Identifier: GPL-2.0-or-later
#ifndef VLC_QT_SEEK_PREVIEW_IMAGE_PROVIDER_HPP
#define VLC_QT_SEEK_PREVIEW_IMAGE_PROVIDER_HPP

#include <QQuickImageProvider>
#include <QImage>
#include <QUrl>

// Unlike data: image URLs, providers also work when Qt networking is disabled.
class SeekPreviewImageProvider final : public QQuickImageProvider
{
public:
    SeekPreviewImageProvider() : QQuickImageProvider(Image) {}

    static QUrl url(const QByteArray& png)
    {
        return QUrl(QStringLiteral("image://seekpreview/") + QString::fromLatin1(
            png.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals)));
    }

    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override
    {
        auto image = QImage::fromData(QByteArray::fromBase64(id.toLatin1(), QByteArray::Base64UrlEncoding), "PNG");
        if (size) *size = image.size();
        if (!image.isNull() && requestedSize.isValid())
            image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        return image;
    }
};

#endif
