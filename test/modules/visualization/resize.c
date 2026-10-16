// SPDX-License-Identifier: LGPL-2.1-or-later
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#define MODULE_NAME test_visual_resize
#ifndef VISUAL_RESIZE_TEST_PLUGIN
#undef VLC_DYNAMIC_PLUGIN
#endif
#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_player.h>
#include <vlc_window.h>
#include <vlc_vout_display.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#undef NDEBUG
#include <assert.h>
#include "../../../lib/libvlc_internal.h"

static atomic_uint_fast64_t picture_size;
static atomic_uint picture_count, window_opens, window_closes, failed_formats;
static atomic_bool fail_format;
static vlc_sem_t frame_event;

static uint64_t size_key(unsigned width, unsigned height)
{
    return ((uint64_t)width << 32) | height;
}

static int EnableWindow(vlc_window_t *wnd, const vlc_window_cfg_t *cfg)
{
    (void) wnd; (void) cfg;
    return VLC_SUCCESS;
}

static void DisableWindow(vlc_window_t *wnd)
{
    (void) wnd;
}

static void DestroyWindow(vlc_window_t *wnd)
{
    (void) wnd;
    atomic_fetch_add(&window_closes, 1);
}

static int OpenWindow(vlc_window_t *wnd)
{
    static const struct vlc_window_operations ops = {
        .enable = EnableWindow, .disable = DisableWindow, .destroy = DestroyWindow,
    };
    wnd->ops = &ops;
    atomic_fetch_add(&window_opens, 1);
    return VLC_SUCCESS;
}

static void Display(vout_display_t *vd, picture_t *picture)
{
    (void) vd;
    atomic_store(&picture_size, size_key(picture->format.i_visible_width,
                                       picture->format.i_visible_height));
    atomic_fetch_add(&picture_count, 1);
    vlc_sem_post(&frame_event);
}

static int OpenDisplay(vout_display_t *vd, video_format_t *fmt,
                       vlc_video_context *vctx)
{
    (void) vctx;
    if (fmt->i_visible_width == 1200 && atomic_load(&fail_format))
    {
        atomic_fetch_add(&failed_formats, 1);
        vlc_sem_post(&frame_event);
        return VLC_EGENERIC;
    }
    static const struct vlc_display_operations ops = { .display = Display };
    vd->ops = &ops;
    return VLC_SUCCESS;
}

vlc_module_begin()
    set_capability("vout window", 9999)
    set_callback(OpenWindow)
    add_shortcut("resize-test")
    add_submodule()
        set_callback_display(OpenDisplay, 9999)
        add_shortcut("resize-test")
vlc_module_end()

#ifndef VISUAL_RESIZE_TEST_PLUGIN
VLC_EXPORT const vlc_plugin_cb vlc_static_modules[] = {
    VLC_SYMBOL(vlc_entry), NULL
};
#endif

static void wait_picture(unsigned width, unsigned height, unsigned previous)
{
    const vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(5);
    while (atomic_load(&picture_size) != size_key(width, height)
           || atomic_load(&picture_count) <= previous)
    {
        assert(vlc_sem_timedwait(&frame_event, deadline) == 0);
    }
}

static void resize(libvlc_int_t *root, int64_t width, int64_t height,
                   unsigned expected_width, unsigned expected_height)
{
    const unsigned previous = atomic_load(&picture_count);
    fprintf(stderr, "request canvas %" PRId64 "x%" PRId64 "\n", width, height);
    assert(var_SetInteger(root, "effect-width", width) == VLC_SUCCESS);
    assert(var_SetInteger(root, "effect-height", height) == VLC_SUCCESS);
    assert(var_SetInteger(root, "goom-width", width) == VLC_SUCCESS);
    assert(var_SetInteger(root, "goom-height", height) == VLC_SUCCESS);
    wait_picture(expected_width, expected_height, previous);
    assert(atomic_load(&window_opens) == 1);
    assert(atomic_load(&window_closes) == 0);
}

