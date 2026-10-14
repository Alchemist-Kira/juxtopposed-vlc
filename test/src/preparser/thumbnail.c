/*****************************************************************************
 * thumbnail.c: test thumbnailing API
 *****************************************************************************
 * Copyright (C) 2018 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
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

#include "../../libvlc/test.h"
#include "../lib/libvlc_internal.h"

#include <vlc_common.h>
#include <vlc_preparser.h>
#include <vlc_input_item.h>
#include <vlc_picture.h>
#include <vlc_modules.h>
#include <vlc_url.h>
#include <vlc_fs.h>

#include <errno.h>

#define MOCK_DURATION VLC_TICK_FROM_SEC( 5 * 60 )

const struct
{
    uint32_t i_nb_video_tracks;
    uint32_t i_nb_audio_tracks;
    vlc_tick_t i_add_video_track_at;
    vlc_tick_t i_time;
    float f_pos;
    bool b_use_pos;
    bool b_fast_seek;
    bool b_can_control_pace;
    vlc_tick_t i_timeout;
    bool b_expected_success;
} test_params[] = {
    /* Simple test with a thumbnail at 60s, with a video track */
    { 1, 0, VLC_TICK_INVALID, VLC_TICK_FROM_SEC( 60 ), .0f, false, true, true,
      VLC_TICK_INVALID, true },
    /* Test without fast-seek */
    { 1, 0, VLC_TICK_INVALID, VLC_TICK_FROM_SEC( 60 ), .0f, false, false, true,
      VLC_TICK_INVALID, true },
    /* Seek by position test */
    { 1, 0, VLC_TICK_INVALID, 0, .3f, true, true, true, VLC_TICK_INVALID, true },
    /* Precise position seek, before the first frame is decoded. */
    { 1, 0, VLC_TICK_INVALID, 0, .3f, true, false, true, VLC_TICK_INVALID, true },
    /* Seek at a negative position */
    { 1, 0, VLC_TICK_INVALID, -12345, .0f, false, true, true, VLC_TICK_INVALID, true },
    /* Take a thumbnail of a file without video, which should timeout. */
    { 0, 1, VLC_TICK_INVALID, VLC_TICK_FROM_SEC( 60 ), .0f, false, true, false, VLC_TICK_FROM_MS( 100 ), false },
    /* Take a thumbnail of a file with a video track starting later */
    { 1, 1, VLC_TICK_FROM_SEC( 60 ), VLC_TICK_FROM_SEC( 30 ), .0f, false, true, true,
      VLC_TICK_INVALID, true },
};

struct test_ctx
{
    vlc_cond_t cond;
    vlc_mutex_t lock;
    size_t test_idx;
    bool b_done;
};

static void thumbnailer_callback( vlc_preparser_req *req, int status,
                                  picture_t* thumbnail, void *data )
{
    struct test_ctx* p_ctx = data;
    vlc_mutex_lock( &p_ctx->lock );

    if ( thumbnail != NULL )
    {
        assert( test_params[p_ctx->test_idx].b_expected_success &&
                "Expected failure but got a thumbnail" );
        assert( thumbnail->format.i_chroma == VLC_CODEC_ARGB );
        assert( status == VLC_SUCCESS );

        vlc_tick_t expected_date;
        /* Don't rely on the expected date if it was purposely invalid */
        if ( test_params[p_ctx->test_idx].b_use_pos == true )
            expected_date = MOCK_DURATION * test_params[p_ctx->test_idx].f_pos;
        else if ( test_params[p_ctx->test_idx].i_add_video_track_at != VLC_TICK_INVALID )
            expected_date = test_params[p_ctx->test_idx].i_add_video_track_at;
        else
        {
            if ( test_params[p_ctx->test_idx].i_time < 0 )
                expected_date = 0;
            else
                expected_date = test_params[p_ctx->test_idx].i_time;
        }
        /* The mock source runs at 25 fps. Allow rounding to one frame. */
        assert( llabs(thumbnail->date - (VLC_TICK_0 + expected_date)) <=
                VLC_TICK_FROM_MS(40) && "Unexpected picture date" );
    }
    else
    {
        assert( !test_params[p_ctx->test_idx].b_expected_success &&
                "Expected a thumbnail but got a failure" );
        if (test_params[p_ctx->test_idx].i_timeout == VLC_TICK_INVALID)
            assert( status == VLC_EGENERIC );
        else
            assert( status == VLC_ETIMEOUT );
    }

    p_ctx->b_done = true;
    vlc_cond_signal( &p_ctx->cond );
    vlc_mutex_unlock( &p_ctx->lock );
    vlc_preparser_req_Release( req );
}

