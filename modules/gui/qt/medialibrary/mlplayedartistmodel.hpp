// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include "mlartistmodel.hpp"
#include <mutex>
#include <optional>

// Rank artists by the sum of their tracks' play counts. Artist name/track-count
// sorting cannot represent listening frequency.
class MLPlayedArtistModel : public MLArtistModel
{
    Q_OBJECT
public:
    explicit MLPlayedArtistModel(QObject* parent = nullptr) : MLArtistModel(parent) {}
protected:
    std::unique_ptr<MLListCacheLoader> createMLLoader() const override;
    void onVlcMlEvent(const MLEvent& event) override;
private:
    struct Loader : MLListCacheLoader::MLOp {
        using MLOp::MLOp;
        size_t count(vlc_medialibrary_t*, const vlc_ml_query_params_t*) const override;
        std::vector<std::unique_ptr<MLItem>> load(vlc_medialibrary_t*, const vlc_ml_query_params_t*) const override;
        std::unique_ptr<MLItem> loadItemById(vlc_medialibrary_t*, MLItemId) const override;
        const std::vector<int64_t>& rankedArtists(vlc_medialibrary_t*) const;
        mutable std::mutex mutex;
        mutable std::optional<std::vector<int64_t>> ranked;
    };
};
