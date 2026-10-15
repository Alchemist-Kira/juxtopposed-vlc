// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <vlc_configuration.h>
#include <vlc_cxx_helpers.hpp>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QLockFile>
#include <QSaveFile>
#include <QSettings>
#include <QTemporaryFile>
#include <QUuid>
#include <QUrl>
#include <memory>

namespace PlaylistCoverStore {
inline QString directory()
{
    const auto path = vlc::wrap_cptr(config_GetUserDir(VLC_USERDATA_DIR));
    return path ? QDir(QString::fromUtf8(path.get())).filePath(QStringLiteral("playlist-covers")) : QString();
}
inline QString key(int64_t id, uint32_t date)
{
    return QString::number(id) + QLatin1Char('-') + QString::number(date);
}
inline QUrl cover(int64_t id, uint32_t date)
{
    const auto folder = directory();
    if (folder.isEmpty()) return {};
    QSettings settings(QDir(folder).filePath(QStringLiteral("covers.ini")), QSettings::IniFormat);
    settings.sync();
    const auto name = settings.value(key(id, date)).toString();
    if (name.isEmpty() || name != QFileInfo(name).fileName()) return {};
    return QUrl::fromLocalFile(QDir(folder).filePath(name));
}
inline std::unique_ptr<QLockFile> lock()
{
    const auto folder = directory();
    if (folder.isEmpty() || !QDir().mkpath(folder)) return {};
    auto result = std::make_unique<QLockFile>(QDir(folder).filePath(QStringLiteral(".covers-writer.lock")));
    if (!result->tryLock(3000)) return {};
    return result;
}
inline QString prepareImage(const QUrl& source)
{
    const auto folder = directory();
    if (!source.isLocalFile() || folder.isEmpty()) return {};
    QImageReader reader(source.toLocalFile());
    reader.setAutoTransform(true);
    const auto size = reader.size();
    if (size.isValid() && (size.width() > 1024 || size.height() > 1024))
        reader.setScaledSize(size.scaled(QSize(1024, 1024), Qt::KeepAspectRatio));
    const auto image = reader.read();
    if (image.isNull() || !QDir().mkpath(folder)) return {};
    const auto path = QDir(folder).filePath(QUuid::createUuid().toString(QUuid::WithoutBraces) + QStringLiteral(".png"));
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly) || !image.save(&output, "PNG") || !output.commit()) return {};
    return path;
}
// Prepare the complete settings file before changing the native playlist name.
// The caller holds the writer lock until committing or cancelling this file.
inline std::unique_ptr<QSaveFile> stage(int64_t id, uint32_t date, const QString& image)
{
    const QDir folder(directory());
    const auto path = folder.filePath(QStringLiteral("covers.ini"));
    QTemporaryFile temporary(folder.filePath(QStringLiteral(".covers-XXXXXX.ini")));
    if (!temporary.open()) return {};
    if (QFile::exists(path)) {
        QFile source(path);
        if (!source.open(QIODevice::ReadOnly)) return {};
        const auto bytes = source.readAll();
        if (source.error() != QFile::NoError || temporary.write(bytes) != bytes.size()) return {};
    }
    temporary.close();
    {
        QSettings settings(temporary.fileName(), QSettings::IniFormat);
        if (image.isEmpty()) settings.remove(key(id, date));
        else settings.setValue(key(id, date), QFileInfo(image).fileName());
        settings.sync();
        if (settings.status() != QSettings::NoError) return {};
    }
    QFile input(temporary.fileName());
    auto output = std::make_unique<QSaveFile>(path);
    if (!input.open(QIODevice::ReadOnly) || !output->open(QIODevice::WriteOnly)) return {};
    const auto bytes = input.readAll();
    if (input.error() != QFile::NoError || output->write(bytes) != bytes.size()) return {};
    return output;
}
} // namespace PlaylistCoverStore
