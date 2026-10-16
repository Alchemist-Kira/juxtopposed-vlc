/*****************************************************************************
 * image.c: test for the image_handler code from vlc_image.h
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
#define MODULE_NAME test_misc_image
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

#include <limits.h>

#include "../lib/libvlc_internal.h"

const char vlc_module_name[] = MODULE_STRING;

static atomic_bool encoder_opened = false;

static void CheckPictureExport(vlc_object_t *root)
{
    static const struct {
        unsigned coded_width, coded_height, width, height;
        unsigned sar_num, sar_den;
        int override_width, override_height;
        unsigned expected_width, expected_height;
    } cases[] = {
        /* A valid near-square pixel ratio used to overflow the height to 6. */
        {864, 418, 854, 388, 46560, 46543, 252, 0, 252, 114},
        {864, 418, 854, 388, 1, 1, 252, 0, 252, 114},
        /* The corresponding portrait case scales from the requested height. */
        {418, 864, 388, 854, 46543, 46560, 0, 252, 114, 252},
        {418, 864, 388, 854, 1, 1, 0, 252, 114, 252},
        {720, 576, 720, 576, 16, 15, 252, 0, 252, 189},
        {576, 720, 576, 720, 15, 16, 0, 252, 189, 252},
    };
    for (size_t i = 0; i < ARRAY_SIZE(cases); ++i)
    {
        video_format_t source;
        video_format_Init(&source, VLC_CODEC_RGBA);
        video_format_Setup(&source, VLC_CODEC_RGBA,
                           cases[i].coded_width, cases[i].coded_height,
                           cases[i].width, cases[i].height,
                           cases[i].sar_num, cases[i].sar_den);
        picture_t *picture = picture_NewFromFormat(&source);
        assert(picture != NULL);
        block_t *block = NULL;
        video_format_t exported = {0};
        assert(picture_Export(root, &block, &exported, picture, VLC_CODEC_PNG,
                              cases[i].override_width, cases[i].override_height,
                              false) == VLC_SUCCESS);
        assert(block != NULL);
        assert(exported.i_width == cases[i].expected_width);
        assert(exported.i_height == cases[i].expected_height);
        assert(exported.i_visible_width == exported.i_width);
        assert(exported.i_visible_height == exported.i_height);
        block_Release(block);
        picture_Release(picture);
        video_format_Clean(&source);
    }
}

static int OpenIntf(vlc_object_t *root)
{
    image_handler_t *ih = image_HandlerCreate(root);
    assert(ih != NULL);

    video_format_t fmt_in;
    video_format_Init(&fmt_in, VLC_CODEC_RGBA);
    fmt_in.i_width = fmt_in.i_visible_width = 800;
    fmt_in.i_height = fmt_in.i_visible_height = 600;

    video_format_t fmt_out;
    video_format_Init(&fmt_out, 0);
    fmt_out.i_width = fmt_out.i_visible_width = 800;
    fmt_out.i_height = fmt_out.i_visible_height = 600;

    picture_t *picture = picture_NewFromFormat(&fmt_in);
    assert(picture != NULL);

    block_t *block;

    block = image_Write(ih, picture, &fmt_in, VLC_CODEC_PNG, &fmt_out);
    assert(block != NULL);
    block_Release(block);
    picture_Release(picture);
    assert(atomic_load(&encoder_opened));
    atomic_store(&encoder_opened, false);

    picture = picture_NewFromFormat(&fmt_in);
    fmt_out.i_width = fmt_out.i_visible_width = 400;
    fmt_out.i_height = fmt_out.i_visible_height = 300;
    block = image_Write(ih, picture, &fmt_in, VLC_CODEC_PNG, &fmt_out);
    assert(block != NULL);
    block_Release(block);
    picture_Release(picture);
    assert(atomic_load(&encoder_opened));

    image_HandlerDelete(ih);
    CheckPictureExport(root);

    return VLC_SUCCESS;
}

static block_t * EncodeVideo(encoder_t *encoder, picture_t *pic)
{
    (void)encoder; (void)pic;

    /* Dummy encoder */
    return block_Alloc(1);
}

static int OpenEncoder(vlc_object_t *obj)
{
    encoder_t *encoder = (encoder_t*)obj;
    static const struct vlc_encoder_operations ops =
    {
        .encode_video = EncodeVideo
    };
    encoder->ops = &ops;
    atomic_store(&encoder_opened, true);
    return VLC_SUCCESS;
}

static picture_t *ConvertVideo(filter_t *filter, picture_t *pic)
{
    picture_Release(pic);
    return picture_NewFromFormat(&filter->fmt_out.video);
}

static int OpenConverter(filter_t *filter)
{
    static const struct vlc_filter_operations ops =
    {
        .filter_video = ConvertVideo,
    };
    filter->ops = &ops;
    return VLC_SUCCESS;
}

/** Inject the mocked modules as a static plugin: **/
vlc_module_begin()
    set_callback(OpenEncoder)
    set_capability("image encoder", INT_MAX)

    add_submodule()
        set_callback_video_converter(OpenConverter, INT_MAX)

    add_submodule()
        set_callback(OpenIntf)
        set_capability("interface", 0)

vlc_module_end()

VLC_EXPORT const vlc_plugin_cb vlc_static_modules[] = {
    VLC_SYMBOL(vlc_entry),
    NULL
};


int main(void)
{
    test_init();

    const char * const args[] = {
        "-vvv", "--vout=dummy", "--aout=dummy", "--text-renderer=dummy",
        "--no-auto-preparse",
    };

    libvlc_instance_t *vlc = libvlc_new(ARRAY_SIZE(args), args);

    libvlc_InternalAddIntf(vlc->p_libvlc_int, MODULE_STRING);
    libvlc_InternalPlay(vlc->p_libvlc_int);

    libvlc_release(vlc);

}
