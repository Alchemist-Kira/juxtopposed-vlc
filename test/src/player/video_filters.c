// SPDX-License-Identifier: LGPL-2.1-or-later
#include "common.h"
#include <vlc_configuration.h>
#include <stdatomic.h>

atomic_uint video_filter_opens;
atomic_uint video_filter_closes;
atomic_uint video_filter_frame_value;
vlc_mutex_t video_filter_lock = VLC_STATIC_MUTEX;
vlc_cond_t video_filter_wait;

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
    vout_Release(output);
    test_end(&ctx);
    ctx_destroy(&ctx);
    return 0;
}
