// SPDX-License-Identifier: LGPL-2.1-or-later
#pragma once

#include <vlc_strings.h>
#include <vlc_hash.h>
#include <algorithm>
#include <string>

namespace vlc::medialibrary {

inline std::string storagePath(std::string path)
{
    std::replace(path.begin(), path.end(), '\\', '/');
    if (path.compare(0, 4, "//?/") == 0 && path.size() > 8 &&
        (path[4] == 'U' || path[4] == 'u') && (path[5] == 'N' || path[5] == 'n') &&
        (path[6] == 'C' || path[6] == 'c') && path[7] == '/') path = "//" + path.substr(8);
    while (path.size() > 2 && path.back() == '/') path.pop_back();
    return path;
}

inline bool isWslStorage(const std::string& path)
{
    const auto normalized = storagePath(path);
    if (normalized.compare(0, 2, "//") != 0) return false;
    const auto end = normalized.find('/', 2);
    if (end == std::string::npos || end + 1 == normalized.size()) return false;
    auto host = normalized.substr(2, end - 2);
    std::transform(host.begin(), host.end(), host.begin(), [](unsigned char c) {
        return c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
    });
    return host == "wsl.localhost" || host == "wsl$";
}

inline std::string localLibraryStorage(const std::string& userDirectory,
                                       const std::string& localDirectory)
{
    const auto local = storagePath(localDirectory);
    if (local.size() < 3 || !((local[0] >= 'A' && local[0] <= 'Z') || (local[0] >= 'a' && local[0] <= 'z')) ||
        local[1] != ':' || local[2] != '/') return {};
    auto source = storagePath(userDirectory);
    if (isWslStorage(source))
    {
        const auto end = source.find('/', 2);
        source.replace(2, end - 2, "wsl.localhost");
        const auto share = source.find('/', 2) + 1;
        const auto shareEnd = source.find('/', share);
        for (size_t i = share; i < (shareEnd == std::string::npos ? source.size() : shareEnd); ++i)
            if (source[i] >= 'A' && source[i] <= 'Z') source[i] += 'a' - 'A';
    }
    vlc_hash_md5_t hash;
    vlc_hash_md5_Init(&hash);
    vlc_hash_md5_Update(&hash, source.data(), source.size());
    char digest[VLC_HASH_MD5_DIGEST_SIZE], key[VLC_HASH_MD5_DIGEST_HEX_SIZE];
    vlc_hash_md5_Finish(&hash, digest, sizeof(digest));
    vlc_hex_encode_binary(digest, sizeof(digest), key);
    return local + "/vlc/wsl-libraries/" + key + "/ml/";
}

}
