/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#include "medialib.hpp"
#include "mlhelper.hpp"
#include "playlist/playlist_controller.hpp"
#include "util/shared_input_item.hpp"
#include "util/playlist_cover_store.hpp"
#include <QScopeGuard>

#include <utility>

#include <QQmlEngine>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QRandomGenerator>
#include <QTemporaryFile>
#include <QSaveFile>
#include <QDir>
#include <vlc_playlist.h>
#include <algorithm>

MediaLib::MediaLib(qt_intf_t *_intf, vlc::playlist::PlaylistController* playlistController, QObject *_parent)
    : QObject( _parent )
    , m_intf( _intf )
    , m_playlistController(playlistController)
    , m_ml( vlc_ml_instance_get( _intf ) )
    , m_event_cb( nullptr, [this](vlc_ml_event_callback_t* cb ) {
        vlc_ml_event_unregister_callback( m_ml, cb );
      })
{
    m_event_cb.reset( vlc_ml_event_register_callback( m_ml, MediaLib::onMediaLibraryEvent,
                                                      this ) );
    m_runner = new ThreadRunner();
}

MediaLib::~MediaLib()
{
    m_runner->destroy();
}

static void convertMLItemToPlaylistMedias(vlc_medialibrary_t* ml, const MLItemId & itemId, const QStringList &options, QVector<vlc::playlist::Media>& medias)
{
    //invalid item
    if (itemId.id == 0)
        return;

    if (itemId.type == VLC_ML_PARENT_UNKNOWN)
    {
        SharedInputItem item( vlc_ml_get_input_item( ml, itemId.id ), false );
        if (item)
            medias.push_back(vlc::playlist::Media(item.get(), options));
    }
    else
    {
        vlc_ml_query_params_t query = vlc_ml_query_params_create();
        ml_unique_ptr<vlc_ml_media_list_t> media_list(vlc_ml_list_media_of( ml, &query, itemId.type, itemId.id));
        if (media_list == nullptr || media_list->i_nb_items == 0)
            return;

        auto mediaRange = ml_range_iterate<vlc_ml_media_t>( media_list );
        std::transform(mediaRange.begin(), mediaRange.end(), std::back_inserter(medias), [&](vlc_ml_media_t& m) {
            SharedInputItem item(vlc_ml_get_input_item( ml, m.i_id ), false);
            return vlc::playlist::Media(item.get(), options);
        });
    }
}

static void convertQUrlToPlaylistMedias(QUrl mrl, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    vlc::playlist::Media media{ mrl.toString(QUrl::FullyEncoded), mrl.fileName(), options };
    medias.push_back(media);
}

static void convertQStringToPlaylistMedias(const QString &mrl, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    vlc::playlist::Media media{ mrl, mrl, options };
    medias.push_back(media);
}


static void convertQVariantListToPlaylistMedias(vlc_medialibrary_t* ml, QVariantList itemIdList, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    for (const QVariant& varValue: itemIdList)
    {
        if (varValue.canConvert<QUrl>())
        {
            auto mrl = varValue.value<QUrl>();
            convertQUrlToPlaylistMedias(mrl, options, medias);
        }
        else if (varValue.canConvert<QString>())
        {
            auto mrl = varValue.value<QString>();
            convertQStringToPlaylistMedias(mrl, options, medias);
        }
        else if (varValue.canConvert<MLItemId>())
        {
            MLItemId itemId = varValue.value<MLItemId>();
            convertMLItemToPlaylistMedias(ml, itemId, options, medias);
        }
        // else ignore
    }
}

MLItemId MediaLib::deserializeMlItemIdFromString(const QString& serialized_id) {
    return MLItemId::fromString(serialized_id);
}

void MediaLib::addToPlaylist(const QString& mrl, const QStringList &options)
{
    QVector<vlc::playlist::Media> medias;
    convertQStringToPlaylistMedias(mrl, options, medias);
    m_playlistController->append(medias, false);
}

