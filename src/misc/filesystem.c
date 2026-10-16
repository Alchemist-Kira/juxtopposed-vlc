// SPDX-License-Identifier: LGPL-2.1-or-later
/*****************************************************************************
 * filesystem.c: filesystem helpers
 *****************************************************************************
 * Copyright © 2024 VLC authors, VideoLAN and Videolabs
 *
 * Authors: Gabriel Lafond Thenaille <gabriel@videolabs.io>
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc_common.h>
#include <vlc_fs.h>

/**
 * Create all directories in the given path if missing.
 */
int vlc_mkdir_parent(const char *dirname, mode_t mode)
{
    int ret = vlc_mkdir(dirname, mode);
    if (ret == 0 || errno == EEXIST) {
        return 0;
    } else if (errno != ENOENT) {
        return -1;
    }

    char *path = strdup(dirname);
    if (path == NULL) {
        return -1;
    }

    char *ptr = path + 1;
#ifdef _WIN32
    for (char *p = path; *p; ++p)
        if (*p == '/') *p = '\\';
    if (path[0] == '\\' && path[1] == '\\') {
        /* A server/share root already exists or is unavailable. It is not
         * a sequence of directories that this function can create. */
        ptr = path + 2;
        unsigned components = 2;
        if (!strncmp(ptr, "?\\", 2)) {
            ptr += 2;
            if (!strncasecmp(ptr, "UNC\\", 4))
                ptr += 4;
            else
                components = 1; /* extended drive or volume root */
        }
        char *end = ptr;
        for (unsigned i = 0; i < components; ++i) {
            end = strchr(ptr, '\\');
            if (end == ptr || *ptr == '\0' || (!end && i + 1 < components)) {
                free(path);
                errno = EINVAL;
                return -1;
            }
            if (!end) end = ptr + strlen(ptr);
            ptr = end + (*end != '\0');
        }
        const char separator = *end;
        char *root_end = end + (separator != '\0');
        const char first_child = *root_end;
        *root_end = '\0';
        struct stat st;
        int status = vlc_stat(path, &st);
        *root_end = first_child;
        if (status != 0 || !S_ISDIR(st.st_mode)) {
            if (status == 0) errno = ENOTDIR;
            free(path);
            return -1;
        }
        if (!separator || !first_child) {
            free(path);
            return 0;
        }
        ptr = end + 1;
    } else if (path[0] && path[1] == ':' && path[2] == '\\')
        ptr = path + 3;
#endif
    while (*ptr) {
        ptr = strchr(ptr, DIR_SEP_CHAR);
        if (ptr == NULL) {
            break;
        }
        *ptr = '\0';
        if (vlc_mkdir(path, mode) != 0) {
            if (errno != EEXIST) {
                free(path);
                return -1;
            }
        }
        *ptr = DIR_SEP_CHAR;
        ptr++;
    }
    ret = vlc_mkdir(path, mode);
    if (errno == EEXIST) {
        ret = 0;
    }
    free(path);
    return ret;
}
