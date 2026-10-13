// SPDX-License-Identifier: GPL-2.0-or-later
#include "redesign_preferences.hpp"
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>
#include <cmath>
#include <algorithm>
#include <QFileDialog>
#include <QColorDialog>
#include <QGuiApplication>
#include <QScreen>

namespace {
QString categoryFor(const QString& name, int subcat)
{
    if (name.startsWith(QLatin1String("key-")) || name.startsWith(QLatin1String("global-key-"))
        || name.startsWith(QLatin1String("hotkeys-")) || name.startsWith(QLatin1String("mouse-"))
        || name.endsWith(QLatin1String("-jump-size"))) return QStringLiteral("controls");
    if (name.startsWith(QLatin1String("sub-")) || name.startsWith(QLatin1String("subsdec-"))
        || name.startsWith(QLatin1String("freetype-")) || name == QLatin1String("spu")) return QStringLiteral("subtitles");
    if (name.startsWith(QLatin1String("record")) || subcat / 100 == 5) return QStringLiteral("recording");
    if (name.contains(QLatin1String("caching")) || name.startsWith(QLatin1String("avcodec-"))
        || subcat == SUBCAT_INPUT_VCODEC || subcat == SUBCAT_INPUT_ACODEC) return QStringLiteral("performance");
    if (subcat == SUBCAT_ADVANCED_NETWORK || subcat == SUBCAT_INPUT_ACCESS
        || name.startsWith(QLatin1String("http-"))) return QStringLiteral("network");
    if (name.startsWith(QLatin1String("metadata-")) || name.contains(QLatin1String("scrobbler"))) return QStringLiteral("privacy");
    if (name.startsWith(QLatin1String("qt-"))) return QStringLiteral("interface");
    switch (subcat / 100) {
    case 2: return QStringLiteral("audio");
    case 3: return subcat == SUBCAT_VIDEO_SUBPIC ? QStringLiteral("subtitles") : QStringLiteral("video");
    case 4: return QStringLiteral("playback");
    case 7: return QStringLiteral("library");
    default: return QStringLiteral("general");
    }
}
}

RedesignPreferences::RedesignPreferences(QObject* parent) : QObject(parent)
{
    size_t count = 0;
    module_t** modules = module_list_get(&count);
    for (size_t i = 0; i < count; ++i) {
        unsigned size = 0;
        module_config_t* configs = module_config_get(modules[i], &size);
        int subcat = SUBCAT_UNKNOWN;
        for (unsigned j = 0; j < size; ++j) {
            const module_config_t& cfg = configs[j];
            if (cfg.i_type == CONFIG_SUBCATEGORY) { subcat = cfg.value.i; continue; }
            if (!CONFIG_ITEM(cfg.i_type) || !cfg.psz_name || !cfg.psz_text
                || subcat == SUBCAT_HIDDEN || subcat == SUBCAT_UNKNOWN) continue;
            const QString name = qfu(cfg.psz_name);
            m_catalog.append({name, categoryFor(name, subcat), qtr(cfg.psz_text)});
        }
        module_config_free(configs);
    }
    module_list_free(modules);
    std::sort(m_catalog.begin(), m_catalog.end(), [](const Entry& a, const Entry& b) {
        return QString::localeAwareCompare(a.title, b.title) < 0;
    });
}

void RedesignPreferences::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx) return;
    m_ctx = ctx;
    emit ctxChanged();
}

QVariant RedesignPreferences::read(const QByteArray& name)
{
    const auto* cfg = config_FindConfig(name.constData());
    if (!cfg) return {};
    switch (CONFIG_CLASS(cfg->i_type)) {
    case CONFIG_ITEM_BOOL: return bool(config_GetInt(name.constData()));
    case CONFIG_ITEM_INTEGER: return QVariant::fromValue<qlonglong>(config_GetInt(name.constData()));
    case CONFIG_ITEM_FLOAT: return config_GetFloat(name.constData());
    case CONFIG_ITEM_STRING: {
        char* text = config_GetPsz(name.constData());
        const QString result = qfu(text ? text : "");
        free(text);
        return result;
    }
    default: return {};
    }
}

