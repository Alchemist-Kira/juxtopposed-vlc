// SPDX-License-Identifier: GPL-2.0-or-later
#include "mlplayedartistmodel.hpp"
#include "mlhelper.hpp"
#include <algorithm>
#include <unordered_map>

std::unique_ptr<MLListCacheLoader> MLPlayedArtistModel::createMLLoader() const
{
    return std::make_unique<MLListCacheLoader>(m_mediaLib, std::make_shared<Loader>(*this));
}

void MLPlayedArtistModel::onVlcMlEvent(const MLEvent& event)
{
    switch (event.i_type) {
    case VLC_ML_EVENT_HISTORY_CHANGED:
    case VLC_ML_EVENT_MEDIA_UPDATED:
    case VLC_ML_EVENT_MEDIA_DELETED:
    case VLC_ML_EVENT_ARTIST_UPDATED:
    case VLC_ML_EVENT_ARTIST_DELETED:
        emit resetRequested();
        return;
    default:
        MLArtistModel::onVlcMlEvent(event);
    }
}

const std::vector<int64_t>& MLPlayedArtistModel::Loader::rankedArtists(vlc_medialibrary_t* ml) const
{
    std::lock_guard<std::mutex> lock(mutex);
    if (ranked) return *ranked;
    std::unordered_map<int64_t, uint64_t> totals;
    vlc_ml_query_params_t query{};
    query.i_sort = VLC_ML_SORTING_PLAYCOUNT;
    // PlayCount uses decreasing order by default in the media library. Keep
    // zero-play history entries last so the early stop below is valid.
    query.b_desc = false;
    query.i_nbResults = 256;
    // Work only on listening history. Clearing history also clears this list.
    bool done = false;
    while (!done) {
        ml_unique_ptr<vlc_ml_media_list_t> tracks{vlc_ml_list_audio_history(ml, &query)};
        if (!tracks) break;
        for (const auto& track : ml_range_iterate<vlc_ml_media_t>(tracks)) {
            if (track.i_playcount == 0) { done = true; break; }
            if (track.i_subtype == VLC_ML_MEDIA_SUBTYPE_ALBUMTRACK && track.album_track.i_artist_id > 0
                && track.i_last_played_date > 0)
                totals[track.album_track.i_artist_id] += track.i_playcount;
        }
        if (tracks->i_nb_items < query.i_nbResults) break;
        query.i_offset += query.i_nbResults;
    }
    std::vector<std::pair<int64_t, uint64_t>> sorted(totals.begin(), totals.end());
    std::sort(sorted.begin(), sorted.end(), [](const auto& a, const auto& b) {
        return a.second == b.second ? a.first < b.first : a.second > b.second;
    });
    std::vector<std::pair<int64_t, QString>> matches;
    const auto pattern = QString::fromUtf8(m_searchPattern);
    for (const auto& [id, plays] : sorted) {
        ml_unique_ptr<vlc_ml_artist_t> artist{vlc_ml_get_artist(ml, id)};
        if (artist && QString::fromUtf8(artist->psz_name).contains(pattern, Qt::CaseInsensitive))
            matches.emplace_back(id, QString::fromUtf8(artist->psz_name));
    }
    if (m_sortName == "title" || m_sortName == "name")
        std::sort(matches.begin(), matches.end(), [this](const auto& a, const auto& b) {
            const int name = QString::compare(a.second, b.second, Qt::CaseInsensitive);
            return name ? (m_sortDesc ? name > 0 : name < 0) : a.first < b.first;
        });
    std::vector<int64_t> result;
    for (const auto& match : matches) result.push_back(match.first);
    ranked = std::move(result);
    return *ranked;
}

size_t MLPlayedArtistModel::Loader::count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t*) const
{
    return rankedArtists(ml).size();
}

std::vector<std::unique_ptr<MLItem>> MLPlayedArtistModel::Loader::load(
    vlc_medialibrary_t* ml, const vlc_ml_query_params_t* query) const
{
    const auto& ids = rankedArtists(ml);
    const size_t end = query->i_nbResults ? std::min(ids.size(), size_t(query->i_offset) + query->i_nbResults) : ids.size();
    std::vector<std::unique_ptr<MLItem>> result;
    for (size_t i = query->i_offset; i < end; ++i) {
        auto item = loadItemById(ml, MLItemId(ids[i], VLC_ML_PARENT_ARTIST));
        if (item) result.push_back(std::move(item));
    }
    return result;
}

std::unique_ptr<MLItem> MLPlayedArtistModel::Loader::loadItemById(vlc_medialibrary_t* ml, MLItemId id) const
{
    ml_unique_ptr<vlc_ml_artist_t> artist{vlc_ml_get_artist(ml, id.id)};
    return artist ? std::make_unique<MLArtist>(artist.get()) : nullptr;
}
