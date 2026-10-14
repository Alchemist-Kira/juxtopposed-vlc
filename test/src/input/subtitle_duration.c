// SPDX-License-Identifier: LGPL-2.1-or-later
#include "../../libvlc/test.h"
#include "../../../lib/libvlc_internal.h"
#include <vlc_filter.h>
#include <vlc_modules.h>
#include "../../../modules/codec/substext.h"

static subpicture_t *subtitle(bool dynamic)
{
    subpicture_t *subpic;
    if (dynamic) {
        subtext_updater_sys_t *sys = calloc(1, sizeof(*sys));
        assert(sys != NULL);
        SubpictureUpdaterSysRegionInit(&sys->region);
        sys->region.p_segments = text_segment_New("A subtitle");
        sys->p_default_style = text_style_Create(STYLE_NO_DEFAULTS);
        assert(sys->region.p_segments && sys->p_default_style);
        static const struct vlc_spu_updater_ops ops = {
            .update = SubpictureTextUpdate, .destroy = SubpictureTextDestroy,
        };
        const subpicture_updater_t updater = {.ops = &ops, .sys = sys};
        subpic = subpicture_New(&updater);
    } else {
        subpic = subpicture_New(NULL);
        assert(subpic != NULL);
        for (unsigned i = 0; i < 2; ++i) {
            subpicture_region_t *region = subpicture_region_NewText();
            assert(region != NULL);
            region->p_text = text_segment_New("A static subtitle");
            assert(region->p_text != NULL);
            vlc_spu_regions_push(&subpic->regions, region);
        }
    }
    assert(subpic != NULL);
    subpic->b_subtitle = true;
    subpic->i_start = VLC_TICK_FROM_SEC(1);
    subpic->i_stop = VLC_TICK_FROM_SEC(3);
    return subpic;
}

int main(void)
{
    test_init();
    const char *args[] = {"--ignore-config", "-Idummy", "--no-media-library"};
    libvlc_instance_t *instance = libvlc_new(ARRAY_SIZE(args), args);
    assert(instance != NULL);
    if (!module_exists("subsdelay")) {
        libvlc_release(instance);
        return 77;
    }
    video_format_t fmt;
    video_format_Init(&fmt, VLC_CODEC_RGBA);
    fmt.i_width = fmt.i_visible_width = 1280;
    fmt.i_height = fmt.i_visible_height = 720;
    fmt.i_sar_num = fmt.i_sar_den = 1;
    for (unsigned dynamic = 0; dynamic < 2; ++dynamic) {
        filter_t *filter = vlc_object_create(instance->p_libvlc_int, sizeof(*filter));
        assert(filter != NULL);
        assert(vlc_filter_LoadModule(filter, "sub filter", "subsdelay", true) != NULL);
        var_SetFloat(filter, "subsdelay-factor", 2.0);
        subpicture_t *subpic = filter->ops->filter_sub(filter, subtitle(dynamic));
        assert(subpic != NULL);
        for (unsigned frame = 0; frame < 3; ++frame) {
            subpicture_Update(subpic, &fmt, &fmt, 1280, 720, VLC_TICK_FROM_MS(1100 + 100 * frame));
            unsigned count = 0;
            subpicture_region_t *region;
            vlc_spu_regions_foreach(region, &subpic->regions) {
                assert(region->p_text != NULL && region->p_text->psz_text != NULL);
                ++count;
            }
            assert(count == (dynamic ? 1 : 2));
            assert(subpic->i_stop == VLC_TICK_FROM_MS(4900));
        }
        // Closing a filter must leave already queued subtitles valid.
        vlc_filter_Delete(filter);
        subpicture_Update(subpic, &fmt, &fmt, 1280, 720, VLC_TICK_FROM_MS(1500));
        assert(!vlc_spu_regions_is_empty(&subpic->regions));
        subpicture_Delete(subpic);
    }
    libvlc_release(instance);
    return 0;
}
