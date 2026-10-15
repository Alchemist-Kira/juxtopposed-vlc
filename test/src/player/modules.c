// SPDX-License-Identifier: LGPL-2.1-or-later
/*****************************************************************************
 * modules.c: modules used for the player test
 *****************************************************************************
 * Copyright (C) 2018-2025 VLC authors and VideoLAN
 *****************************************************************************/

#include "common.h"

#ifdef OUTPUT_TEARDOWN_TEST
#include <vlc_window.h>

static int teardown_window_Enable(vlc_window_t *window, const vlc_window_cfg_t *cfg)
{
    vlc_window_ReportSize(window, cfg->width, cfg->height);
    return VLC_SUCCESS;
}

static void teardown_window_Disable(vlc_window_t *window)
{
    (void) window;
    vlc_mutex_lock(&window_teardown.lock);
    if (window_teardown.blocked)
    {
        window_teardown.entered = true;
        vlc_cond_signal(&window_teardown.wait);
        const vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(5);
        while (window_teardown.blocked)
            assert(vlc_cond_timedwait(&window_teardown.wait,
                                     &window_teardown.lock, deadline) == 0);
    }
    vlc_mutex_unlock(&window_teardown.lock);
}

static int teardown_window_Open(vlc_window_t *window)
{
    static const struct vlc_window_operations ops = {
        .enable = teardown_window_Enable,
        .disable = teardown_window_Disable,
        .resize = vlc_window_ReportSize,
    };
    window->type = VLC_WINDOW_TYPE_DUMMY;
    window->ops = &ops;
    return VLC_SUCCESS;
}
#endif

#ifdef VIDEO_FILTER_TEST
#include <stdatomic.h>
#include <vlc_vout_display.h>
extern atomic_uint video_filter_opens;
extern atomic_uint video_filter_closes;
extern atomic_uint video_filter_frame_value;
extern vlc_mutex_t video_filter_lock;
extern vlc_cond_t video_filter_wait;
extern video_format_t video_display_format;
extern unsigned video_display_frames;

static void video_display_Display(vout_display_t *display, picture_t *picture)
{
    (void) picture;
    vlc_mutex_lock(&video_filter_lock);
    video_display_format = *display->source;
    video_display_frames++;
    vlc_cond_signal(&video_filter_wait);
    vlc_mutex_unlock(&video_filter_lock);
}

static int video_display_Open(vout_display_t *display, video_format_t *format,
                              vlc_video_context *context)
{
    (void) format; (void) context;
    static const struct vlc_display_operations ops = {
        .display = video_display_Display,
    };
    display->ops = &ops;
    return VLC_SUCCESS;
}

static void video_filter_Notify(void)
{
    vlc_mutex_lock(&video_filter_lock);
    vlc_cond_signal(&video_filter_wait);
    vlc_mutex_unlock(&video_filter_lock);
}

static picture_t *video_filter_Filter(filter_t *filter, picture_t *picture)
{
    atomic_store(&video_filter_frame_value,
                 var_GetInteger(filter, "test-video-filter-value"));
    video_filter_Notify();
    return picture;
}

static void video_filter_Close(filter_t *filter)
{
    (void) filter;
    atomic_fetch_add(&video_filter_closes, 1);
    video_filter_Notify();
}

static int video_filter_Open(filter_t *filter)
{
    int ret = var_Create(filter, "test-video-filter-value", VLC_VAR_INTEGER | VLC_VAR_DOINHERIT);
    if (ret != VLC_SUCCESS)
        return ret;
    static const struct vlc_filter_operations ops = {
        .filter_video = video_filter_Filter, .close = video_filter_Close,
    };
    filter->ops = &ops;
    atomic_fetch_add(&video_filter_opens, 1);
    return VLC_SUCCESS;
}
#endif

#define MODULE_NAME test_src_player
#undef VLC_DYNAMIC_PLUGIN
#include <vlc_plugin.h>
/* Define a builtin module for mocked parts */
const char vlc_module_name[] = MODULE_STRING;

struct aout_sys
{
    vlc_tick_t first_pts;
    vlc_tick_t first_play_date;
    vlc_tick_t pos;

    struct ctx *ctx;
};

static void aout_Play(audio_output_t *aout, block_t *block, vlc_tick_t date)
{
    struct aout_sys *sys = aout->sys;

    if (sys->first_play_date == VLC_TICK_INVALID)
    {
        assert(sys->first_pts == VLC_TICK_INVALID);
        sys->first_play_date = date;
        sys->first_pts = block->i_pts;

        struct ctx *ctx = sys->ctx;
        vlc_player_Lock(ctx->player);
        VEC_PUSH(on_aout_first_pts, sys->first_pts);
        vlc_player_Unlock(ctx->player);
    }

    aout_TimingReport(aout, sys->first_play_date + sys->pos - VLC_TICK_0,
                      sys->first_pts + sys->pos);
    sys->pos += block->i_length;
    block_Release(block);
}

