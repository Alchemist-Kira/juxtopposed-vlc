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
#ifdef _WIN32
# include <windows.h>
# include <vlc_charset.h>
#endif

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
        /* The CRT stat function rejects some extended UNC share roots. */
        wchar_t *root = ToWide(path);
        DWORD attributes = root ? GetFileAttributesW(root) : INVALID_FILE_ATTRIBUTES;
        DWORD error = root ? GetLastError() : ERROR_INVALID_NAME;
        free(root);
        *root_end = first_child;
        if (attributes == INVALID_FILE_ATTRIBUTES ||
            !(attributes & FILE_ATTRIBUTE_DIRECTORY)) {
            errno = attributes != INVALID_FILE_ATTRIBUTES ? ENOTDIR :
                error == ERROR_ACCESS_DENIED || error == ERROR_SHARING_VIOLATION ? EACCES :
                error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND ||
                error == ERROR_BAD_NETPATH || error == ERROR_BAD_NET_NAME ||
                error == ERROR_INVALID_NAME ? ENOENT : EIO;
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