void MediaLib::addToPlaylist(const QUrl& mrl, const QStringList &options)
{
    QVector<vlc::playlist::Media> medias;
    convertQUrlToPlaylistMedias(mrl, options, medias);
    m_playlistController->append(medias, false);
}

// A specific item has been asked to be added to the playlist
void MediaLib::addToPlaylist(const MLItemId & itemId, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemId, options]
    (vlc_medialibrary_t* ml, Context& ctx){
        convertMLItemToPlaylistMedias(ml, itemId, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, false);
    });
}

void MediaLib::addToPlaylist(const QVariantList& itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, false);
    });
}

// A specific item has been asked to be played,
// so it's added to the playlist and played
void MediaLib::addAndPlay(const MLItemId & itemId, const QStringList &options )
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemId, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertMLItemToPlaylistMedias(ml, itemId, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, true);
    });


}

void MediaLib::addAndPlay(const QString& mrl, const QStringList &options)
{
    vlc::playlist::Media media{ mrl, mrl, options };
    m_playlistController->append( QVector<vlc::playlist::Media>{media}, true );
}

void MediaLib::addAndPlay(const QUrl& mrl, const QStringList &options)
{
    vlc::playlist::Media media{ mrl.toString(QUrl::FullyEncoded), mrl.fileName(), options };
    m_playlistController->append( QVector<vlc::playlist::Media>{media}, true );
}


void MediaLib::addAndPlay(const QVariantList& itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, true);
    });
}

void MediaLib::insertIntoPlaylist(const size_t index, const QVariantList &itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx )
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias);
    },
    //UI thread
    [this, index]
    (quint64, Context& ctx) {
        if (!ctx.medias.isEmpty())
            m_playlistController->insert( index, ctx.medias );
    });
}

void MediaLib::reload()
{
    runOnMLThread(this,
    //ML thread
    [](vlc_medialibrary_t* ml){
        vlc_ml_reload_folder(ml, nullptr);
    });
}

void MediaLib::mediaState(const QUrl& url, bool create, QJSValue callback)
{
    requestMediaState(url, create ? MediaStateAction::Ensure : MediaStateAction::Read, false, callback);
}

void MediaLib::resyncFolder(const QUrl& url, QJSValue callback)
{
    if (!callback.isCallable()) return;
    runOnMLThread<QVariantMap>(this,
        [url](vlc_medialibrary_t* ml, QVariantMap& result) {
            result = {{"success", false}, {"error", qtr("VLC cannot rescan this folder. Check the folder and try again.")}};
            if (!url.isValid() || url.scheme().isEmpty()) return;
            const auto mrl = url.toEncoded();
            if (vlc_ml_reload_folder(ml, mrl.constData()) == VLC_SUCCESS)
                result = {{"success", true}, {"error", QString()}};
        },
        [this, callback](quint64, const QVariantMap& result) mutable {
            if (auto engine = qjsEngine(this)) callback.call({engine->toScriptValue(result)});
        }, "redesign-folder-resync");
}

void MediaLib::playlistState(const MLItemId& id, QJSValue callback)
{
    requestPlaylistState(id, false, false, callback);
}

void MediaLib::setPlaylistFavorite(const MLItemId& id, bool favorite, QJSValue callback)
{
    requestPlaylistState(id, true, favorite, callback);
}

