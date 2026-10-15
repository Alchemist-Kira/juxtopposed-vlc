// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QFileInfo>
#include <QMap>
#include <QRegularExpression>
#include <QSet>
#include <QUrl>

namespace TrackMatching {
inline QString stem(const QUrl& url)
{
    static const QRegularExpression separators(QStringLiteral("[^\\p{L}\\p{N}]+"));
    return QFileInfo(url.fileName()).completeBaseName()
        .normalized(QString::NormalizationForm_KC).toCaseFolded()
        .replace(separators, QStringLiteral(" ")).trimmed();
}

struct Episode {
    QString show;
    int season = -1;
    int number = -1;
};

inline Episode episode(const QString& name)
{
    static const QRegularExpression pattern(QStringLiteral(
        "(?:^| )(?:(?:s(\\d{1,3}) ?e(\\d{1,4}))|(?:(\\d{1,3})x(\\d{1,4})))(?: |$)"));
    const auto match = pattern.match(name);
    if (!match.hasMatch()) return {};
    const bool longForm = !match.captured(1).isEmpty();
    return {name.left(match.capturedStart()).trimmed(),
        match.captured(longForm ? 1 : 3).toInt(), match.captured(longForm ? 2 : 4).toInt()};
}

inline int score(const QUrl& media, const QUrl& track)
{
    const auto target = stem(media), source = stem(track);
    if (target.isEmpty() || source.isEmpty()) return 0;
    if (target == source) return 100;
    const auto a = episode(target), b = episode(source);
    if (a.number >= 0 && b.number >= 0) {
        if (a.number != b.number || a.season != b.season) return 0;
        if (a.show == b.show) return 90;
        return a.show.isEmpty() || b.show.isEmpty() ? 50 : 0;
    }
    if (!source.startsWith(target + QLatin1Char(' '))) return 0;
    // Only treat known track labels as suffixes. A short film title must not
    // silently match a different film whose name starts with the same words.
    static const QSet<QString> labels = [] {
        const auto words = QStringLiteral("en eng english es spa spanish ja jpn japanese de deu ger german "
            "nl nld dut dutch fr fra fre french ar ara arabic pt por portuguese br brazilian "
            "hi hin hindi ko kor korean zh zho chi chinese ru rus russian pl pol polish "
            "it ita italian uk ukr ukrainian sv swe swedish no nor norwegian da dan danish "
            "fi fin finnish tr tur turkish cs ces cze czech ro ron rum romanian hu hun hungarian "
            "forced sdh cc commentary default full signs songs subtitles subs audio stereo surround "
            "0 1 2 5 7 ac3 eac3 dts flac opus aac mp3 wav atmos truehd").split(QLatin1Char(' '));
        return QSet<QString>(words.cbegin(), words.cend());
    }();
    const auto suffix = source.mid(target.size() + 1).split(QLatin1Char(' '));
    for (const auto& word : suffix) if (!labels.contains(word)) return 0;
    return 80;
}

inline QMap<QUrl, QList<QUrl>> match(const QList<QUrl>& media, const QList<QUrl>& tracks)
{
    QMap<QUrl, QList<QUrl>> result;
    QSet<QUrl> seen;
    for (const auto& track : tracks) {
        if (seen.contains(track)) continue;
        seen.insert(track);
        int best = 0;
        QSet<QUrl> targets;
        for (const auto& file : media) {
            if (file == track) continue;
            const int value = score(file, track);
            if (value > best) { best = value; targets.clear(); }
            if (value > 0 && value == best) targets.insert(file);
        }
        // A duplicate playlist entry is one media. Distinct locations with
        // the same name are ambiguous and require a manual choice.
        if (targets.size() == 1) result[*targets.cbegin()].append(track);
    }
    return result;
}
}
