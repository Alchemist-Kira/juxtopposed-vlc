// SPDX-License-Identifier: LGPL-2.1-or-later
#include "common.h"
#include <vlc_configuration.h>

static void test_subtitle_delay(struct ctx *ctx, int legacy, int milliseconds)
{
    vlc_player_t *player = ctx->player;
    config_PutInt("sub-delay", legacy);
    config_PutInt("sub-delay-ms", milliseconds);
    const vlc_tick_t expected = VLC_TICK_FROM_MS(legacy * 100 + milliseconds);

    // The same preference must apply again when another input is created.
    for (unsigned episode = 0; episode < 2; ++episode)
    {
        struct media_params params = DEFAULT_MEDIA_PARAMS(VLC_TICK_FROM_SEC(1));
        params.track_count[SPU_ES] = 1;
        player_set_current_mock_media(ctx, "subtitle-delay", &params, false);
        player_start(ctx);
        wait_state(ctx, VLC_PLAYER_STATE_PLAYING);
        assert(vlc_player_GetSubtitleDelay(player) == expected);
        test_end(ctx);
    }
}

int main(void)
{
    struct ctx ctx;
    ctx_init(&ctx, DISABLE_VIDEO);
    const int64_t previous_legacy = config_GetInt("sub-delay");
    const int64_t previous_ms = config_GetInt("sub-delay-ms");
    test_subtitle_delay(&ctx, 0, 0);
    test_subtitle_delay(&ctx, 12, 0); // Preserve legacy tenths of a second.
    test_subtitle_delay(&ctx, 0, 375);
    test_subtitle_delay(&ctx, 0, -125);
    test_subtitle_delay(&ctx, 12, -25); // Both options are additive.
    config_PutInt("sub-delay", previous_legacy);
    config_PutInt("sub-delay-ms", previous_ms);
    ctx_destroy(&ctx);
    return 0;
}