void MediaLib::playlistTrackTargets(const MLItemId& id, QJSValue callback)
{
    if (!callback.isCallable()) return;
    runOnMLThread<QVariantMap>(this,
        [id](vlc_medialibrary_t* ml, QVariantMap& result) {
            result = {{"success", false}, {"error", qtr("VLC cannot read this playlist. Select it again.")}};
            if (id.type != VLC_ML_PARENT_PLAYLIST || id.id <= 0) return;
            ml_unique_ptr<vlc_ml_playlist_t> playlist(vlc_ml_get_playlist(ml, id.id));
            if (!playlist) return;
            auto query = vlc_ml_query_params_create();
            ml_unique_ptr<vlc_ml_media_list_t> media(vlc_ml_list_playlist_media(ml, &query, id.id));
            if (!media) return;
            QVariantList items;
            QSet<int64_t> seen;
            for (const auto& item : ml_range_iterate<vlc_ml_media_t>(media)) {
                if (seen.contains(item.i_id) || !item.p_files) continue;
                seen.insert(item.i_id);
                for (const auto& file : ml_range_iterate<vlc_ml_file_t>(item.p_files)) {
                    if (file.i_type != VLC_ML_FILE_TYPE_MAIN) continue;
                    const QUrl url(qfu(file.psz_mrl));
                    if (!url.isValid() || url.scheme().isEmpty()) continue;
                    QString name = qfu(item.psz_filename);
                    if (name.isEmpty()) name = url.fileName();
                    if (name.isEmpty()) name = qfu(item.psz_title);
                    if (name.isEmpty()) name = url.toDisplayString();
                    items.push_back(QVariantMap{{"name", name}, {"url", url.toString(QUrl::FullyEncoded)},
                        {"location", url.toDisplayString(QUrl::PreferLocalFile)}, {"enabled", file.b_present}});
                    break;
                }
            }
            result = {{"success", true}, {"error", QString()}, {"name", qfu(playlist->psz_name)}, {"items", items}};
        },
        [this, callback](quint64, const QVariantMap& result) mutable {
            if (auto engine = qjsEngine(this)) callback.call({engine->toScriptValue(result)});
        }, "redesign-playlist-tracks");
}

void MediaLib::requestPlaylistState(const MLItemId& id, bool update, bool favorite, QJSValue callback)
{
    if (!callback.isCallable()) return;
    runOnMLThread<QVariantMap>(this,
        [id, update, favorite](vlc_medialibrary_t* ml, QVariantMap& state) {
            state = {{"success", false}, {"error", qtr("VLC cannot read this playlist. Select it again.")}};
            if (id.type != VLC_ML_PARENT_PLAYLIST || id.id <= 0) return;
            ml_unique_ptr<vlc_ml_playlist_t> playlist(vlc_ml_get_playlist(ml, id.id));
            if (!playlist) return;
            if (update && vlc_ml_playlist_set_favorite(ml, id.id, favorite) != VLC_SUCCESS) {
                state["error"] = qtr("VLC cannot save this change. Try again.");
                return;
            }
            state = {{"success", true}, {"error", QString()}, {"id", id.toString()},
                {"name", qfu(playlist->psz_name)}, {"favorite", update ? favorite : playlist->b_is_favorite},
                {"count", playlist->i_nb_media}, {"duration", QVariant::fromValue(playlist->i_duration)},
                {"readOnly", playlist->b_is_read_only}, {"created", playlist->i_creation_date},
                {"videoCount", playlist->i_nb_video}, {"audioCount", playlist->i_nb_audio},
                {"unknownCount", playlist->i_nb_unknown}, {"missingCount", playlist->i_nb_media - std::min(playlist->i_nb_media, playlist->i_nb_present_media)},
                {"unknownDurationCount", playlist->i_nb_duration_unknown}, {"source", qfu(playlist->psz_mrl)},
                {"cover", PlaylistCoverStore::cover(id.id, playlist->i_creation_date).toString(QUrl::FullyEncoded)}};
        },
        [this, callback](quint64, const QVariantMap& state) mutable {
            if (auto engine = qjsEngine(this)) callback.call({engine->toScriptValue(state)});
        }, "redesign-playlist-state");
}