void RedesignPreferences::write(const QByteArray& name, const QVariant& value)
{
    const auto* cfg = config_FindConfig(name.constData());
    if (!cfg) return;
    switch (CONFIG_CLASS(cfg->i_type)) {
    case CONFIG_ITEM_BOOL:
    case CONFIG_ITEM_INTEGER: config_PutInt(name.constData(), value.toLongLong()); break;
    case CONFIG_ITEM_FLOAT: config_PutFloat(name.constData(), value.toFloat()); break;
    case CONFIG_ITEM_STRING: config_PutPsz(name.constData(), value.toString().toUtf8().constData()); break;
    }
}

QVariant RedesignPreferences::value(const QString& name) const
{
    if (name == QLatin1String("redesign-repeat"))
        return value(QStringLiteral("repeat")).toBool() ? 1 : value(QStringLiteral("loop")).toBool() ? 2 : 0;
    if (name == QLatin1String("redesign-after-playback"))
        return value(QStringLiteral("play-and-exit")).toBool() ? 1 : value(QStringLiteral("play-and-pause")).toBool() ? 2 : 0;
    if (name.startsWith(QLatin1String("filter:"))) {
        const auto parts = name.split(QLatin1Char(':'));
        return parts.size() == 3 && value(parts[1]).toString().split(QLatin1Char(':')).contains(parts[2]);
    }

    const auto it = m_edits.constFind(name);
    return it == m_edits.cend() ? read(name.toUtf8()) : *it;
}

