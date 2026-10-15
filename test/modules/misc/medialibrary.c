/*****************************************************************************
 * medialibrary.c: test for the medialibrary code
 *****************************************************************************
 * Copyright (C) 2023 Videolabs
 *
 * Authors: Alexandre Janniaux <ajanni@videolabs.io>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

/* Define a builtin module for mocked parts */
#define MODULE_NAME test_misc_medialibrary
#undef VLC_DYNAMIC_PLUGIN

#include "../../libvlc/test.h"

#include <vlc/vlc.h>

#include <vlc_common.h>
#include <vlc_image.h>
#include <vlc_picture.h>
#include <vlc_plugin.h>
#include <vlc_block.h>
#include <vlc_codec.h>
#include <vlc_filter.h>

#include <vlc_media_library.h>
#include <vlc_player.h>
#include <vlc_url.h>
#include <vlc_configuration.h>
#include <vlc_variables.h>
#include <ftw.h>

#include "../lib/libvlc_internal.h"

const char vlc_module_name[] = MODULE_STRING;

static int exitcode = 0;

static void TrackListChanged(vlc_player_t *player, enum vlc_player_list_action action,
                              const struct vlc_player_track *track, void *data)
{
    (void)player; (void)action; (void)track;
    vlc_cond_signal(data);
}

static void PlayerStateChanged(vlc_player_t *player, enum vlc_player_state state, void *data)
{
    (void)player; (void)state;
    vlc_cond_signal(data);
}

static void TestAssociatedTracks(vlc_object_t *root, vlc_medialibrary_t *ml,
                                 const vlc_ml_media_t *media, const char *mrl)
{
    char *directory = config_GetUserDir(VLC_USERDATA_DIR);
    char *path;
    assert(asprintf(&path, "%s/aux captions & accents.srt", directory) >= 0);
    free(directory);
    FILE *file = fopen(path, "wb");
    assert(file);
    fputs("1\n00:00:00,000 --> 00:01:00,000\nAssociated subtitle\n", file);
    assert(fclose(file) == 0);
    char *subtitle = vlc_path2uri(path, NULL);
    free(path);
    assert(subtitle);
    const char *audio = "mock://audio_track_count=1;length=100000000";
    assert(vlc_ml_media_add_external_mrl(ml, media->i_id, subtitle,
                                        VLC_ML_FILE_TYPE_SUBTITLE) == VLC_SUCCESS);
    assert(vlc_ml_media_add_external_mrl(ml, media->i_id, audio,
                                        VLC_ML_FILE_TYPE_SOUNDTRACK) == VLC_SUCCESS);
    /* A secondary file must not resolve to its parent when opened on its own. */
    assert(vlc_ml_get_media_by_mrl(ml, subtitle) == NULL);
    assert(vlc_ml_get_media_by_mrl(ml, audio) == NULL);
    vlc_ml_media_t *standalone = vlc_ml_new_external_media(ml, audio);
    assert(standalone);
    vlc_ml_media_t *lookup = vlc_ml_get_media_by_mrl(ml, audio);
    assert(lookup && lookup->i_id == standalone->i_id);
    vlc_ml_media_release(lookup);
    assert(vlc_ml_media_add_external_mrl(ml, standalone->i_id, subtitle,
                                        VLC_ML_FILE_TYPE_SUBTITLE) == VLC_SUCCESS);
    vlc_ml_media_release(standalone);
    assert(vlc_ml_media_add_external_mrl(ml, media->i_id, "file:///part.mkv",
                                        VLC_ML_FILE_TYPE_PART) == VLC_SUCCESS);
    lookup = vlc_ml_get_media_by_mrl(ml, "file:///part.mkv");
    assert(lookup && lookup->i_id == media->i_id);
    vlc_ml_media_release(lookup);

    /* Track discovery does not need a desktop window. */
    var_Create(root, "video", VLC_VAR_BOOL);
    var_SetBool(root, "video", false);
    vlc_player_t *player = vlc_player_New(root, VLC_PLAYER_LOCK_NORMAL);
    assert(player);
    vlc_cond_t changed;
    vlc_cond_init(&changed);
    const struct vlc_player_cbs callbacks = {
        .on_track_list_changed = TrackListChanged,
        .on_state_changed = PlayerStateChanged,
    };
    input_item_t *item = input_item_New(mrl, "Associated tracks");
    assert(item);
    vlc_player_Lock(player);
    vlc_player_listener_id *listener = vlc_player_AddListener(player, &callbacks, &changed);
    assert(listener);
    for (unsigned attempt = 0; attempt < 2; ++attempt)
    {
        assert(vlc_player_SetCurrentMedia(player, item) == VLC_SUCCESS);
        assert(vlc_player_Start(player) == VLC_SUCCESS);
        while (vlc_player_GetState(player) != VLC_PLAYER_STATE_PLAYING ||
               vlc_player_GetTrackCount(player, AUDIO_ES) < 1 ||
               vlc_player_GetTrackCount(player, SPU_ES) < 1)
            vlc_player_CondWait(player, &changed);
        assert(vlc_player_GetTrackCount(player, AUDIO_ES) == 1);
        assert(vlc_player_GetTrackCount(player, SPU_ES) == 1);
        vlc_player_Stop(player);
        while (vlc_player_GetState(player) != VLC_PLAYER_STATE_STOPPED)
            vlc_player_CondWait(player, &changed);
    }
    vlc_player_RemoveListener(player, listener);
    vlc_player_Unlock(player);
    vlc_player_Delete(player);
    input_item_Release(item);
    free(subtitle);
}

