// SPDX-License-Identifier: LGPL-2.1-or-later
#include "../../libvlc/test.h"
#include "../../../lib/libvlc_internal.h"
#include <vlc_filter.h>
#include <vlc_modules.h>

static subpicture_t *new_subpicture(filter_t *filter)
{
    (void)filter;
    return subpicture_New(NULL);
}

int main(void)
{
    test_init();
    const char *args[] = {"--ignore-config", "-Idummy", "--no-media-library"};
    libvlc_instance_t *instance = libvlc_new(ARRAY_SIZE(args), args);
    assert(instance != NULL);
    if (!module_exists("marq")) {
        libvlc_release(instance);
        return 77;
    }
    filter_t *filter = vlc_object_create(instance->p_libvlc_int, sizeof(*filter));
    assert(filter != NULL);
    static const struct filter_subpicture_callbacks callbacks = { .buffer_new = new_subpicture };
    filter->owner.sub = &callbacks;
    assert(vlc_filter_LoadModule(filter, "sub source", "marq", true) != NULL);
    var_SetString(filter, "marq-marquee", "Test overlay");
    const int opacity[] = {255, 128, 0, 64, 255};
    for (size_t i = 0; i < ARRAY_SIZE(opacity); ++i) {
        var_SetInteger(filter, "marq-opacity", opacity[i]);
        subpicture_t *subpic = filter->ops->source_sub(filter, VLC_TICK_FROM_SEC(2 + 2 * i));
        assert(subpic != NULL);
        // Fade the complete text, including its outline, after rendering it.
        assert(subpic->i_alpha == opacity[i]);
        unsigned count = 0;
        subpicture_region_t *region;
        vlc_spu_regions_foreach(region, &subpic->regions) {
            assert(region->p_text != NULL && region->p_text->style != NULL);
            assert(region->p_text->style->i_font_alpha == 255);
            assert(region->i_alpha == 255);
            ++count;
        }
        assert(count == 1);
        subpicture_Delete(subpic);
    }
    vlc_filter_Delete(filter);
    libvlc_release(instance);
    return 0;
}
