// SPDX-License-Identifier: GPL-2.0-or-later
#include "redesign_preferences.hpp"
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>
#include <vlc_aout.h>
#include <vlc_player.h>
#include "../../../../audio_filter/equalizer_presets.h"
#include <cmath>
#include <algorithm>
#include <QFileDialog>
#include <QColorDialog>
#include <QGuiApplication>
#include <QScreen>
#include <QKeyEvent>
#include <QRegularExpression>
#include <QDir>
#include <QFileInfo>
#include "util/vlchotkeyconverter.hpp"

namespace {
bool supportsWebRemote()
{
    // Lua's HTTP interface is a submodule: its shortcut need not be the
    // primary module name used by module_exists().
    static const bool available = [] {
        module_t** modules = nullptr;
        const ssize_t count = vlc_module_match("interface", "luahttp", true, &modules, nullptr);
        free(modules);
        return count > 0;
    }();
    return available;
}

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
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(300);
    connect(&m_saveTimer, &QTimer::timeout, this, [this]() { if (m_autoSave && dirty()) save(); });
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

void RedesignPreferences::setAutoSave(bool enabled)
{
    if (m_autoSave == enabled) return;
    m_autoSave = enabled;
    if (!enabled) m_saveTimer.stop();
    else if (dirty()) m_saveTimer.start();
    emit autoSaveChanged();
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

QString RedesignPreferences::audioOutputModule() const
{
    if (!m_ctx) return {};
    audio_output_t* output = vlc_player_aout_Hold(m_ctx->getIntf()->p_player);
    if (!output) return {};
    char* name = vlc_object_get_name(VLC_OBJECT(output));
    const QString result = qfu(name ? name : "");
    free(name); aout_Release(output);
    return result;
}

QVariantList RedesignPreferences::audioDeviceChoices() const
{
    QVariantList choices{QVariantMap{{QStringLiteral("label"), qtr("System default")}, {QStringLiteral("value"), QString()}}};
    if (!m_ctx) return choices;
    audio_output_t* output = vlc_player_aout_Hold(m_ctx->getIntf()->p_player);
    if (!output) return choices;
    char **ids = nullptr, **names = nullptr;
    const int count = aout_DevicesList(output, &ids, &names);
    for (int i = 0; i < count; ++i) {
        if (ids[i] && *ids[i]) choices.append(QVariantMap{{QStringLiteral("label"), qfu(names[i])}, {QStringLiteral("value"), qfu(ids[i])}});
        free(ids[i]); free(names[i]);
    }
    free(ids); free(names); aout_Release(output);
    return choices;
}

void RedesignPreferences::refresh()
{
    ++m_revision; emit changed();
}

QVariant RedesignPreferences::value(const QString& name) const
{
    if (name == QLatin1String("redesign-audio-device")) {
        const QString module = audioOutputModule();
        const QString configured = value(QStringLiteral("audio-device-default")).toString();
        const QString driver = value(QStringLiteral("audio-device-default-module")).toString();
        if (!configured.isEmpty() && (driver.isEmpty() || driver == module)) return configured;
        const QString legacyName = module + QStringLiteral("-audio-device");
        const auto* legacy = config_FindConfig(legacyName.toUtf8().constData());
        if (legacy && CONFIG_CLASS(legacy->i_type) == CONFIG_ITEM_STRING) {
            const QString selected = value(legacyName).toString();
            if (selected != qfu(legacy->orig.psz ? legacy->orig.psz : "")) return selected;
        }
        return QString();
    }
    if (name == QLatin1String("redesign-startup-volume")) {
        const int configured = value(QStringLiteral("audio-startup-volume")).toInt();
        if (configured >= 0) return configured;
        const QString module = audioOutputModule();
        const bool gain = module == QLatin1String("alsa") || module == QLatin1String("jack") || module == QLatin1String("kai");
        const QString legacyName = module + (gain ? QStringLiteral("-gain") : QStringLiteral("-volume"));
        if (config_FindConfig(legacyName.toUtf8().constData())) {
            double volume = value(legacyName).toDouble();
            if (gain) volume = std::cbrt(volume);
            if (module == QLatin1String("auhal")) volume /= AOUT_VOLUME_DEFAULT;
            if (std::isfinite(volume)) return std::clamp(int(std::lround(volume * 100)), 0, 300);
        }
        return 100;
    }

    if (name == QLatin1String("redesign-web-remote")) {
        const auto interfaces = value(QStringLiteral("extraintf")).toString().split(QLatin1Char(':'), Qt::SkipEmptyParts);
        return std::any_of(interfaces.cbegin(), interfaces.cend(), [](const auto& entry) {
            const auto module = entry.section(QLatin1Char('{'), 0, 0);
            return module == QLatin1String("http") || module == QLatin1String("luahttp");
        });
    }
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
    if (name == QLatin1String("redesign-config-folder"))
        return {{QStringLiteral("kind"), QStringLiteral("action")}, {QStringLiteral("editor"), QStringLiteral("action")},
            {QStringLiteral("buttonLabel"), qtr("Open")},
            {QStringLiteral("help"), qtr("Open the folder that contains the VLC settings.")}};
    if (name == QLatin1String("redesign-audio-device")) {
        auto choices = audioDeviceChoices();
        const QString configured = value(name).toString();
        if (!configured.isEmpty() && std::none_of(choices.cbegin(), choices.cend(), [&](const auto& choice) {
            return choice.toMap().value(QStringLiteral("value")).toString() == configured;
        })) choices.append(QVariantMap{{QStringLiteral("label"), qtr("Unavailable device (%1)").arg(configured)}, {QStringLiteral("value"), configured}});
        return {{QStringLiteral("kind"), QStringLiteral("string")}, {QStringLiteral("title"), qtr("Output device")},
            {QStringLiteral("choices"), choices}, {QStringLiteral("defaultValue"), QString()}, {QStringLiteral("value"), configured},
            {QStringLiteral("help"), qtr("Choose the device to use for audio. A disconnected device falls back to the audio driver's default.")}};
    }
    if (name == QLatin1String("redesign-startup-volume"))
        return {{QStringLiteral("kind"), QStringLiteral("integer")}, {QStringLiteral("title"), qtr("Startup volume")},
            {QStringLiteral("minimum"), 0}, {QStringLiteral("maximum"), 300}, {QStringLiteral("defaultValue"), 100},
            {QStringLiteral("value"), value(name)}};

    if (name == QLatin1String("redesign-web-remote"))
        return {{QStringLiteral("kind"), QStringLiteral("bool")}, {QStringLiteral("title"), qtr("Web remote control")},
            {QStringLiteral("defaultValue"), false}, {QStringLiteral("value"), value(name)},
            {QStringLiteral("supported"), supportsWebRemote()},
            {QStringLiteral("help"), supportsWebRemote() ? qtr("Control VLC from a web browser. Restart VLC after changing the web remote, port or password.")
                : qtr("Web remote control is unavailable in this VLC build.")}};

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
    if (name == QLatin1String("audio-spatial") || name == QLatin1String("audio-spatial-mode")) {
        const bool supported = module_exists("spatialaudio");
        result.insert(QStringLiteral("supported"), supported);
        if (!supported) result.insert(QStringLiteral("help"), qtr("VLC cannot use spatial audio in this version."));
    }
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
    if (name == QLatin1String("equalizer-preset")) {
        choices.clear();
        choices.append(QVariantMap{{QStringLiteral("label"), qtr("None")}, {QStringLiteral("value"), QString()}});
        for (int i = 0; i < NB_PRESETS; ++i) {
            QVariantList curve;
            for (int band = 0; band < eqz_preset_10b[i].i_band; ++band)
                curve.append(eqz_preset_10b[i].f_amp[band]);
            choices.append(QVariantMap{{QStringLiteral("label"), qtr(preset_list_text[i])},
                {QStringLiteral("value"), qfu(preset_list[i])}, {QStringLiteral("curve"), curve}});
        }
    }
    result.insert(QStringLiteral("editor"), editor);
    result.insert(QStringLiteral("kind"), kind);
    result.insert(QStringLiteral("choices"), choices);
    return result;
}

bool RedesignPreferences::stage(const QString& name, const QVariant& proposed)
{
    if (name == QLatin1String("audio-spatial") || name == QLatin1String("audio-spatial-mode")) {
        if (!module_exists("spatialaudio")) return false;
        if (name == QLatin1String("audio-spatial-mode") && proposed.toInt() != AOUT_MIX_MODE_BINAURAL
            && proposed.toInt() != AOUT_MIX_MODE_UNSET) return false;
    }
    if (name == QLatin1String("redesign-startup-volume")) {
        bool valid = false;
        const auto volume = proposed.toLongLong(&valid);
        return stage(QStringLiteral("audio-startup-volume"), valid && volume >= 0 && volume <= 300 ? QVariant(volume) : QVariant(QStringLiteral("invalid")));
    }
    if (name == QLatin1String("redesign-audio-device")) {
        const QString id = proposed.toString();
        const auto choices = audioDeviceChoices();
        if (std::none_of(choices.cbegin(), choices.cend(), [&](const auto& choice) { return choice.toMap().value(QStringLiteral("value")).toString() == id; })) return false;
        const QString module = audioOutputModule();
        stage(QStringLiteral("audio-device-default-module"), id.isEmpty() ? QString() : module);
        const QString legacyName = module + QStringLiteral("-audio-device");
        const auto* legacy = config_FindConfig(legacyName.toUtf8().constData());
        if (legacy && CONFIG_CLASS(legacy->i_type) == CONFIG_ITEM_STRING)
            stage(legacyName, id.isEmpty() ? qfu(legacy->orig.psz ? legacy->orig.psz : "") : id);
        return stage(QStringLiteral("audio-device-default"), id);
    }
    if (name == QLatin1String("volume-save")) {
        if (proposed.toBool() && m_invalid.contains(QStringLiteral("audio-startup-volume")))
            stage(QStringLiteral("audio-startup-volume"), value(QStringLiteral("audio-startup-volume")));
        if (!proposed.toBool() && value(QStringLiteral("audio-startup-volume")).toInt() < 0)
            stage(QStringLiteral("audio-startup-volume"), value(QStringLiteral("redesign-startup-volume")));
        if (proposed.toBool() && m_ctx) {
            const float current = vlc_player_aout_GetVolume(m_ctx->getIntf()->p_player);
            if (std::isfinite(current) && current >= 0) stage(QStringLiteral("audio-last-volume"), std::min(current, 3.f));
        }
    }

    if (name == QLatin1String("redesign-web-remote")) {
        if (proposed.toBool() && !supportsWebRemote()) return false;
        auto interfaces = value(QStringLiteral("extraintf")).toString().split(QLatin1Char(':'), Qt::SkipEmptyParts);
        interfaces.erase(std::remove_if(interfaces.begin(), interfaces.end(), [](const auto& entry) {
            const auto module = entry.section(QLatin1Char('{'), 0, 0);
            return module == QLatin1String("http") || module == QLatin1String("luahttp");
        }), interfaces.end());
        if (proposed.toBool()) interfaces.append(QStringLiteral("http"));
        return stage(QStringLiteral("extraintf"), interfaces.join(QLatin1Char(':')));
    }

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

    if (name == QLatin1String("equalizer-preset") && !proposed.toString().isEmpty()) {
        const QByteArray preset = proposed.toString().toUtf8();
        const auto it = std::find_if(std::begin(eqz_preset_10b), std::end(eqz_preset_10b), [&](const auto& row) { return preset == row.psz_name; });
        if (it == std::end(eqz_preset_10b)) return false;
        QStringList bands;
        for (int i = 0; i < it->i_band; ++i) bands.append(QString::number(std::abs(it->f_amp[i]) < 0.05f ? 0.f : it->f_amp[i], 'f', 1));
        stage(QStringLiteral("equalizer-bands"), bands.join(QLatin1Char(' ')));
        stage(QStringLiteral("equalizer-preamp"), it->f_preamp);
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
        if (name == QLatin1String("equalizer-preamp")) valid = valid && v >= -20 && v <= 20;
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
    if (m_autoSave) m_saveTimer.start();
    return true;
}

void RedesignPreferences::reset(const QString& name)
{
    const auto data = describe(name);
    if (!data.isEmpty()) stage(name, data.value(QStringLiteral("defaultValue")));
}

void RedesignPreferences::discard()
{
    m_saveTimer.stop();
    m_edits.clear(); m_invalid.clear(); m_error.clear(); ++m_revision; emit changed();
}

bool RedesignPreferences::save()
{
    m_saveTimer.stop();
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
    // These controls are inherited by the current input and action dispatcher.
    auto* instance = vlc_object_instance(m_ctx->getIntf());
    for (const auto& name : {QStringLiteral("mouse-pause-policy"), QStringLiteral("hotkeys-x-wheel-mode"),
                            QStringLiteral("hotkeys-y-wheel-mode"), QStringLiteral("hotkeys-wheel-direction")}) {
        if (!previous.contains(name)) continue;
        const QByteArray bytes = name.toUtf8();
        const int type = name == QLatin1String("mouse-pause-policy") ? VLC_VAR_STRING
            : name == QLatin1String("hotkeys-wheel-direction") ? VLC_VAR_BOOL : VLC_VAR_INTEGER;
        if (var_Type(instance, bytes.constData()) == 0) var_Create(instance, bytes.constData(), type);
        if (type == VLC_VAR_STRING) var_SetString(instance, bytes.constData(), value(name).toString().toUtf8().constData());
        else if (type == VLC_VAR_BOOL) var_SetBool(instance, bytes.constData(), value(name).toBool());
        else var_SetInteger(instance, bytes.constData(), value(name).toLongLong());
    }

    // Apply audio effects to the current output after persistence succeeds.
    // Defaults remain available for the next output if nothing is playing.
    auto* player = m_ctx->getIntf()->p_player;
    const bool deviceChanged = previous.contains(QStringLiteral("audio-device-default"))
        || previous.contains(QStringLiteral("audio-device-default-module"))
        || previous.contains(audioOutputModule() + QStringLiteral("-audio-device"));
    if (previous.contains(QStringLiteral("volume-save")) || deviceChanged || previous.contains(QStringLiteral("mix-mode"))
        || previous.contains(QStringLiteral("stereo-mode")) || previous.contains(QStringLiteral("audio-spatial"))
        || previous.contains(QStringLiteral("audio-spatial-mode"))) {
        audio_output_t* output = vlc_player_aout_Hold(player);
        if (output) {
            for (const auto& option : {QStringLiteral("mix-mode"), QStringLiteral("stereo-mode"), QStringLiteral("audio-spatial-mode")})
                if (previous.contains(option)) var_SetInteger(output, option.toUtf8().constData(), value(option).toLongLong());
            if (previous.contains(QStringLiteral("audio-spatial")))
                var_SetBool(output, "audio-spatial", value(QStringLiteral("audio-spatial")).toBool());
            if (previous.contains(QStringLiteral("volume-save"))) {
                if (var_Type(output, "volume-save") == 0) var_Create(output, "volume-save", VLC_VAR_BOOL);
                var_SetBool(output, "volume-save", value(QStringLiteral("volume-save")).toBool());
            }
            if (deviceChanged) {
                const QByteArray id = value(QStringLiteral("redesign-audio-device")).toString().toUtf8();
                aout_DeviceSet(output, id.isEmpty() ? nullptr : id.constData());
            }
            aout_Release(output);
        }
    }
    if (previous.contains(QStringLiteral("audio-filter"))) {
        const auto before = previous.value(QStringLiteral("audio-filter")).toString().split(QLatin1Char(':'), Qt::SkipEmptyParts);
        const auto after = value(QStringLiteral("audio-filter")).toString().split(QLatin1Char(':'), Qt::SkipEmptyParts);
        for (const auto& filter : before)
            if (!after.contains(filter)) vlc_player_aout_EnableFilter(player, filter.toUtf8().constData(), false);
        for (const auto& filter : after)
            if (!before.contains(filter)) vlc_player_aout_EnableFilter(player, filter.toUtf8().constData(), true);
    }
    const QStringList equalizerOptions{QStringLiteral("equalizer-preset"), QStringLiteral("equalizer-bands"), QStringLiteral("equalizer-preamp"), QStringLiteral("equalizer-2pass")};
    if (std::any_of(equalizerOptions.cbegin(), equalizerOptions.cend(), [&](const auto& name) { return previous.contains(name); })) {
        audio_output_t* output = vlc_player_aout_Hold(player);
        if (output) {
            for (const auto& name : equalizerOptions) {
                const auto current = value(name);
                const QByteArray bytes = name.toUtf8();
                if (name == QLatin1String("equalizer-preamp")) var_SetFloat(output, bytes.constData(), current.toFloat());
                else if (name == QLatin1String("equalizer-2pass")) var_SetBool(output, bytes.constData(), current.toBool());
                else if (name != QLatin1String("equalizer-preset") || !current.toString().isEmpty()) var_SetString(output, bytes.constData(), current.toString().toUtf8().constData());
            }
            aout_Release(output);
        }
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

QUrl RedesignPreferences::configurationFolder() const
{
    if (!m_ctx) return {};
    char* custom = var_InheritString(m_ctx->getIntf(), "config");
    QString folder;
    if (custom && *custom) folder = QFileInfo(qfu(custom)).absolutePath();
    free(custom);
    if (folder.isEmpty()) {
        char* path = config_GetUserDir(VLC_CONFIG_DIR);
        folder = qfu(path ? path : "");
        free(path);
    }
    if (folder.isEmpty() || !QDir().mkpath(folder)) return {};
    return QUrl::fromLocalFile(folder);
}

QString RedesignPreferences::chooseColor(const QString& initial)
{
    const QColor color = QColorDialog::getColor(QColor(initial), nullptr, qtr("Choose color"));
    return color.isValid() ? color.name() : QString();
}

QVariantList RedesignPreferences::equalizerBands() const
{
    const auto custom = value(QStringLiteral("equalizer-bands")).toString().split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
    const QByteArray name = value(QStringLiteral("equalizer-preset")).toString().toUtf8();
    const auto preset = std::find_if(std::begin(eqz_preset_10b), std::end(eqz_preset_10b), [&](const auto& row) { return name == row.psz_name; });
    QVariantList result;
    for (int i = 0; i < 10; ++i) {
        bool valid = false;
        double gain = i < custom.size() ? custom[i].toDouble(&valid) : 0;
        if (!valid || !std::isfinite(gain)) gain = preset != std::end(eqz_preset_10b) ? preset->f_amp[i] : 0;
        result.append(std::abs(gain) < 0.05 ? 0.0 : std::clamp(gain, -20.0, 20.0));
    }
    return result;
}

bool RedesignPreferences::setEqualizerBand(int index, double gain)
{
    if (index < 0 || index >= 10 || !std::isfinite(gain) || gain < -20 || gain > 20) return false;
    const auto values = equalizerBands();
    QStringList bands;
    for (int i = 0; i < values.size(); ++i) bands.append(QString::number(i == index ? gain : values[i].toDouble(), 'f', 1));
    if (!stage(QStringLiteral("equalizer-bands"), bands.join(QLatin1Char(' ')))) return false;
    return stage(QStringLiteral("equalizer-preset"), QString());
}

QVariantList RedesignPreferences::shortcutCatalog() const
{
    struct Shortcut { QString name, title, group; int groupOrder, order; };
    QList<Shortcut> shortcuts;
    const QStringList basic{QStringLiteral("key-toggle-fullscreen"), QStringLiteral("key-leave-fullscreen"), QStringLiteral("key-position"), QStringLiteral("key-intf-show")};
    const QStringList playback{QStringLiteral("key-play-pause"), QStringLiteral("key-stop"), QStringLiteral("key-next"), QStringLiteral("key-prev"), QStringLiteral("key-program-sid-next"), QStringLiteral("key-program-sid-prev")};
    for (const auto& entry : m_catalog) {
        if (!entry.name.startsWith(QLatin1String("key-"))) continue;
        Shortcut row{entry.name, entry.title, qtr("Other"), 5, 1000};
        if (basic.contains(entry.name)) { row.group = qtr("Basic"); row.groupOrder = 0; row.order = basic.indexOf(entry.name); }
        else if (playback.contains(entry.name)) { row.group = qtr("Playback"); row.groupOrder = 1; row.order = playback.indexOf(entry.name); }
        else if (entry.name.contains(QLatin1String("sub"))) { row.group = qtr("Subtitles"); row.groupOrder = 4; }
        else if (entry.name.contains(QLatin1String("audio")) || entry.name.contains(QLatin1String("vol-"))) { row.group = qtr("Audio"); row.groupOrder = 2; }
        else if (entry.name.contains(QLatin1String("aspect")) || entry.name.contains(QLatin1String("crop")) || entry.name.contains(QLatin1String("zoom")) || entry.name.contains(QLatin1String("snapshot")) || entry.name.contains(QLatin1String("deinterlace"))) { row.group = qtr("Video"); row.groupOrder = 3; }
        else if (entry.name.contains(QLatin1String("jump")) || entry.name.contains(QLatin1String("rate")) || entry.name.contains(QLatin1String("frame"))) { row.group = qtr("Playback"); row.groupOrder = 1; }
        if (entry.name == QLatin1String("key-toggle-fullscreen")) row.title = qtr("Toggle fullscreen");
        else if (entry.name == QLatin1String("key-leave-fullscreen")) row.title = qtr("Exit fullscreen / close dialog");
        else if (entry.name == QLatin1String("key-position")) row.title = qtr("Show playback position and time");
        else if (entry.name == QLatin1String("key-intf-show")) row.title = qtr("Show interface controls in fullscreen");
        else if (entry.name == QLatin1String("key-play-pause")) row.title = qtr("Play / pause");
        else if (entry.name == QLatin1String("key-stop")) row.title = qtr("Stop playback");
        else if (entry.name == QLatin1String("key-next")) row.title = qtr("Next track");
        else if (entry.name == QLatin1String("key-prev")) row.title = qtr("Previous track");
        shortcuts.append(row);
    }
    std::sort(shortcuts.begin(), shortcuts.end(), [](const Shortcut& a, const Shortcut& b) {
        if (a.groupOrder != b.groupOrder) return a.groupOrder < b.groupOrder;
        if (a.order != b.order) return a.order < b.order;
        return QString::localeAwareCompare(a.title, b.title) < 0;
    });
    QVariantList result;
    for (const auto& row : shortcuts) {
        const QString global = QStringLiteral("global-") + row.name;
        result.append(QVariantMap{{QStringLiteral("name"), row.name}, {QStringLiteral("title"), row.title},
            {QStringLiteral("group"), row.group}, {QStringLiteral("globalName"), config_FindConfig(global.toUtf8().constData()) ? global : QString()}});
    }
    return result;
}

QString RedesignPreferences::shortcutForKey(int key, int modifiers) const
{
    QKeyEvent event(QEvent::KeyPress, key, Qt::KeyboardModifiers::fromInt(modifiers));
    return VLCKeyToString(qtEventToVLCKey(&event), false);
}

QVariantList RedesignPreferences::shortcutConflicts(const QString& name, const QString& shortcut) const
{
    QVariantList conflicts;
    if (shortcut.isEmpty()) return conflicts;
    const bool global = name.startsWith(QLatin1String("global-key-"));
    for (const auto& entry : m_catalog) {
        if (entry.name == name || entry.name.startsWith(QLatin1String("global-key-")) != global) continue;
        if (!entry.name.startsWith(global ? QLatin1String("global-key-") : QLatin1String("key-"))) continue;
        if (value(entry.name).toString().split(QLatin1Char('\t')).contains(shortcut, Qt::CaseInsensitive))
            conflicts.append(QVariantMap{{QStringLiteral("name"), entry.name}, {QStringLiteral("title"), entry.title}});
    }
    return conflicts;
}

bool RedesignPreferences::assignShortcut(const QString& name, const QString& shortcut, bool replaceConflicts)
{
    const auto* cfg = config_FindConfig(name.toUtf8().constData());
    if (!cfg || cfg->i_type != CONFIG_ITEM_KEY) return false;
    const auto conflicts = shortcutConflicts(name, shortcut);
    if (!conflicts.isEmpty() && !replaceConflicts) return false;
    for (const auto& conflict : conflicts) {
        const QString other = conflict.toMap().value(QStringLiteral("name")).toString();
        QStringList bindings = value(other).toString().split(QLatin1Char('\t'), Qt::SkipEmptyParts);
        bindings.erase(std::remove_if(bindings.begin(), bindings.end(), [&shortcut](const QString& binding) {
            return binding.compare(shortcut, Qt::CaseInsensitive) == 0;
        }), bindings.end());
        stage(other, bindings.join(QLatin1Char('\t')));
    }
    if (shortcut.isEmpty()) return stage(name, QString());
    QStringList bindings = value(name).toString().split(QLatin1Char('\t'), Qt::SkipEmptyParts);
    // Replace the displayed binding while retaining alternate and media keys.
    if (!bindings.isEmpty() && !bindings.first().startsWith(QLatin1String("Media ")))
        bindings.removeFirst();
    bindings.removeAll(shortcut);
    bindings.prepend(shortcut);
    return stage(name, bindings.join(QLatin1Char('\t')));
}
