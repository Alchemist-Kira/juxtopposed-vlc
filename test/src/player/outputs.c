// SPDX-License-Identifier: LGPL-2.1-or-later
/*****************************************************************************
 * outputs.c: audio/video outputs player test
 *****************************************************************************
 * Copyright (C) 2018-2025 VLC authors and VideoLAN
 *****************************************************************************/

#include "common.h"
#include <vlc_configuration.h>
#include <math.h>

static void
test_no_outputs(struct ctx *ctx)
{
    test_log("test_no_outputs\n");
    vlc_player_t *player = ctx->player;

    struct media_params params = DEFAULT_MEDIA_PARAMS(VLC_TICK_FROM_MS(10));
    player_set_current_mock_media(ctx, "media1", &params, false);
    player_start(ctx);

    wait_state(ctx, VLC_PLAYER_STATE_STOPPING);
    {
        vec_on_vout_changed *vec = &ctx->report.on_vout_changed;
        assert(vec->size == 0);
    }

    audio_output_t *aout = vlc_player_aout_Hold(player);
    assert(!aout);

    test_end(ctx);
}

static void
test_outputs(struct ctx *ctx)
{
    test_log("test_outputs\n");
    vlc_player_t *player = ctx->player;

    /* Test that the player has a valid aout and vout, even before first
     * playback */
    audio_output_t *aout = vlc_player_aout_Hold(player);
    assert(aout);

    vout_thread_t *vout = vlc_player_vout_Hold(player);
    assert(vout);

    size_t vout_count;
    vout_thread_t **vout_list = vlc_player_vout_HoldAll(player, &vout_count);
    assert(vout_count == 1 && vout_list[0] == vout);
    vout_Release(vout_list[0]);
    free(vout_list);
    vout_Release(vout);

    /* Test that the player keep the same aout and vout during playback */
    struct media_params params = DEFAULT_MEDIA_PARAMS(VLC_TICK_FROM_MS(10));

    player_set_current_mock_media(ctx, "media1", &params, false);
    player_start(ctx);

    wait_state(ctx, VLC_PLAYER_STATE_STOPPING);

    {
        vec_on_vout_changed *vec = &ctx->report.on_vout_changed;
        assert(vec->size >= 1);
        assert(vec->data[0].action == VLC_PLAYER_VOUT_STARTED);

        vout_thread_t *same_vout = vlc_player_vout_Hold(player);
        assert(vec->data[0].vout == same_vout);
        vout_Release(same_vout);
    }

    audio_output_t *same_aout = vlc_player_aout_Hold(player);
    assert(same_aout == aout);
    aout_Release(same_aout);

    aout_Release(aout);
    test_end(ctx);
}

static audio_output_t *new_default_output(struct ctx *ctx, vlc_player_t **player)
{
    *player = vlc_player_New(VLC_OBJECT(ctx->vlc->p_libvlc_int), VLC_PLAYER_LOCK_NORMAL);
    assert(*player != NULL);
    audio_output_t *output = vlc_player_aout_Hold(*player);
    assert(output != NULL);
    return output;
}

static void release_default_output(vlc_player_t *player, audio_output_t *output)
{
    aout_Release(output);
    vlc_player_Delete(player);
}

static void test_audio_defaults(struct ctx *ctx)
{
    test_log("test_audio_defaults\n");
    ctx->flags |= AUDIO_TEST_DEFAULTS;
    config_PutInt("volume-save", false);
    config_PutInt("audio-startup-volume", 180);
    config_PutFloat("audio-last-volume", -1.f);
    config_PutPsz("audio-device-default", "headphones");
    config_PutPsz("audio-device-default-module", "test_src_player");

    vlc_player_t *player;
    audio_output_t *output = new_default_output(ctx, &player);
    assert(fabsf(aout_VolumeGet(output) - 1.8f) < 0.001f);
    char *device = aout_DeviceGet(output);
    assert(device != NULL && !strcmp(device, "headphones"));
    free(device);
    assert(aout_VolumeSet(output, 2.2f) == 0);
    assert(config_GetFloat("audio-last-volume") == -1.f);
    release_default_output(player, output);

    config_PutInt("volume-save", true);
    config_PutFloat("audio-last-volume", 0.42f);
    output = new_default_output(ctx, &player);
    // Driver initialization must not overwrite the remembered volume.
    assert(fabsf(aout_VolumeGet(output) - 0.42f) < 0.001f);
    assert(aout_VolumeSet(output, 0.67f) == 0);
    assert(fabsf(config_GetFloat("audio-last-volume") - 0.67f) < 0.001f);
    release_default_output(player, output);
    output = new_default_output(ctx, &player);
    assert(fabsf(aout_VolumeGet(output) - 0.67f) < 0.001f);
    release_default_output(player, output);

    // Device identifiers cannot be carried over to a different driver.
    config_PutPsz("audio-device-default-module", "another-driver");
    output = new_default_output(ctx, &player);
    device = aout_DeviceGet(output);
    assert(device != NULL && !strcmp(device, "speakers"));
    free(device);
    release_default_output(player, output);
    // A disconnected device also falls back to the driver's default.
    config_PutPsz("audio-device-default-module", "test_src_player");
    config_PutPsz("audio-device-default", "disconnected");
    output = new_default_output(ctx, &player);
    device = aout_DeviceGet(output);
    assert(device != NULL && !strcmp(device, "speakers"));
    free(device);
    release_default_output(player, output);

    config_PutPsz("audio-device-default", "");
    config_PutPsz("audio-device-default-module", "");
    config_PutInt("audio-startup-volume", -1);
    config_PutFloat("audio-last-volume", -1.f);
    config_PutInt("volume-save", false);
    output = new_default_output(ctx, &player);
    assert(fabsf(aout_VolumeGet(output) - 0.75f) < 0.001f);
    release_default_output(player, output);
    config_PutInt("volume-save", true);
}

int
main(void)
{
    struct ctx ctx;

    /* Test with --aout=none --vout=none */
    ctx_init(&ctx, DISABLE_VIDEO_OUTPUT | DISABLE_AUDIO_OUTPUT);
    test_no_outputs(&ctx);
    ctx_destroy(&ctx);

    /* Test with normal outputs */
    ctx_init(&ctx, 0);
    test_outputs(&ctx);
    test_audio_defaults(&ctx);
    ctx_destroy(&ctx);

    return 0;
}