QVariantMap RedesignPreferences::describe(const QString& name) const
{
    if (name == QLatin1String("redesign-repeat") || name == QLatin1String("redesign-after-playback")) {
        const bool repeat = name == QLatin1String("redesign-repeat");
        const QStringList labels = repeat ? QStringList{qtr("Off"), qtr("Current item"), qtr("All items")}
            : QStringList{qtr("Stop"), qtr("Quit VLC"), qtr("Pause on the last frame")};
        QVariantList choices;
        for (int i = 0; i < labels.size(); ++i) choices.append(QVariantMap{{QStringLiteral("label"), labels[i]}, {QStringLiteral("value"), i}});
        return {{QStringLiteral("kind"), QStringLiteral("integer")}, {QStringLiteral("title"), repeat ? qtr("Repeat") : qtr("When playback finishes")},
            {QStringLiteral("choices"), choices}, {QStringLiteral("defaultValue"), 0}, {QStringLiteral("value"), value(name)}};
    }
    if (name.startsWith(QLatin1String("filter:"))) {
        const auto parts = name.split(QLatin1Char(':'));
        if (parts.size() != 3 || !module_exists(parts[2].toUtf8().constData())) return {};
        return {{QStringLiteral("kind"), QStringLiteral("bool")}, {QStringLiteral("title"), parts[2]},
            {QStringLiteral("value"), value(name)}, {QStringLiteral("defaultValue"), false}};
    }

    const QByteArray bytes = name.toUtf8();
    const auto* cfg = config_FindConfig(bytes.constData());
    if (!cfg || !CONFIG_ITEM(cfg->i_type)) return {};
    QVariantMap result{{QStringLiteral("name"), name}, {QStringLiteral("title"), qtr(cfg->psz_text ? cfg->psz_text : cfg->psz_name)},
        {QStringLiteral("help"), qtr(cfg->psz_longtext ? cfg->psz_longtext : "")}, {QStringLiteral("value"), value(name)}};
    QVariantList choices;
    QString kind;
    switch (CONFIG_CLASS(cfg->i_type)) {
    case CONFIG_ITEM_BOOL:
        kind = QStringLiteral("bool"); result.insert(QStringLiteral("defaultValue"), bool(cfg->orig.i)); break;
    case CONFIG_ITEM_INTEGER: {
        kind = QStringLiteral("integer");
        result.insert(QStringLiteral("defaultValue"), QVariant::fromValue<qlonglong>(cfg->orig.i));
        result.insert(QStringLiteral("minimum"), QVariant::fromValue<qlonglong>(cfg->min.i));
        result.insert(QStringLiteral("maximum"), QVariant::fromValue<qlonglong>(cfg->max.i));
        int64_t* values = nullptr; char** labels = nullptr;
        const ssize_t count = config_GetIntChoices(bytes.constData(), &values, &labels);
        for (ssize_t i = 0; i < count; ++i) {
            choices.append(QVariantMap{{QStringLiteral("label"), qfu(labels[i])}, {QStringLiteral("value"), QVariant::fromValue<qlonglong>(values[i])}});
            free(labels[i]);
        }
        free(values); free(labels);
        break;
    }
    case CONFIG_ITEM_FLOAT:
        kind = QStringLiteral("float"); result.insert(QStringLiteral("defaultValue"), cfg->orig.f);
        result.insert(QStringLiteral("minimum"), cfg->min.f); result.insert(QStringLiteral("maximum"), cfg->max.f); break;
    case CONFIG_ITEM_STRING: {
        kind = cfg->i_type == CONFIG_ITEM_PASSWORD ? QStringLiteral("password") : QStringLiteral("string");
        result.insert(QStringLiteral("defaultValue"), qfu(cfg->orig.psz ? cfg->orig.psz : ""));
        char** values = nullptr; char** labels = nullptr;
        const ssize_t count = config_GetPszChoices(bytes.constData(), &values, &labels);
        for (ssize_t i = 0; i < count; ++i) {
            choices.append(QVariantMap{{QStringLiteral("label"), qfu(labels[i])}, {QStringLiteral("value"), qfu(values[i])}});
            free(values[i]); free(labels[i]);
        }
        free(values); free(labels);
        break;
    }
    }
    QString editor;
    switch (cfg->i_type) {
    case CONFIG_ITEM_LOADFILE: case CONFIG_ITEM_SAVEFILE: editor = QStringLiteral("file"); break;
    case CONFIG_ITEM_DIRECTORY: editor = QStringLiteral("directory"); break;
    case CONFIG_ITEM_RGB: editor = QStringLiteral("color"); break;
    }
    if (name == QLatin1String("qt-fullscreen-screennumber")) {
        choices.append(QVariantMap{{QStringLiteral("label"), qtr("Current screen")}, {QStringLiteral("value"), -1}});
        const auto screens = QGuiApplication::screens();
        for (int i = 0; i < screens.size(); ++i)
            choices.append(QVariantMap{{QStringLiteral("label"), screens[i]->name()}, {QStringLiteral("value"), i}});
    }
    result.insert(QStringLiteral("editor"), editor);
    result.insert(QStringLiteral("kind"), kind);
    result.insert(QStringLiteral("choices"), choices);
    return result;
}