void MediaLib::savePlaylistDetails(const MLItemId& id, const QString& name, const QUrl& cover, QJSValue callback)
{
    if (!callback.isCallable()) return;
    runOnMLThread<QVariantMap>(this,
        [id, name = name.trimmed(), cover](vlc_medialibrary_t* ml, QVariantMap& result) {
            result = {{"success", false}, {"error", qtr("VLC cannot save this playlist. Try again.")}};
            if (id.type != VLC_ML_PARENT_PLAYLIST || id.id <= 0 || name.isEmpty()) return;
            ml_unique_ptr<vlc_ml_playlist_t> playlist(vlc_ml_get_playlist(ml, id.id));
            if (!playlist) return;
            if (playlist->b_is_read_only) {
                result["error"] = qtr("You cannot change this playlist.");
                return;
            }
            const auto oldName = qfu(playlist->psz_name);
            const auto writerLock = PlaylistCoverStore::lock();
            if (!writerLock) return;
            const auto oldCover = PlaylistCoverStore::cover(id.id, playlist->i_creation_date);
            const bool changeCover = cover != oldCover;
            QString image;
            bool saved = false;
            const auto cleanup = qScopeGuard([&] { if (!saved && !image.isEmpty()) QFile::remove(image); });
            std::unique_ptr<QSaveFile> metadata;
            if (changeCover) {
                if (!cover.isEmpty()) {
                    image = PlaylistCoverStore::prepareImage(cover);
                    if (image.isEmpty()) {
                        result["error"] = qtr("VLC cannot read or save this image. Select another image.");
                        return;
                    }
                }
                metadata = PlaylistCoverStore::stage(id.id, playlist->i_creation_date, image);
                if (!metadata) return;
            }
            const bool changeName = oldName != name;
            if (changeName && vlc_ml_playlist_rename(ml, id.id, qtu(name)) != VLC_SUCCESS) return;
            if (metadata && !metadata->commit()) {
                if (changeName && vlc_ml_playlist_rename(ml, id.id, qtu(oldName)) != VLC_SUCCESS)
                    result["error"] = qtr("VLC saved the name but cannot save the thumbnail. Open the properties again to see the saved values.");
                return;
            }
            saved = true;
            if (changeCover && oldCover.isLocalFile()) QFile::remove(oldCover.toLocalFile());
            result = {{"success", true}, {"error", QString()}, {"name", name},
                      {"cover", PlaylistCoverStore::cover(id.id, playlist->i_creation_date)}};
        },
        [this, id, callback](quint64, const QVariantMap& result) mutable {
            if (result.value("success").toBool())
                emit playlistDetailsChanged(id, result.value("name").toString(), result.value("cover").toUrl());
            if (auto engine = qjsEngine(this)) callback.call({engine->toScriptValue(result)});
        }, "redesign-playlist-details");
}

void MediaLib::shuffleAndPlay(const MLItemId& id)
{
    if (id.type != VLC_ML_PARENT_PLAYLIST || id.id <= 0) return;
    struct Result { QVector<vlc::playlist::Media> media; };
    runOnMLThread<Result>(this,
        [id](vlc_medialibrary_t* ml, Result& result) {
            convertMLItemToPlaylistMedias(ml, id, {}, result.media);
            std::shuffle(result.media.begin(), result.media.end(), *QRandomGenerator::global());
        },
        [this](quint64, const Result& result) {
            if (!result.media.isEmpty()) m_playlistController->append(result.media, true);
        });
}

