// SPDX-License-Identifier: LGPL-2.1-or-later
#pragma once

#include <algorithm>
#include <cctype>
#include <optional>
#include <regex>
#include <set>
#include <string>
#include <vector>

namespace vlc::medialibrary::trackrules {

inline std::string nativePath(std::string value)
{
#ifdef _WIN32
    std::replace(value.begin(), value.end(), '/', '\\');
#endif
    return value;
}

struct Pair {
    std::string media;
    std::string track;
    std::string source = {};
};

inline constexpr size_t MaxBytes = 1024 * 1024;
inline constexpr size_t MaxPairs = 1024;

inline std::string path(std::string value)
{
    std::replace(value.begin(), value.end(), '\\', '/');
    return value;
}

inline std::string fileName(const std::string& value)
{
    const auto at = value.find_last_of("/\\");
    return value.substr(at == std::string::npos ? 0 : at + 1);
}

inline std::string stem(const std::string& value)
{
    auto name = fileName(value);
    const auto at = name.find_last_of('.');
    return at == std::string::npos ? name : name.substr(0, at);
}

inline std::string parent(const std::string& value)
{
    const auto normal = path(value); const auto at = normal.find_last_of('/');
    return at == std::string::npos ? std::string() : normal.substr(0, at == 0 ? 1 : at);
}

inline std::string compact(const std::string& value)
{
    std::string result;
    for (const unsigned char ch : value) {
        if (ch >= 0x80) result.push_back(ch);
        else if (ch >= 'A' && ch <= 'Z') result.push_back(ch + ('a' - 'A'));
        else if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) result.push_back(ch);
    }
    return result;
}

struct Episode {
    size_t start, end, seasonAt, seasonWidth, numberAt, numberWidth;
    unsigned season, number;
};

inline std::vector<Episode> episodes(const std::string& value)
{
    static const std::regex pattern("[sS]([0-9]{1,3})[ ._-]*[eE]([0-9]{1,4})|([0-9]{1,3})[xX]([0-9]{1,4})");
    std::vector<Episode> result;
    for (auto it = std::sregex_iterator(value.begin(), value.end(), pattern); it != std::sregex_iterator(); ++it) {
        const auto& match = *it;
        const size_t start = match.position(), end = start + match.length();
        if ((start && value[start - 1] >= '0' && value[start - 1] <= '9')
            || (end < value.size() && value[end] >= '0' && value[end] <= '9')) continue;
        const int a = match[1].matched ? 1 : 3, b = a + 1;
        result.push_back({start, end, size_t(match.position(a)), size_t(match.length(a)),
            size_t(match.position(b)), size_t(match.length(b)),
            unsigned(std::stoul(match[a].str())), unsigned(std::stoul(match[b].str()))});
    }
    return result;
}

inline std::string digits(unsigned value, size_t width)
{
    auto text = std::to_string(value);
    return std::string(width > text.size() ? width - text.size() : 0, '0') + text;
}

inline std::string family(const std::string& media)
{
    const auto name = stem(media); const auto markers = episodes(name);
    return markers.empty() ? "*" : "e|" + compact(name.substr(0, markers.front().start));
}

inline std::vector<Episode> trackEpisodes(const Pair& pair, const Episode& sample)
{
    const auto track = path(pair.track);
    const auto root = pair.source.empty() ? parent(track) : path(pair.source);
    size_t begin = track.size() - fileName(track).size();
    if (!root.empty() && track.compare(0, root.size(), root) == 0
        && (root.back() == '/' || (track.size() > root.size() && track[root.size()] == '/'))) {
        begin = root.size() + (root.back() == '/' ? 0 : 1);
        for (const auto& marker : episodes(fileName(root)))
            if (marker.season == sample.season && marker.number == sample.number) {
                const auto outer = parent(root); begin = outer.empty() ? 0 : outer.size() + (outer.back() == '/' ? 0 : 1); break;
            }
    }
    auto matches = episodes(track.substr(begin));
    for (auto& marker : matches) {
        marker.start += begin; marker.end += begin; marker.seasonAt += begin; marker.numberAt += begin;
    }
    return matches;
}

