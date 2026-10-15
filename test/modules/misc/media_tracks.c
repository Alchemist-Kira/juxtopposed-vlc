// SPDX-License-Identifier: LGPL-2.1-or-later
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include <vlc/vlc.h>
#include <vlc_common.h>
#undef NDEBUG
#include <assert.h>
#include <vlc_fs.h>
#include <vlc_media_library.h>
#include <vlc_url.h>
#include "../../../lib/libvlc_internal.h"

static libvlc_instance_t *open_library(void)
{
    const char *args[] = {
        "--quiet", "--ignore-config", "--media-library", "--no-auto-preparse",
        "--no-restore-playback-states",
    };
    libvlc_instance_t *instance = libvlc_new(ARRAY_SIZE(args), args);
    assert(instance);
    return instance;
}

static void check_files(vlc_medialibrary_t *ml, int64_t id,
                        const char *main, const char *subtitle,
                        const char *audio)
{
    vlc_ml_media_t *media = vlc_ml_get_media(ml, id);
    assert(media && media->p_files);
    assert(media->p_files->i_nb_items == 1u + !!subtitle + !!audio);
    unsigned main_count = 0, subtitle_count = 0, audio_count = 0;
    for (size_t i = 0; i < media->p_files->i_nb_items; ++i)
    {
        const vlc_ml_file_t *file = &media->p_files->p_items[i];
        switch (file->i_type)
        {
            case VLC_ML_FILE_TYPE_MAIN:
                assert(!strcmp(file->psz_mrl, main));
                ++main_count;
                break;
            case VLC_ML_FILE_TYPE_SUBTITLE:
                assert(subtitle && !strcmp(file->psz_mrl, subtitle));
                ++subtitle_count;
                break;
            case VLC_ML_FILE_TYPE_SOUNDTRACK:
                assert(audio && !strcmp(file->psz_mrl, audio));
                ++audio_count;
                break;
            default:
                assert(!"Unexpected file type");
        }
    }
    assert(main_count == 1 && subtitle_count == !!subtitle && audio_count == !!audio);
    vlc_ml_media_release(media);
}

int main(int argc, char **argv)
{
    /* A Windows cross-build can supply a host path. Otherwise use the build
     * directory. Never use the user's media library or configuration. */
    const char *base = argc > 1 ? argv[1] : TOP_BUILDDIR "/test";
    char *directory;
    assert(asprintf(&directory, "%s/media-tracks-%"PRId64,
                    base, vlc_tick_now()) >= 0);
    assert(vlc_mkdir(directory, 0700) == 0);
    assert(setenv("VLC_USERDATA_PATH", directory, 1) == 0);
    fprintf(stderr, "Using owned media library: %s\n", directory);

    char *path;
    assert(asprintf(&path, "%s/keep captions & accents.srt", directory) >= 0);
    FILE *file = vlc_fopen(path, "wb");
    assert(file);
    assert(fputs("Keep this disk file", file) >= 0);
    assert(fclose(file) == 0);
    char *subtitle = vlc_path2uri(path, NULL);
    assert(subtitle);

    libvlc_instance_t *instance = open_library();
    vlc_medialibrary_t *ml = vlc_ml_instance_get(instance->p_libvlc_int);
    assert(ml);
    vlc_ml_media_t *first = vlc_ml_new_external_media(ml, "file:///first.mkv");
    vlc_ml_media_t *second = vlc_ml_new_external_media(ml, "file:///second.mkv");
    assert(first && second);
    const int64_t first_id = first->i_id, second_id = second->i_id;
    vlc_ml_media_release(first);
    vlc_ml_media_release(second);

    /* Source builds with the unpatched dependency do not have this operation. */
    if (vlc_ml_media_set_external_mrls(ml, first_id,
            VLC_ML_FILE_TYPE_SUBTITLE, NULL, 0) == VLC_ENOTSUP)
    {
        fprintf(stderr, "External track replacement is unavailable\n");
        libvlc_release(instance);
        free(subtitle);
        free(path);
        free(directory);
        return 77;
    }

    const char *audio = "file:///sound.wav";
    assert(vlc_ml_media_add_external_mrl(ml, first_id, audio,
                                         VLC_ML_FILE_TYPE_SOUNDTRACK) == VLC_SUCCESS);
    assert(vlc_ml_media_add_external_mrl(ml, first_id, "file:///old.srt",
                                         VLC_ML_FILE_TYPE_SUBTITLE) == VLC_SUCCESS);
    const char *tracks[] = { subtitle, subtitle };
    assert(vlc_ml_media_set_external_mrls(ml, first_id,
            VLC_ML_FILE_TYPE_SUBTITLE, tracks, ARRAY_SIZE(tracks)) == VLC_SUCCESS);
    assert(vlc_ml_media_set_external_mrls(ml, second_id,
            VLC_ML_FILE_TYPE_SUBTITLE, tracks, 1) == VLC_SUCCESS);
    check_files(ml, first_id, "file:///first.mkv", subtitle, audio);
    check_files(ml, second_id, "file:///second.mkv", subtitle, NULL);

    const char *invalid[][1] = { { NULL }, { "" }, { "file:///first.mkv" }, { audio } };
    for (size_t i = 0; i < ARRAY_SIZE(invalid); ++i)
    {
        assert(vlc_ml_media_set_external_mrls(ml, first_id,
                VLC_ML_FILE_TYPE_SUBTITLE, invalid[i], 1) != VLC_SUCCESS);
        check_files(ml, first_id, "file:///first.mkv", subtitle, audio);
    }
    assert(vlc_ml_media_set_external_mrls(ml, first_id,
            VLC_ML_FILE_TYPE_SUBTITLE, NULL, 1) != VLC_SUCCESS);
    assert(vlc_ml_media_set_external_mrls(ml, first_id,
            VLC_ML_FILE_TYPE_MAIN, NULL, 0) != VLC_SUCCESS);

    libvlc_release(instance);
    instance = open_library();
    ml = vlc_ml_instance_get(instance->p_libvlc_int);
    assert(ml);
    check_files(ml, first_id, "file:///first.mkv", subtitle, audio);
    check_files(ml, second_id, "file:///second.mkv", subtitle, NULL);
    assert(vlc_ml_media_set_external_mrls(ml, first_id,
            VLC_ML_FILE_TYPE_SUBTITLE, NULL, 0) == VLC_SUCCESS);
    check_files(ml, first_id, "file:///first.mkv", NULL, audio);
    check_files(ml, second_id, "file:///second.mkv", subtitle, NULL);
    assert(vlc_ml_media_set_external_mrls(ml, first_id,
            VLC_ML_FILE_TYPE_SOUNDTRACK, NULL, 0) == VLC_SUCCESS);
    check_files(ml, first_id, "file:///first.mkv", NULL, NULL);
    libvlc_release(instance);

    file = vlc_fopen(path, "rb");
    assert(file);
    assert(fclose(file) == 0);
    free(subtitle);
    free(path);
    free(directory);
    /* Retain only this test's database and file under the build directory for
     * inspection. The test runner supplies the process timeout. */
    fprintf(stderr, "Track replacement, validation, restart and disk preservation passed\n");
    return 0;
}
