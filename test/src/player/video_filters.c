// SPDX-License-Identifier: LGPL-2.1-or-later
#include "common.h"
#include <vlc_configuration.h>
#include <stdatomic.h>

atomic_uint video_filter_opens;
atomic_uint video_filter_closes;
atomic_uint video_filter_frame_value;
vlc_mutex_t video_filter_lock = VLC_STATIC_MUTEX;
vlc_cond_t video_filter_wait;
video_format_t video_display_format;
unsigned video_display_frames;

static video_format_t wait_picture(struct ctx *ctx)
{
    const vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(5);
    vlc_player_Unlock(ctx->player);
    vlc_mutex_lock(&video_filter_lock);
    const unsigned count = video_display_frames;
    while (video_display_frames == count)
        assert(vlc_cond_timedwait(&video_filter_wait, &video_filter_lock, deadline) == 0);
    video_format_t format = video_display_format;
    vlc_mutex_unlock(&video_filter_lock);
    vlc_player_Lock(ctx->player);
    return format;
}

static void test_crop_aspect(struct ctx *ctx, vout_thread_t *output)
{
    video_format_t format = wait_picture(ctx);
    assert(format.i_visible_width == 1280 && format.i_visible_height == 720);
    for (unsigned attempt = 0; attempt < 5; ++attempt)
    {
        assert(var_SetString(output, "aspect-ratio", "4:3") == VLC_SUCCESS);
        assert(var_SetString(output, "crop", "16:9") == VLC_SUCCESS);
        assert(var_SetString(output, "crop", "1:1") == VLC_SUCCESS);
        format = wait_picture(ctx);
        assert(format.i_visible_width == 960 && format.i_visible_height == 720);
        assert(format.i_x_offset == 160 && format.i_y_offset == 0);
        assert(format.i_sar_num * 4 == format.i_sar_den * 3);
    }
    assert(var_SetString(output, "crop", "") == VLC_SUCCESS);
    format = wait_picture(ctx);
    assert(format.i_visible_width == 1280 && format.i_visible_height == 720);
    assert(format.i_x_offset == 0 && format.i_y_offset == 0);
    assert(var_SetString(output, "aspect-ratio", "") == VLC_SUCCESS);
    format = wait_picture(ctx);
    assert(format.i_sar_num == format.i_sar_den);
    // Border crops also start from the decoder's original visible rectangle.
    for (unsigned attempt = 0; attempt < 3; ++attempt)
    {
        assert(var_SetString(output, "crop", "10+20+30+40") == VLC_SUCCESS);
        assert(var_SetString(output, "aspect-ratio", attempt % 2 ? "" : "4:3") == VLC_SUCCESS);
        format = wait_picture(ctx);
        assert(format.i_visible_width == 1240 && format.i_visible_height == 660);
        assert(format.i_x_offset == 10 && format.i_y_offset == 20);
    }
}

static void wait_value(struct ctx *ctx, atomic_uint *counter, unsigned value)
{
    const vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(5);
    vlc_player_Unlock(ctx->player);
    vlc_mutex_lock(&video_filter_lock);
    while (atomic_load(counter) != value)
        assert(vlc_cond_timedwait(&video_filter_wait, &video_filter_lock, deadline) == 0);
    vlc_mutex_unlock(&video_filter_lock);
    vlc_player_Lock(ctx->player);
}

int main(void)
{
    struct ctx ctx;
    vlc_cond_init(&video_filter_wait);
    ctx_init(&ctx, DISABLE_AUDIO);
    struct media_params params = DEFAULT_MEDIA_PARAMS(VLC_TICK_FROM_SEC(30));
    params.config = "video[0]{width=1280,height=720}";
    assert(var_SetString(ctx.vlc->p_libvlc_int, "vout", "test-video-display") == VLC_SUCCESS);
    // Keep two filters active: changing a non-command option must rebuild
    // both, rather than clear the chain or retain only the changed filter.
    player_set_current_mock_media(&ctx, "video-filters", &params, false);
    player_start(&ctx);
    wait_state(&ctx, VLC_PLAYER_STATE_PLAYING);
    while (ctx.report.on_vout_changed.size == 0)
        vlc_player_CondWait(ctx.player, &ctx.wait);
    vout_thread_t *output = vlc_player_vout_Hold(ctx.player);
    assert(output != NULL);
    assert(var_SetString(output, "video-filter", "test-video-filter:test-video-filter") == VLC_SUCCESS);
    wait_value(&ctx, &video_filter_frame_value, 1);
    assert(atomic_load(&video_filter_opens) == 2);

    for (int value = 2; value <= 4; ++value)
    {
        assert(var_SetInteger(output, "test-video-filter-value", value) == VLC_SUCCESS);
        wait_value(&ctx, &video_filter_frame_value, value);
        assert(atomic_load(&video_filter_opens) == (unsigned) value * 2);
        assert(atomic_load(&video_filter_closes) == (unsigned) (value - 1) * 2);
    }
    // Explicitly clearing the chain must still remove both filters and their
    // proxy callbacks. A later parameter edit must not call unloaded filters.
    assert(var_SetString(output, "video-filter", "") == VLC_SUCCESS);
    wait_value(&ctx, &video_filter_closes, 8);
    assert(var_SetInteger(output, "test-video-filter-value", 5) == VLC_SUCCESS);
    test_crop_aspect(&ctx, output);
    test_end(&ctx);

    // A stopped output is retained for the next input. Changes to its filter
    // settings must remain safe and take effect when it starts again.
    assert(var_SetString(output, "video-filter", "test-video-filter:test-video-filter") == VLC_SUCCESS);
    assert(var_SetInteger(output, "test-video-filter-value", 6) == VLC_SUCCESS);
    player_set_current_mock_media(&ctx, "video-filters-restart", &params, false);
    player_start(&ctx);
    wait_state(&ctx, VLC_PLAYER_STATE_PLAYING);
    wait_value(&ctx, &video_filter_frame_value, 6);
    assert(atomic_load(&video_filter_opens) == 10);
    vout_Release(output);
    test_end(&ctx);
    ctx_destroy(&ctx);
    return 0;
}