static void aout_Flush(audio_output_t *aout)
{
    struct aout_sys *sys = aout->sys;
    sys->pos = 0;
    sys->first_pts = sys->first_play_date = VLC_TICK_INVALID;
}

static void aout_Stop(audio_output_t *aout)
{
    struct aout_sys *sys = aout->sys;

    if (sys->first_play_date != VLC_TICK_INVALID)
    {
        /* Same dates as the timing reports from Play() */
        struct report_aout_stop report = {
            .date = vlc_tick_now(),
            .end_date = sys->first_play_date + sys->pos - VLC_TICK_0,
        };

        struct ctx *ctx = sys->ctx;
        vlc_player_Lock(ctx->player);
        VEC_PUSH(on_aout_stop, report);
        vlc_player_Unlock(ctx->player);
    }

    aout_Flush(aout);
}

static void aout_Pause(audio_output_t *aout, bool pause, vlc_tick_t date)
{
    (void) date;
    if (pause)
        aout_Flush(aout);
}

static void aout_InstantDrain(audio_output_t *aout)
{
    aout_DrainedReport(aout);
}

static int aout_Start(audio_output_t *aout, audio_sample_format_t *restrict fmt)
{
    (void) aout;
    return AOUT_FMT_LINEAR(fmt) ? VLC_SUCCESS : VLC_EGENERIC;
}

static void
aout_Close(vlc_object_t *obj)
{
    audio_output_t *aout = (audio_output_t *)obj;
    free(aout->sys);
}

static int aout_TestVolumeSet(audio_output_t *aout, float volume)
{
    aout_VolumeReport(aout, volume);
    return 0;
}

static int aout_TestDeviceSelect(audio_output_t *aout, const char *id)
{
    if (id != NULL && strcmp(id, "speakers") && strcmp(id, "headphones"))
        return -1;
    aout_DeviceReport(aout, id != NULL ? id : "speakers");
    return 0;
}

static int aout_Open(vlc_object_t *obj)
{
    audio_output_t *aout = (audio_output_t *)obj;

    aout->start = aout_Start;
    aout->play = aout_Play;
    aout->pause = aout_Pause;
    aout->flush = aout_Flush;
    aout->stop = aout_Stop;
    aout->volume_set = NULL;
    aout->mute_set = NULL;

    struct aout_sys *sys = aout->sys = malloc(sizeof(*sys));
    assert(sys != NULL);

    sys->ctx = var_InheritAddress(aout, "test-ctx");
    assert(sys->ctx != NULL);
    if (sys->ctx->flags & AUDIO_TEST_DEFAULTS)
    {
        aout->volume_set = aout_TestVolumeSet;
        aout->device_select = aout_TestDeviceSelect;
        aout_HotplugReport(aout, "speakers", "Speakers");
        aout_HotplugReport(aout, "headphones", "Headphones");
        aout_DeviceReport(aout, "speakers");
        aout_VolumeReport(aout, 0.75f);
    }

    if (sys->ctx->flags & AUDIO_INSTANT_DRAIN)
        aout->drain = aout_InstantDrain;

    aout_Flush(aout);

    return VLC_SUCCESS;
}

static block_t *resampler_Resample(filter_t *filter, block_t *in)
{
    VLC_UNUSED(filter);
    return in;
}

static void resampler_Close(filter_t *filter)
{
    VLC_UNUSED(filter);
}

static int resampler_Open(vlc_object_t *obj)
{
    filter_t *filter = (filter_t *)obj;
    static const struct vlc_filter_operations filter_ops =
    { .filter_audio = resampler_Resample, .close = resampler_Close, };
    filter->ops = &filter_ops;
    return VLC_SUCCESS;
}

vlc_module_begin()
    /* This aout module will report audio timings perfectly, but without any
     * delay, in order to be usable for player tests. Indeed, this aout will
     * report timings immediately from Play(), but points will be in the
     * future (like when aout->time_get() is used). */
    set_capability("audio output", 0)
    set_callbacks(aout_Open, aout_Close)
    add_submodule ()
    /* aout will insert a resampler that can have samples delay, even for 1:1
     * Insert our own resampler that keeps blocks and pts untouched. */
    set_capability ("audio resampler", 9999)
    set_callback (resampler_Open)
#ifdef VIDEO_FILTER_TEST
    add_submodule()
    set_capability("video filter", 0)
    add_shortcut("test-video-filter")
    add_integer("test-video-filter-value", 1, "Test value", NULL)
    set_callback_video_filter(video_filter_Open)
    add_submodule()
    add_shortcut("test-video-display")
    set_callback_display(video_display_Open, 0)
#endif
#ifdef OUTPUT_TEARDOWN_TEST
    add_submodule()
    set_capability("vout window", 0)
    add_shortcut("test-window-teardown")
    set_callback(teardown_window_Open)
#endif
vlc_module_end()

VLC_EXPORT const vlc_plugin_cb vlc_static_modules[] = {
    VLC_SYMBOL(vlc_entry),
    NULL
};
