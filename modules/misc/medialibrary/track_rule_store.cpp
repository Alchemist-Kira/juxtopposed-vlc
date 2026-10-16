// SPDX-License-Identifier: LGPL-2.1-or-later
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#include "track_rule_store.hpp"
#include "track_rules.hpp"
#include <vlc_common.h>
#include <vlc_fs.h>
#include <vlc_hash.h>
#include <vlc_media_library.h>
#include <vlc_strings.h>
#include <vlc_url.h>
#include <vlc_charset.h>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <memory>
#include <set>
#include <sys/stat.h>
#include <unistd.h>
#ifdef _WIN32
# include <windows.h>
# include <io.h>
#endif

namespace vlc::medialibrary {
namespace {
bool absolute(const std::string& path)
{
    return !path.empty() && (path[0] == '/' || (path.size() > 2
        && ((path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z'))
        && path[1] == ':' && path[2] == '/'));
}

bool readable(const std::string& path)
{
    struct stat st;
    if (vlc_stat(path.c_str(), &st) != 0 || !S_ISREG(st.st_mode)) return false;
    FILE* file = vlc_fopen(path.c_str(), "rb");
    if (!file) return false;
    fclose(file); return true;
}

bool valid(const std::string& definition, std::vector<trackrules::Pair>& pairs)
{
    if (!trackrules::decode(definition, pairs) || pairs.empty()) return false;
    for (const auto& pair : pairs)
        if (!absolute(trackrules::path(pair.track)) || !absolute(trackrules::path(pair.source))) return false;
    return true;
}

std::string find(const std::string& expected)
{
    if (readable(expected)) return expected;
    // Accept one equivalent filename, while leaving ambiguous choices to the user.
    const auto parent = trackrules::parent(expected);
    const auto name = trackrules::compact(trackrules::fileName(expected));
    std::unique_ptr<vlc_DIR, decltype(&vlc_closedir)> directory(vlc_opendir(parent.c_str()), vlc_closedir);
    if (!directory) return {};
    std::string result;
    while (const char* entry = vlc_readdir(directory.get())) {
        if (entry[0] == '.' || trackrules::compact(entry) != name) continue;
        const auto candidate = parent + '/' + entry;
        if (!readable(candidate)) continue;
        if (!result.empty() && result != candidate) return {};
        result = candidate;
    }
    return result;
}

bool replace(const std::string& temporary, const std::string& target)
{
#ifdef _WIN32
    const auto widePath = [](std::string path) {
        std::replace(path.begin(), path.end(), '/', '\\');
        if (path.compare(0, 2, "\\\\") == 0) path = "\\\\?\\UNC\\" + path.substr(2);
        else path = "\\\\?\\" + path;
        return ToWide(path.c_str());
    };
    std::unique_ptr<wchar_t, decltype(&free)> from(widePath(temporary), free), to(widePath(target), free);
    return from && to && MoveFileExW(from.get(), to.get(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
#else
    return vlc_rename(temporary.c_str(), target.c_str()) == 0;
#endif
}
}

std::string TrackRuleStore::scope(const std::string& folderMrl) const
{
    std::unique_ptr<char, decltype(&free)> decoded(vlc_uri2path(folderMrl.c_str()), free);
    if (!decoded) return {};
    auto path = trackrules::path(decoded.get());
    if (!absolute(path)) return {};
    // Remove lexical dot segments without reading the target or a network share.
    const bool unc = path.compare(0, 2, "//") == 0;
    std::vector<std::string> parts;
    size_t at = 0;
    while (at < path.size()) {
        const auto end = path.find('/', at);
        const auto part = path.substr(at, end == std::string::npos ? end : end - at);
        const size_t rootParts = unc ? 2 : path.size() > 2 && path[1] == ':' ? 1 : 0;
        if (part == "..") { if (parts.size() > rootParts) parts.pop_back(); }
        else if (!part.empty() && part != ".") parts.push_back(part);
        if (end == std::string::npos) break;
        at = end + 1;
    }
    std::string normal = path[0] == '/' ? (unc ? "//" : "/") : "";
    for (const auto& part : parts) { if (!normal.empty() && normal.back() != '/') normal += '/'; normal += part; }
#ifdef _WIN32
    std::unique_ptr<wchar_t, decltype(&free)> wide(ToWide(normal.c_str()), free);
    if (!wide) return {};
    const int length = LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_UPPERCASE, wide.get(), -1, nullptr, 0, nullptr, nullptr, 0);
    if (length <= 0) return {};
    std::vector<wchar_t> folded(length);
    if (!LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_UPPERCASE, wide.get(), -1, folded.data(), length, nullptr, nullptr, 0)) return {};
    std::unique_ptr<char, decltype(&free)> utf8(FromWide(folded.data()), free);
    if (!utf8) return {};
    normal = utf8.get();
#endif
    if (normal.size() == 2 && normal[1] == ':') normal += '/';
    return normal;
}

std::string TrackRuleStore::location(const std::string& folderMrl, int type) const
{
    const auto folder = scope(folderMrl);
    if (folder.empty() || !absolute(trackrules::path(m_directory))
        || (type != VLC_ML_FILE_TYPE_SUBTITLE && type != VLC_ML_FILE_TYPE_SOUNDTRACK)) return {};
    vlc_hash_md5_t hash; vlc_hash_md5_Init(&hash);
    vlc_hash_md5_Update(&hash, folder.data(), folder.size());
    char digest[VLC_HASH_MD5_DIGEST_SIZE], key[VLC_HASH_MD5_DIGEST_HEX_SIZE];
    vlc_hash_md5_Finish(&hash, digest, sizeof(digest)); vlc_hex_encode_binary(digest, sizeof(digest), key);
    return m_directory + '/' + key + '.' + std::to_string(type) + ".rules";
}

bool TrackRuleStore::read(const std::string& folderMrl, int type, std::string& definition) const
{
    definition.clear(); const auto fileName = location(folderMrl, type);
    if (fileName.empty()) return false;
    struct stat st;
    if (vlc_stat(fileName.c_str(), &st) != 0) return errno == ENOENT;
    if (!S_ISREG(st.st_mode)) return false;
    FILE* file = vlc_fopen(fileName.c_str(), "rb");
    if (!file) return false;
    std::string bytes(trackrules::MaxBytes + 1, '\0');
    const size_t size = fread(bytes.data(), 1, bytes.size(), file);
    const bool failed = ferror(file); fclose(file);
    if (failed || size > trackrules::MaxBytes) return false;
    bytes.resize(size); const auto split = bytes.find('\n');
    std::unique_ptr<char, decltype(&free)> uri(vlc_path2uri(trackrules::nativePath(scope(folderMrl)).c_str(), nullptr), free);
    if (!uri || split == std::string::npos || bytes.substr(0, split) != uri.get()) return false;
    definition = bytes.substr(split + 1);
    std::vector<trackrules::Pair> pairs;
    if (!valid(definition, pairs)) { definition.clear(); return false; }
    return true;
}

bool TrackRuleStore::write(const std::string& folderMrl, int type, const std::string& definition) const
{
    const auto fileName = location(folderMrl, type);
    if (fileName.empty()) return false;
    if (definition.empty()) return vlc_unlink(fileName.c_str()) == 0 || errno == ENOENT;
    std::vector<trackrules::Pair> pairs;
    if (!valid(definition, pairs)) return false;
    auto nativeDirectory = m_directory;
#ifdef _WIN32
    std::replace(nativeDirectory.begin(), nativeDirectory.end(), '/', '\\');
#endif
    if (vlc_mkdir_parent(nativeDirectory.c_str(), 0700) != 0) return false;
    std::unique_ptr<char, decltype(&free)> uri(vlc_path2uri(trackrules::nativePath(scope(folderMrl)).c_str(), nullptr), free);
    if (!uri) return false;
    const auto data = std::string(uri.get()) + '\n' + definition;
    if (data.size() > trackrules::MaxBytes) return false;
    std::string temporary = fileName + ".XXXXXX";
    const int fd = vlc_mkstemp(temporary.data());
    if (fd < 0) return false;
    FILE* file = fdopen(fd, "wb");
    if (!file) { close(fd); vlc_unlink(temporary.c_str()); return false; }
    bool saved = fwrite(data.data(), 1, data.size(), file) == data.size();
    if (fflush(file) != 0 || ferror(file)) saved = false;
#ifdef _WIN32
    if (saved && _commit(fd) != 0) saved = false;
#else
    if (saved && fdatasync(fd) != 0) saved = false;
#endif
    if (fclose(file) != 0) saved = false;
    if (saved) saved = replace(temporary, fileName);
    if (!saved) vlc_unlink(temporary.c_str());
    return saved;
}

bool TrackRuleStore::resolve(const std::string& definition, const std::string& mediaName,
                             bool& applies, std::vector<std::string>& paths) const
{
    applies = false; paths.clear();
    if (definition.empty()) return true;
    std::vector<trackrules::Pair> pairs;
    if (!valid(definition, pairs)) return false;
    std::set<std::string> seen;
    for (const auto& pair : pairs) {
        const auto expected = trackrules::expected(pair, mediaName);
        if (!expected) continue;
        applies = true; const auto actual = find(*expected);
        if (!actual.empty() && seen.insert(actual).second) paths.push_back(actual);
    }
    return true;
}

}