static void ValidateThumbnail(void *data, const vlc_ml_event_t *event)
{
    if (event->i_type != VLC_ML_EVENT_MEDIA_THUMBNAIL_GENERATED)
        return;

    assert(event->media_thumbnail_generated.b_success);
    vlc_sem_t *sem = data;
    vlc_sem_post(sem);
}

static int OpenIntf(vlc_object_t *root)
{
    vlc_medialibrary_t *ml = vlc_ml_instance_get(root);
    if (ml == NULL)
    {
        exitcode = 77;
        return VLC_SUCCESS;
    }

    #define MOCK_URL "mock://video_track_count=1;length=100000000;" \
                     "video_width=800;video_height=600"
    vlc_ml_media_t *media = vlc_ml_new_external_media(ml, MOCK_URL);

    vlc_sem_t sem;
    vlc_sem_init(&sem, 0);

    vlc_ml_event_callback_t *listener =
        vlc_ml_event_register_callback(ml, ValidateThumbnail, &sem);
    vlc_ml_media_generate_thumbnail(ml, media->i_id,
            VLC_ML_THUMBNAIL_SMALL, 800, 600, 0.f);

    vlc_sem_wait(&sem);
    vlc_ml_event_unregister_callback(ml, listener);

    TestAssociatedTracks(root, ml, media, MOCK_URL);

    vlc_ml_media_release(media);

    return VLC_SUCCESS;
}

/** Inject the mocked modules as a static plugin: **/
vlc_module_begin()
    set_callback(OpenIntf)
    set_capability("interface", 0)
vlc_module_end()

VLC_EXPORT const vlc_plugin_cb vlc_static_modules[] = {
    VLC_SYMBOL(vlc_entry),
    NULL
};

static int cleanup_tmpdir(const char *dirpath, const struct stat *sb,
                          int typeflag, struct FTW *ftwbuf)
{
    (void)sb; (void)typeflag; (void)ftwbuf;
    return remove(dirpath);
}

int main(void)
{
    char template[] = "/tmp/vlc.test." MODULE_STRING ".XXXXXX";
    const char *tempdir = mkdtemp(template);
    if (tempdir == NULL)
    {
        assert(tempdir != NULL);
        return -1;
    }
    fprintf(stderr, "Using VLC_USERDATA_PATH directory %s\n", tempdir);
    setenv("VLC_USERDATA_PATH", tempdir, 1);

    test_init();

    const char * const args[] = {
        "-vvv", "--vout=dummy", "--aout=dummy", "--text-renderer=dummy",
        "--no-auto-preparse", "--media-library", "--ignore-config",
        "--no-restore-playback-states", "--no-sub-autodetect-file"
    };

    libvlc_instance_t *vlc = libvlc_new(ARRAY_SIZE(args), args);

    libvlc_InternalAddIntf(vlc->p_libvlc_int, MODULE_STRING);
    libvlc_InternalPlay(vlc->p_libvlc_int);

    libvlc_release(vlc);

    /* Remove temporary directory */
    nftw(tempdir, cleanup_tmpdir, FOPEN_MAX, FTW_DEPTH | FTW_MOUNT | FTW_PHYS);
    return exitcode;
}