bool RedesignPreferences::stage(const QString& name, const QVariant& proposed)
{
    if (name == QLatin1String("redesign-repeat") || name == QLatin1String("redesign-after-playback")) {
        const int choice = proposed.toInt();
        if (choice < 0 || choice > 2) return false;
        const bool repeat = name == QLatin1String("redesign-repeat");
        stage(repeat ? QStringLiteral("repeat") : QStringLiteral("play-and-exit"), choice == 1);
        return stage(repeat ? QStringLiteral("loop") : QStringLiteral("play-and-pause"), choice == 2);
    }
    if (name.startsWith(QLatin1String("filter:"))) {
        const auto parts = name.split(QLatin1Char(':'));
        if (parts.size() != 3 || !module_exists(parts[2].toUtf8().constData())) return false;
        auto filters = value(parts[1]).toString().split(QLatin1Char(':'), Qt::SkipEmptyParts);
        filters.removeAll(parts[2]);
        if (proposed.toBool()) filters.append(parts[2]);
        return stage(parts[1], filters.join(QLatin1Char(':')));
    }

    const auto* cfg = config_FindConfig(name.toUtf8().constData());
    if (!cfg || !CONFIG_ITEM(cfg->i_type)) return false;
    QVariant normalized;
    bool valid = true;
    switch (CONFIG_CLASS(cfg->i_type)) {
    case CONFIG_ITEM_BOOL: normalized = proposed.toBool(); break;
    case CONFIG_ITEM_INTEGER: {
        const qlonglong v = proposed.toLongLong(&valid);
        valid = valid && (cfg->min.i == cfg->max.i || (v >= cfg->min.i && v <= cfg->max.i));
        normalized = QVariant::fromValue(v); break;
    }
    case CONFIG_ITEM_FLOAT: {
        const double v = proposed.toDouble(&valid);
        valid = valid && std::isfinite(v) && (cfg->min.f == cfg->max.f || (v >= cfg->min.f && v <= cfg->max.f));
        normalized = float(v); break;
    }
    case CONFIG_ITEM_STRING: normalized = proposed.toString(); break;
    default: valid = false; break;
    }
    if (!valid) {
        m_invalid.insert(name);
        m_error = qtr("Enter a value within the allowed range.");
        ++m_revision; emit changed(); return false;
    }
    m_invalid.remove(name);
    if (QStringList{QStringLiteral("hue"), QStringLiteral("brightness"), QStringLiteral("contrast"), QStringLiteral("saturation"), QStringLiteral("gamma")}.contains(name))
        stage(QStringLiteral("filter:video-filter:adjust"), true);

    if (normalized == read(name.toUtf8())) m_edits.remove(name);
    else m_edits.insert(name, normalized);
    if (m_invalid.isEmpty())
        m_error.clear();
    ++m_revision;
    emit changed();
    return true;
}

void RedesignPreferences::reset(const QString& name)
{
    const auto data = describe(name);
    if (!data.isEmpty()) stage(name, data.value(QStringLiteral("defaultValue")));
}

void RedesignPreferences::discard()
{
    m_edits.clear(); m_invalid.clear(); m_error.clear(); ++m_revision; emit changed();
}

bool RedesignPreferences::save()
{
    if (!m_ctx || !m_invalid.isEmpty()) return false;
    QVariantMap previous;
    for (auto it = m_edits.cbegin(); it != m_edits.cend(); ++it) {
        previous.insert(it.key(), read(it.key().toUtf8()));
        write(it.key().toUtf8(), it.value());
    }
    if (config_SaveConfigFile(m_ctx->getIntf()) != 0) {
        for (auto it = previous.cbegin(); it != previous.cend(); ++it) write(it.key().toUtf8(), it.value());
        m_error = qtr("The preferences file could not be saved. Your edits are still open.");
        ++m_revision; emit changed(); return false;
    }
    m_ctx->reloadPrefs();
    discard();
    return true;
}

QVariantList RedesignPreferences::catalog(const QString& category, const QString& search) const
{
    QVariantList result;
    for (const auto& entry : m_catalog) {
        if (!search.isEmpty()) {
            if (!entry.name.contains(search, Qt::CaseInsensitive) && !entry.title.contains(search, Qt::CaseInsensitive)) continue;
        } else if (entry.category != category) continue;
        result.append(QVariantMap{{QStringLiteral("name"), entry.name}, {QStringLiteral("title"), entry.title}});
    }
    return result;
}

QString RedesignPreferences::choosePath(const QString& name)
{
    const auto* cfg = config_FindConfig(name.toUtf8().constData());
    if (!cfg) return {};
    const QString initial = value(name).toString();
    switch (cfg->i_type) {
    case CONFIG_ITEM_DIRECTORY: return QFileDialog::getExistingDirectory(nullptr, qtr("Select folder"), initial);
    case CONFIG_ITEM_SAVEFILE: return QFileDialog::getSaveFileName(nullptr, qtr("Select file"), initial);
    case CONFIG_ITEM_LOADFILE: return QFileDialog::getOpenFileName(nullptr, qtr("Select file"), initial);
    default: return {};
    }
}

QString RedesignPreferences::chooseColor(const QString& initial)
{
    const QColor color = QColorDialog::getColor(QColor(initial), nullptr, qtr("Choose color"));
    return color.isValid() ? color.name() : QString();
}