void MediaLib::exportPlaylist(const MLItemId& id, const QUrl& file, const QByteArray& format,
                             QObject* receiver, std::function<void(const QString&)> callback)
{
    runOnMLThread<QString>(receiver,
        [id, file, format, intf = m_intf](vlc_medialibrary_t* ml, QString& error) {
            error = qtr("VLC cannot export this playlist. Select it again.");
            if (id.type != VLC_ML_PARENT_PLAYLIST || id.id <= 0 || !file.isLocalFile()) return;
            if (format != "export-xspf" && format != "export-m3u" && format != "export-m3u8" && format != "export-html") return;
            ml_unique_ptr<vlc_ml_playlist_t> source(vlc_ml_get_playlist(ml, id.id));
            if (!source) return;
            auto query = vlc_ml_query_params_create();
            ml_unique_ptr<vlc_ml_media_list_t> media(vlc_ml_list_playlist_media(ml, &query, id.id));
            if (!media) return;
            std::vector<SharedInputItem> items;
            std::vector<input_item_t*> pointers;
            for (const auto& entry : ml_range_iterate<vlc_ml_media_t>(media)) {
                SharedInputItem item(vlc_ml_get_input_item(ml, entry.i_id), false);
                if (!item) return;
                pointers.push_back(item.get());
                items.push_back(std::move(item));
            }
            /* An independent, non-playing queue keeps export separate from the
             * user's playback queue, selected item and shuffle setting. */
            auto queue = vlc::wrap_cptr(vlc_playlist_New(VLC_OBJECT(intf),
                VLC_PLAYLIST_PREPARSING_DISABLED, 1, 0), vlc_playlist_Delete);
            if (!queue) return;
            error = qtr("VLC cannot save this file. Select another location.");
            const QFileInfo destination(file.toLocalFile());
            QTemporaryFile temporary(destination.dir().filePath(QStringLiteral(".vlc-export-XXXXXX")));
            if (!temporary.open()) return;
            temporary.close();
            vlc_playlist_Lock(queue.get());
            int status = pointers.empty() ? VLC_SUCCESS :
                vlc_playlist_Insert(queue.get(), 0, pointers.data(), pointers.size());
            if (status == VLC_SUCCESS)
                status = vlc_playlist_Export(queue.get(), qtu(temporary.fileName()), format.constData());
            vlc_playlist_Unlock(queue.get());
            if (status != VLC_SUCCESS) return;
            QFile input(temporary.fileName());
            QSaveFile output(destination.filePath());
            if (!input.open(QIODevice::ReadOnly) || !output.open(QIODevice::WriteOnly)) return;
            while (!input.atEnd()) {
                const auto bytes = input.read(65536);
                if (bytes.isEmpty() || output.write(bytes) != bytes.size()) return;
            }
            if (input.error() != QFile::NoError || !output.commit()) return;
            error.clear();
        },
        [callback = std::move(callback)](quint64, const QString& error) { callback(error); },
        "redesign-playlist-export");
}

void MediaLib::addMediaTracks(const QUrl& url, const QList<QUrl>& tracks, bool subtitles,
                             QObject* receiver, std::function<void(const TrackAddition&)> callback)
{
    runOnMLThread<TrackAddition>(receiver,
        [url, tracks, subtitles](vlc_medialibrary_t* ml, TrackAddition& result) {
            if (!url.isValid() || url.scheme().isEmpty() ||
                (url.isLocalFile() && !QFileInfo(url.toLocalFile()).isFile())) {
                result.error = qtr("VLC cannot read this media. Select the file again.");
                return;
            }
            QList<QUrl> unique;
            QSet<QUrl> seen;
            for (const auto& track : tracks) {
                QFile file(track.toLocalFile());
                if (!track.isLocalFile() || track == url ||
                    !QFileInfo(file).isFile() || !file.open(QIODevice::ReadOnly)) {
                    result.error = qtr("VLC cannot read this track: %1").arg(track.toDisplayString());
                    return;
                }
                if (!seen.contains(track)) { seen.insert(track); unique.push_back(track); }
            }
            if (unique.isEmpty()) return;
            const auto mrl = url.toEncoded();
            ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media_by_mrl(ml, mrl.constData()));
            if (!media) media.reset(vlc_ml_new_external_media(ml, mrl.constData()));
            if (!media) {
                result.error = qtr("VLC cannot save this change. Try again.");
                return;
            }
            const auto type = subtitles ? VLC_ML_FILE_TYPE_SUBTITLE : VLC_ML_FILE_TYPE_SOUNDTRACK;
            for (const auto& track : unique) {
                bool found = false;
                if (media->p_files) {
                    for (const auto& file : ml_range_iterate<vlc_ml_file_t>(media->p_files)) {
                        if (QUrl(qfu(file.psz_mrl)) != track) continue;
                        if (file.i_type != type) {
                            result.error = qtr("VLC already uses this file for another track: %1").arg(track.fileName());
                            return;
                        }
                        found = true;
                        break;
                    }
                }
                if (found) continue;
                const auto uri = track.toEncoded();
                if (vlc_ml_media_add_external_mrl(ml, media->i_id, uri.constData(), type) != VLC_SUCCESS) {
                    result.error = qtr("VLC could not save this track: %1").arg(track.fileName());
                    return;
                }
                result.added.push_back(track);
            }
        },
        [callback = std::move(callback)](quint64, const TrackAddition& result) { callback(result); },
        "redesign-media-tracks");
}