static void test_thumbnails( libvlc_instance_t* p_vlc, bool external )
{
    struct test_ctx ctx;
    vlc_cond_init( &ctx.cond );
    vlc_mutex_init( &ctx.lock );

    for ( size_t i = 0; i < ARRAY_SIZE(test_params); ++i)
    {
        char* psz_mrl;

        ctx.test_idx = i;
        ctx.b_done = false;

        const struct vlc_preparser_cfg cfg = {
            .types = VLC_PREPARSER_TYPE_THUMBNAIL,
            .timeout = test_params[i].i_timeout,
            .external_process = external,
        };

        vlc_preparser_t* p_thumbnailer = vlc_preparser_New(
                    VLC_OBJECT( p_vlc->p_libvlc_int ), &cfg );
        assert( p_thumbnailer != NULL );


        if ( asprintf( &psz_mrl, "mock://video_track_count=%u;audio_track_count=%u"
                       ";length=%" PRId64 ";can_control_pace=%s;video_chroma=ARGB;video_add_track_at=%" PRId64,
                       test_params[i].i_nb_video_tracks,
                       test_params[i].i_nb_audio_tracks, MOCK_DURATION,
                       test_params[i].b_can_control_pace ? "true" : "false",
                       test_params[i].i_add_video_track_at ) < 0 )
            assert( !"Failed to allocate mock mrl" );
        input_item_t* p_item = input_item_New( psz_mrl, "mock item" );
        assert( p_item != NULL );

        vlc_mutex_lock( &ctx.lock );

        vlc_preparser_req *req;
        struct vlc_thumbnailer_arg thumb_arg;
        if ( test_params[i].b_use_pos )
        {
            thumb_arg.seek.type = VLC_THUMBNAILER_SEEK_POS;
            thumb_arg.seek.pos = test_params[i].f_pos;
            thumb_arg.seek.speed = test_params[i].b_fast_seek ?
                VLC_THUMBNAILER_SEEK_FAST : VLC_THUMBNAILER_SEEK_PRECISE;
        }
        else
        {
            thumb_arg.seek.type = VLC_THUMBNAILER_SEEK_TIME;
            thumb_arg.seek.time = test_params[i].i_time;
            thumb_arg.seek.speed = test_params[i].b_fast_seek ?
                VLC_THUMBNAILER_SEEK_FAST : VLC_THUMBNAILER_SEEK_PRECISE;
        }
        thumb_arg.hw_dec = false;
        static const struct vlc_thumbnailer_cbs cbs = {
            .on_ended = thumbnailer_callback,
        };
        req = vlc_preparser_req_NewThumbnail( p_thumbnailer, p_item,
                                              &thumb_arg, &cbs, &ctx );
        assert( req != NULL );
        assert( vlc_preparser_Submit( p_thumbnailer, req ) == VLC_SUCCESS );

        while ( ctx.b_done == false )
            vlc_cond_wait( &ctx.cond, &ctx.lock );

        vlc_mutex_unlock( &ctx.lock );

        input_item_Release( p_item );
        free( psz_mrl );

        vlc_preparser_Delete( p_thumbnailer );
    }
}

static void thumbnailer_callback_cancel( vlc_preparser_req *req, int status,
                                         picture_t* p_thumbnail, void *data )
{
    (void)req;
    assert( p_thumbnail == NULL );
    assert( status == -EINTR );

    vlc_sem_t *sem = data;
    vlc_sem_post(sem);
}

static void test_cancel_thumbnail( libvlc_instance_t* p_vlc, bool external )
{
    const struct vlc_preparser_cfg cfg = {
        .types = VLC_PREPARSER_TYPE_THUMBNAIL,
        .timeout = VLC_TICK_INVALID,
        .external_process = external,
    };
    vlc_preparser_t* p_thumbnailer = vlc_preparser_New(
                VLC_OBJECT( p_vlc->p_libvlc_int ), &cfg );
    assert( p_thumbnailer != NULL );

    const char* psz_mrl = "mock://video_track_count=0;audio_track_count=1;"
                          /* force timeout: parsing will take the same time as length */
                          "can_control_pace=false;"
                          "length=20000000";
    input_item_t* p_item = input_item_New( psz_mrl, "mock item" );
    assert( p_item != NULL );

    static const struct vlc_thumbnailer_cbs cbs = {
        .on_ended = thumbnailer_callback_cancel,
    };

    vlc_sem_t sem;
    vlc_sem_init(&sem, 0);
    vlc_preparser_req *req =
        vlc_preparser_req_NewThumbnail( p_thumbnailer, p_item, NULL, &cbs, &sem );
    assert( req != NULL );
    assert( vlc_preparser_Submit( p_thumbnailer, req ) == VLC_SUCCESS );

    vlc_preparser_Cancel( p_thumbnailer, req );

    vlc_sem_wait(&sem);

    vlc_preparser_req_Release( req );

    input_item_Release( p_item );

    vlc_preparser_Delete( p_thumbnailer );
}

struct still_thumbnail_ctx
{
    vlc_sem_t completed;
    vlc_tick_t expected_date;
};