static void test_resize(const char *effect)
{
    const bool goom = !strcmp(effect, "goom");
    atomic_store(&picture_size, 0);
    atomic_store(&picture_count, 0);
    atomic_store(&window_opens, 0);
    atomic_store(&window_closes, 0);
    atomic_store(&failed_formats, 0);
    atomic_store(&fail_format, false);
    vlc_sem_init(&frame_event, 0);
    const char *args[] = {
        "--ignore-config", "--no-plugins-cache", "--no-media-library", "--no-auto-preparse",
        "--no-spu", "--no-osd", "--aout=dummy", "--clock-master=monotonic",
        goom ? "--audio-visual=goom" : "--audio-visual=visual", "--vout=resize-test,none",
    };
    libvlc_instance_t *instance = libvlc_new(ARRAY_SIZE(args), args);
    assert(instance);
    libvlc_int_t *root = instance->p_libvlc_int;
    var_Create(root, "window", VLC_VAR_STRING);
    var_SetString(root, "window", "resize-test,none");
    var_Create(root, "effect-width", VLC_VAR_INTEGER);
    var_Create(root, "effect-height", VLC_VAR_INTEGER);
    var_Create(root, "effect-list", VLC_VAR_STRING);
    var_SetInteger(root, "effect-width", 800);
    var_SetInteger(root, "effect-height", 500);
    var_SetString(root, "effect-list", effect);
    var_Create(root, "goom-width", VLC_VAR_INTEGER);
    var_Create(root, "goom-height", VLC_VAR_INTEGER);
    var_SetInteger(root, "goom-width", 800);
    var_SetInteger(root, "goom-height", 500);
    var_Create(root, "visualization-size", VLC_VAR_INTEGER);
    var_Create(root, "visualization-window-size", VLC_VAR_INTEGER);
    var_SetInteger(root, "visualization-size", -1);

    vlc_player_t *player = vlc_player_New(VLC_OBJECT(root), VLC_PLAYER_LOCK_NORMAL);
    assert(player);
    input_item_t *media = input_item_New("mock://length=20000000;audio_track_count=1", effect);
    assert(media);
    vlc_player_Lock(player);
    assert(vlc_player_SetCurrentMedia(player, media) == VLC_SUCCESS);
    assert(vlc_player_Start(player) == VLC_SUCCESS);
    vlc_player_Unlock(player);
    input_item_Release(media);
    wait_picture(800, 500, 0);
    fprintf(stderr, "%s: initial canvas 800x500 rendered\n", effect);

    resize(root, 1920, 480, 1920, 480);
    resize(root, 975, 549, 974, 548);
    resize(root, 200, 100, goom ? 200 : 532, goom ? 100 : 400);
    resize(root, -1, -1, goom ? 64 : 532, goom ? 64 : 400);
    resize(root, 1280, 720, 1280, 720);
    resize(root, 800, 500, 800, 500);

    unsigned previous = atomic_load(&picture_count);
    var_SetInteger(root, "effect-width", INT64_C(4294967297));
    var_SetInteger(root, "goom-width", INT64_C(4294967297));
    wait_picture(800, 500, previous + 2);
    assert(atomic_load(&window_opens) == 1);

    atomic_store(&fail_format, true);
    previous = atomic_load(&picture_count);
    var_SetInteger(root, "effect-width", 1200);
    var_SetInteger(root, "effect-height", 600);
    var_SetInteger(root, "goom-width", 1200);
    var_SetInteger(root, "goom-height", 600);
    const vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(5);
    while (atomic_load(&failed_formats) == 0)
    {
        assert(vlc_sem_timedwait(&frame_event, deadline) == 0);
    }
    previous = atomic_load(&picture_count);
    wait_picture(800, 500, previous);
    atomic_store(&fail_format, false);
    resize(root, 960, 540, 960, 540);

    const unsigned widths[] = {800, 1280, 1920};
    const unsigned heights[] = {500, 720, 1080};
    for (unsigned i = 0; i < ARRAY_SIZE(widths); ++i)
    {
        previous = atomic_load(&picture_count);
        var_SetInteger(root, "visualization-size", i + 1);
        wait_picture(widths[i], heights[i], previous);
    }
    previous = atomic_load(&picture_count);
    var_SetInteger(root, "visualization-window-size", size_key(1901, 791));
    var_SetInteger(root, "visualization-size", 0);
    wait_picture(1900, 790, previous);
    previous = atomic_load(&picture_count);
    var_SetInteger(root, "visualization-window-size", size_key(1040, 620));
    wait_picture(1040, 620, previous);
    previous = atomic_load(&picture_count);
    var_SetInteger(root, "visualization-size", -1);
    wait_picture(960, 540, previous);
    assert(var_GetInteger(root, "effect-width") == 960);
    assert(var_GetInteger(root, "goom-width") == 960);

    vlc_player_Lock(player);
    assert(vlc_player_GetState(player) == VLC_PLAYER_STATE_PLAYING);
    vlc_player_Stop(player);
    vlc_player_Unlock(player);
    vlc_player_Delete(player);
    libvlc_release(instance);
    assert(atomic_load(&window_opens) == 1);
    assert(atomic_load(&window_closes) == 1);
}

static void Timeout(void *opaque)
{
    (void) opaque;
    fputs("visualization resize test timed out\n", stderr);
    abort();
}

#ifdef VISUAL_RESIZE_TEST_PLUGIN
VLC_EXPORT int visual_resize_test_run(void);
int visual_resize_test_run(void)
#else
int main(void)
#endif
{
    vlc_timer_t timer;
    assert(vlc_timer_create(&timer, Timeout, NULL) == 0);
    vlc_timer_schedule(timer, false, VLC_TICK_FROM_SEC(45), 0);
    const char *effects[] = { "scope", "spectrum", "spectrometer", "vuMeter", "dummy" };
    for (size_t i = 0; i < ARRAY_SIZE(effects); ++i)
    {
        test_resize(effects[i]);
        fprintf(stderr, "%s: live resize and recovery passed\n", effects[i]);
    }
#ifdef VISUAL_RESIZE_TEST_GOOM
    test_resize("goom");
    fprintf(stderr, "goom: live resize and recovery passed\n");
#endif
    vlc_timer_destroy(timer);
    return 0;
}