void MediaLib::setMediaState(const QUrl& url, const QString& field, bool value, QJSValue callback)
{
    if (field != QLatin1String("played") && field != QLatin1String("favorite")) return;
    requestMediaState(url, field == QLatin1String("played") ? MediaStateAction::Played : MediaStateAction::Favorite, value, callback);
}

void MediaLib::requestMediaState(const QUrl& url, MediaStateAction action, bool value, QJSValue callback)
{
    if (!callback.isCallable()) return;
    struct Result { bool success = false; bool played = false; bool favorite = false; QString id; QString error; };
    const auto uri = url.toEncoded();
    const bool valid = url.isValid() && !url.scheme().isEmpty();
    runOnMLThread<Result>(this,
        [uri, valid, action, value](vlc_medialibrary_t* ml, Result& result) {
            result.error = qtr("VLC cannot read this media. Select the file again.");
            if (!valid) return;
            ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media_by_mrl(ml, uri.constData()));
            if (!media && action != MediaStateAction::Read) media.reset(vlc_ml_new_external_media(ml, uri.constData()));
            if (!media && action != MediaStateAction::Read) return;
            if (media) {
                result.error = qtr("VLC cannot save this change. Try again.");
                if (action == MediaStateAction::Played && vlc_ml_media_set_played(ml, media->i_id, value) != VLC_SUCCESS) return;
                if (action == MediaStateAction::Favorite && vlc_ml_media_set_favorite(ml, media->i_id, value) != VLC_SUCCESS) return;
                result.played = action == MediaStateAction::Played ? value : media->i_playcount > 0;
                result.favorite = action == MediaStateAction::Favorite ? value : media->b_is_favorite;
                result.id = MLItemId(media->i_id, VLC_ML_PARENT_UNKNOWN).toString();
            }
            result.success = true;
            result.error.clear();
        },
        [this, callback](quint64, const Result& result) mutable {
            if (auto engine = qjsEngine(this)) {
                const QVariantMap state {{"success", result.success}, {"played", result.played}, {"favorite", result.favorite}, {"id", result.id}, {"error", result.error}};
                callback.call({engine->toScriptValue(state)});
            }
        }, "redesign-media-state");
}

