// SPDX-License-Identifier: LGPL-2.1-or-later
#ifndef VLC_VISUALIZATION_SIZE_H
#define VLC_VISUALIZATION_SIZE_H

#include <limits.h>
#include <vlc_variables.h>

/* Return false to keep the visualizer's own width and height. The window
 * dimensions use one variable so a render thread cannot read half a resize. */
static inline bool visualization_GetSize(vlc_object_t *obj, unsigned *width,
                                         unsigned *height)
{
    switch (var_InheritInteger(obj, "visualization-size"))
    {
        case 0:
        {
            const uint64_t packed = var_InheritInteger(obj, "visualization-window-size");
            const unsigned w = packed >> 32, h = packed & UINT32_MAX;
            if (w == 0 || h == 0 || w > INT_MAX || h > INT_MAX)
                return false;
            *width = w;
            *height = h;
            return true;
        }
        case 1: *width = 800; *height = 500; return true;
        case 2: *width = 1280; *height = 720; return true;
        case 3: *width = 1920; *height = 1080; return true;
        default: return false;
    }
}

#endif