inline std::optional<std::string> expected(const Pair& pair, const std::string& media)
{
    const auto sampleStem = stem(pair.media), mediaStem = stem(media);
    const auto sample = episodes(sampleStem), current = episodes(mediaStem);
    if (!sample.empty()) {
        const auto tracks = trackEpisodes(pair, sample.front());
        if (current.empty() || tracks.empty()) return {};
        const auto& a = sample.front(); const auto& b = current.front(); const auto& last = tracks.back();
        if (compact(sampleStem.substr(0, a.start)) != compact(mediaStem.substr(0, b.start))
            || last.season != a.season || last.number != a.number) return {};
        auto result = path(pair.track);
        for (auto it = tracks.rbegin(); it != tracks.rend(); ++it) {
            if (it->season != a.season || it->number != a.number) continue;
            result.replace(it->numberAt, it->numberWidth, digits(b.number, it->numberWidth));
            result.replace(it->seasonAt, it->seasonWidth, digits(b.season, it->seasonWidth));
        }
        return result;
    }
    // For files without an episode number, preserve a filename-based suffix.
    const auto trackName = fileName(pair.track);
    if (sampleStem.empty() || trackName.size() <= sampleStem.size()
        || compact(trackName.substr(0, sampleStem.size())) != compact(sampleStem)) return {};
    const auto suffix = trackName.substr(sampleStem.size());
    if (suffix.front() != '.' && suffix.front() != '_' && suffix.front() != ' ') return {};
    return pair.track.substr(0, pair.track.size() - trackName.size()) + mediaStem + suffix;
}

inline std::string signature(const Pair& pair)
{
    auto name = stem(pair.media); const auto episode = episodes(name);
    if (!episode.empty()) {
        const auto marker = episode.front();
        const auto sample = expected(pair, pair.media);
        if (!sample) return {};
        auto pattern = pair.track;
        const auto matches = trackEpisodes(pair, marker);
        for (auto it = matches.rbegin(); it != matches.rend(); ++it) {
            if (it->season != marker.season || it->number != marker.number) continue;
            pattern.replace(it->numberAt, it->numberWidth, std::string(it->numberWidth, '#'));
            pattern.replace(it->seasonAt, it->seasonWidth, std::string(it->seasonWidth, '#'));
        }
        return compact(name.substr(0, marker.start)) + "|" + pattern;
    }
    const auto sample = expected(pair, pair.media);
    if (!sample) return {};
    const auto trackName = fileName(pair.track);
    return "*|" + pair.track.substr(0, pair.track.size() - trackName.size()) + trackName.substr(name.size());
}

inline std::vector<Pair> distinct(const std::vector<Pair>& pairs)
{
    std::set<std::string> seen; std::vector<Pair> result;
    for (auto pair : pairs) {
        pair.media = fileName(pair.media); pair.track = path(pair.track);
        pair.source = pair.source.empty() ? parent(pair.track) : path(pair.source);
        const auto key = signature(pair);
        if (!key.empty() && seen.insert(key).second) result.push_back(std::move(pair));
    }
    return result;
}

inline std::string encode(const std::vector<Pair>& pairs)
{
    std::string result = "1|";
    for (const auto& pair : pairs) for (const auto& field : {pair.media, pair.track, pair.source.empty() ? parent(pair.track) : pair.source})
        result += std::to_string(field.size()) + ":" + field;
    return result;
}

inline bool decode(const std::string& text, std::vector<Pair>& pairs)
{
    pairs.clear();
    if (text.size() > MaxBytes || text.compare(0, 2, "1|") != 0 || text.find('\0') != std::string::npos) return false;
    size_t at = 2;
    auto field = [&](std::string& value) {
        if (at == text.size() || text[at] < '0' || text[at] > '9') return false;
        size_t length = 0;
        while (at < text.size() && text[at] >= '0' && text[at] <= '9') {
            length = length * 10 + text[at++] - '0';
            if (length > 8192) return false;
        }
        if (at == text.size() || text[at++] != ':' || length == 0 || length > text.size() - at) return false;
        value = text.substr(at, length); at += length; return true;
    };
    while (at < text.size()) {
        Pair pair;
        if (pairs.size() == MaxPairs || !field(pair.media) || !field(pair.track) || !field(pair.source)
            || pair.media != fileName(pair.media) || signature(pair).empty()) { pairs.clear(); return false; }
        pairs.push_back(std::move(pair));
    }
    return true;
}

} // namespace vlc::medialibrary::trackrules