void MediaLib::mlInputItem(const QVector<MLItemId>& itemIdVector, QJSValue callback)
{
    if (!callback.isCallable()) // invalid argument
    {
        msg_Warn(m_intf, "callback is not callbable");
        return;
    }

    struct Ctx {
        std::vector<SharedInputItem> items;
    };

    if (itemIdVector.empty())
    {
        //call the callback with and empty list
        auto jsEngine = qjsEngine(this);
        if (!jsEngine)
            return;
        auto jsArray = jsEngine->newArray(0);
        callback.call({jsArray});
        return;
    }

    auto it = m_inputItemQuery.find(itemIdVector);

    if (it == m_inputItemQuery.end())
    {
        it = m_inputItemQuery.insert(itemIdVector, {callback});
    }
    else
    {
        // be patient

        for (const auto& it2 : it.value())
        {
            if (callback.strictlyEquals(it2))
                return;
        }

        it.value().push_back(callback); // FIXME: Use an ordered set
        return;
    }

    runOnMLThread<Ctx>(this,
    //ML thread
    [itemIdVector](vlc_medialibrary_t* ml, Ctx& ctx){
        for (auto mlId : itemIdVector)
        {
            // NOTE: When we have a parent it's a collection of media(s).
            if (mlId.type == VLC_ML_PARENT_UNKNOWN)
            {
                ctx.items.emplace_back(vlc_ml_get_input_item(ml, mlId.id), false);
            }
            else
            {
                ml_unique_ptr<vlc_ml_media_list_t> list;

                vlc_ml_query_params_t query = vlc_ml_query_params_create();

                list.reset(vlc_ml_list_media_of(ml, &query, mlId.type, mlId.id));

                if (list == nullptr)
                    continue;

                for (const vlc_ml_media_t & media : ml_range_iterate<vlc_ml_media_t>(list))
                    ctx.items.emplace_back(vlc_ml_get_input_item(ml, media.i_id), false);
            }
        }
    },
    //UI thread
    [this, it](quint64, Ctx& ctx) mutable
    {
        auto jsEngine = qjsEngine(this);
        if (!jsEngine)
            return;

        auto jsArray = jsEngine->newArray(ctx.items.size());

        int i  = 0;
        for (const auto& inputItem : ctx.items)
        {
            jsArray.setProperty(i, jsEngine->toScriptValue(inputItem));
            i++;
        }

        for (const auto& cb : std::as_const(it.value()))
        {
            cb.call({jsArray});
        }

        m_inputItemQuery.erase(it);
    });
}

vlc_ml_event_callback_t* MediaLib::registerEventListener( void (*callback)(void*, const vlc_ml_event_t*), void* data)
{
    return vlc_ml_event_register_callback( m_ml , callback , data ) ;
}

void MediaLib::unregisterEventListener(vlc_ml_event_callback_t* cb)
{
    vlc_ml_event_unregister_callback( m_ml , cb );
}

void MediaLib::onMediaLibraryEvent( void* data, const vlc_ml_event_t* event )
{
    MediaLib* self = static_cast<MediaLib*>( data );
    switch ( event->i_type )
    {
        case VLC_ML_EVENT_PARSING_PROGRESS_UPDATED:
        {
            int percent =  event->parsing_progress.i_percent;
            QMetaObject::invokeMethod(self, [self, percent]() {
                self->m_parsingProgress = percent;
                self->emit parsingProgressChanged(percent);
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_STARTED:
        {
            QMetaObject::invokeMethod(self, [self]() {
                self->m_discoveryPending = true;
                self->emit discoveryPendingChanged(self->m_discoveryPending);
                self->emit discoveryStarted();
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_PROGRESS:
        {
            const QUrl entryPoint{ event->discovery_progress.psz_entry_point };
            const QString entryPointStr = entryPoint.isLocalFile()
                                              ? entryPoint.toLocalFile()
                                              : entryPoint.toDisplayString();

            QMetaObject::invokeMethod(self, [self, entryPointStr]() {
                self->m_discoveryEntryPoint = entryPointStr;
                self->emit discoveryEntryPointChanged(entryPointStr);
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_COMPLETED:
        {
            QMetaObject::invokeMethod(self, [self]() {
                self->m_discoveryPending = false;
                self->emit discoveryPendingChanged(self->m_discoveryPending);
                self->emit discoveryCompleted();
            });
            break;
        }
        case VLC_ML_EVENT_BACKGROUND_IDLE_CHANGED:
        {
            bool idle = event->background_idle_changed.b_idle;
            QMetaObject::invokeMethod(self, [self, idle]() {
                self->m_idle = idle;
                self->emit idleChanged();
            });
            break;
        }
        default:
            break;
    }
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                std::function< void()> uiCb,
                const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [uiCb](quint64, NoCtx&){
        uiCb();
    },
    queue);
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                std::function< void(quint64)> uiCb, const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [uiCb](quint64 requestId, NoCtx&){
        uiCb(requestId);
    },
    queue);
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [](quint64, NoCtx&){
    },
    queue);
}

void MediaLib::cancelMLTask(const QObject* object, quint64 taskId)
{
    m_runner->cancelTask(object, taskId);
}

