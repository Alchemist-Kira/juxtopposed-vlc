// SPDX-License-Identifier: GPL-2.0-or-later
#ifndef VLC_SEEK_PREVIEW_CACHE_HPP
#define VLC_SEEK_PREVIEW_CACHE_HPP

#include <QCache>
#include <QUrl>
#include <QVector>
#include <algorithm>
#include <deque>
#include <cmath>
#include <optional>

class SeekPreviewCache
{
public:
    struct Frame { QUrl image; qint64 time; };
    static constexpr qint64 Bucket = 500000;
    static constexpr int MaximumSamples = 24;

    void clear() { m_precise.clear(); m_sampled.clear(); }
    bool insert(qint64 requested, const QUrl& image, qint64 decoded, bool sampled) {
        if (image.isEmpty()) return false;
        return (sampled ? m_sampled : m_precise).insert(requested, new Frame{image, decoded});
    }
    std::optional<Frame> exact(qint64 time) const {
        const auto* frame = m_precise.object(time);
        return frame ? std::optional<Frame>(*frame) : std::nullopt;
    }
    std::optional<Frame> nearest(qint64 time) const {
        std::optional<Frame> result;
        for (const auto* cache : {&m_precise, &m_sampled}) {
            for (auto key : cache->keys()) {
                const auto* frame = cache->object(key);
                if (!result || std::abs(frame->time - time) < std::abs(result->time - time))
                    result = *frame;
            }
        }
        return result;
    }
    int count(bool sampled) const { return (sampled ? m_sampled : m_precise).size(); }

    // Spread the first results across the timeline, then fill the gaps. Aim for
    // roughly five-second spacing and keep a separate bounded sample cache.
    static QVector<qint64> samplesFor(qint64 duration) {
        if (duration <= 0) return {};
        const qint64 last = (duration - 1) / Bucket;
        const int count = last >= (MaximumSamples - 1) * 10 ? MaximumSamples
            : int((last + 9) / 10 + 1);
        QVector<qint64> result{0};
        if (count == 1) return result;
        const auto timeAt = [last, count](int index) { return last * index / (count - 1) * Bucket; };
        result.push_back(timeAt(count - 1));
        std::deque<std::pair<int, int>> gaps{{0, count - 1}};
        while (!gaps.empty()) {
            const auto [first, end] = gaps.front();
            gaps.pop_front();
            if (end - first <= 1) continue;
            const int middle = first + (end - first) / 2;
            result.push_back(timeAt(middle));
            gaps.emplace_back(first, middle);
            gaps.emplace_back(middle, end);
        }
        return result;
    }
private:
    QCache<qint64, Frame> m_precise{32};
    QCache<qint64, Frame> m_sampled{MaximumSamples};
};
#endif
