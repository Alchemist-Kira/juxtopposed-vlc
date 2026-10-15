/* SPDX-License-Identifier: LGPL-2.1-or-later */
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#undef NDEBUG
#include <assert.h>
#include <vlc/vlc.h>
#include "../lib/libvlc_internal.h"
#include <vlc_common.h>
#include <vlc_fs.h>
#include <vlc_playlist.h>
#ifdef __linux__
# include <dirent.h>
static unsigned descriptors(void)
{
    DIR *directory = opendir("/proc/self/fd");
    assert(directory);
    unsigned count = 0;
    while (readdir(directory)) ++count;
    closedir(directory);
    return count;
}
#endif

int main(void)
{
#ifndef _WIN32
    setenv("VLC_PLUGIN_PATH", TOP_BUILDDIR "/modules", 1);
    setenv("VLC_LIB_PATH", TOP_BUILDDIR "/modules", 1);
#endif
    const char *options[] = { "--ignore-config", "--no-plugins-cache", "--no-media-library" };
    libvlc_instance_t *instance = libvlc_new(ARRAY_SIZE(options), options);
    assert(instance);
    vlc_playlist_t *playlist = vlc_playlist_New(VLC_OBJECT(instance->p_libvlc_int),
                                               VLC_PLAYLIST_PREPARSING_DISABLED, 1, 0);
    assert(playlist);
    char filename[] = "playlist-export-XXXXXX";
    int fd = vlc_mkstemp(filename);
    assert(fd >= 0);
    vlc_close(fd);
    char invalid[sizeof(filename) + sizeof("/missing.m3u8")];
    snprintf(invalid, sizeof(invalid), "%s/missing.m3u8", filename);
    vlc_playlist_Lock(playlist);
    /* The parent is a file: opening this path must fail without closing NULL. */
    assert(vlc_playlist_Export(playlist, invalid, "export-m3u8") != VLC_SUCCESS);
    assert(vlc_playlist_Export(playlist, filename, "export-m3u8") == VLC_SUCCESS);
    FILE *file = vlc_fopen(filename, "rt");
    assert(file);
    char text[32];
    assert(fgets(text, sizeof(text), file) && !strcmp(text, "#EXTM3U\n"));
    fclose(file);
#ifdef __linux__
    /* Small exports fail at the buffered close, after ferror() still succeeds. */
    assert(vlc_playlist_Export(playlist, "/dev/full", "export-m3u8") != VLC_SUCCESS);
    const unsigned before = descriptors();
#endif
    for (unsigned i = 0; i < 3; ++i)
        assert(vlc_playlist_Export(playlist, filename, "export-nonexistent") != VLC_SUCCESS);
#ifdef __linux__
    assert(descriptors() == before);
#endif
    vlc_playlist_Unlock(playlist);
    vlc_playlist_Delete(playlist);
    libvlc_release(instance);
    vlc_unlink(filename);
    return 0;
}