static void still_thumbnail_ended(vlc_preparser_req *req, int status,
                                  picture_t *picture, void *data)
{
    (void)req;
    struct still_thumbnail_ctx *ctx = data;
    assert(status == VLC_SUCCESS);
    assert(picture != NULL);
    assert(picture->date == ctx->expected_date);
    vlc_sem_post(&ctx->completed);
}

static void test_still_thumbnail(libvlc_instance_t *vlc)
{
    bool have_jpeg_decoder = module_exists("avcodec") && module_exists("avformat");
    bool have_image = module_exists("image");

    const struct vlc_preparser_cfg cfg = {
        .types = VLC_PREPARSER_TYPE_THUMBNAIL,
        .timeout = VLC_TICK_FROM_SEC(2),
    };
    vlc_preparser_t *parser = vlc_preparser_New(VLC_OBJECT(vlc->p_libvlc_int), &cfg);
    assert(parser != NULL);
    char *uri = vlc_path2uri(TOP_SRCDIR "/test/samples/image.jpg", NULL);
    assert(uri != NULL);
    char *image_path = NULL;
    char *image_uri = NULL;
    if (have_image)
    {
        const char *tmpdir = getenv("TMPDIR");
        if (tmpdir == NULL) tmpdir = getenv("TEMP");
        if (tmpdir == NULL) tmpdir = "/tmp";
        assert(asprintf(&image_path, "%s/vlc-thumbnail-XXXXXX", tmpdir) >= 0);
        int fd = vlc_mkstemp(image_path);
        assert(fd != -1);
        /* A one-pixel Farbfeld image needs only the mandatory raw decoder. */
        const unsigned char image[] = {
            'f', 'a', 'r', 'b', 'f', 'e', 'l', 'd',
            0, 0, 0, 1, 0, 0, 0, 1,
            255, 255, 0, 0, 0, 0, 255, 255,
        };
        assert(write(fd, image, sizeof(image)) == sizeof(image));
        close(fd);
        image_uri = vlc_path2uri(image_path, NULL);
        assert(image_uri != NULL);
    }
    for (unsigned i = 0; i < 4; ++i)
    {
        bool seek = i % 2;
        if ((seek && !have_image) || (!seek && !have_jpeg_decoder))
            continue;
        input_item_t *item = input_item_New(seek ? image_uri : uri, "thumbnail timing fixture");
        assert(item != NULL);
        if (seek)
        {
            input_item_AddOption(item, "demux=image", VLC_INPUT_OPTION_TRUSTED);
            input_item_AddOption(item, "image-duration=10", VLC_INPUT_OPTION_TRUSTED);
            input_item_AddOption(item, "image-fps=25/1", VLC_INPUT_OPTION_TRUSTED);
            input_item_AddOption(item, "image-decode=0", VLC_INPUT_OPTION_TRUSTED);
        }
        else
        {
            input_item_AddOption(item, "demux=avformat", VLC_INPUT_OPTION_TRUSTED);
            input_item_AddOption(item, "codec=avcodec", VLC_INPUT_OPTION_TRUSTED);
        }
        /* A paused playback start must not stop thumbnail decoding. */
        if (i >= 2)
            input_item_AddOption(item, "start-paused", VLC_INPUT_OPTION_TRUSTED);

        struct still_thumbnail_ctx ctx = {
            .expected_date = VLC_TICK_0 + (seek ? VLC_TICK_FROM_MS(520) : 0),
        };
        vlc_sem_init(&ctx.completed, 0);
        struct vlc_thumbnailer_arg arg = {0};
        arg.seek.type = VLC_THUMBNAILER_SEEK_TIME;
        arg.seek.time = seek ? VLC_TICK_FROM_MS(520) : 0;
        arg.seek.speed = VLC_THUMBNAILER_SEEK_PRECISE;
        const struct vlc_thumbnailer_cbs cbs = {.on_ended = still_thumbnail_ended};
        vlc_preparser_req *req = vlc_preparser_req_NewThumbnail(parser, item, &arg, &cbs, &ctx);
        assert(req != NULL);
        assert(vlc_preparser_Submit(parser, req) == VLC_SUCCESS);
        vlc_sem_wait(&ctx.completed);
        vlc_preparser_req_Release(req);
        input_item_Release(item);
    }
    free(uri);
    if (image_path != NULL) vlc_unlink(image_path);
    free(image_path);
    free(image_uri);
    vlc_preparser_Delete(parser);
}

int main( void )
{
    test_init();

    static const char * argv[] = {
        "-v",
        "--ignore-config",
    };
    libvlc_instance_t *vlc = libvlc_new(ARRAY_SIZE(argv), argv);
    assert(vlc);

    fprintf(stderr, "Run with internal preparser...\n");
    test_thumbnails( vlc, false );
    test_cancel_thumbnail( vlc, false );
    test_still_thumbnail(vlc);

#if !defined(HAVE_VLC_PROCESS_SPAWN)
    fprintf(stderr, "Run with external preparser...\n");
    test_thumbnails( vlc, true );
    test_cancel_thumbnail( vlc, true );
#endif


    libvlc_release( vlc );
}
