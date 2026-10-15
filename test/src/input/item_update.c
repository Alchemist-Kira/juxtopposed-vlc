// SPDX-License-Identifier: LGPL-2.1-or-later
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#undef NDEBUG
#include <assert.h>
#include <vlc_common.h>
#include <vlc_input_item.h>

static void AddTrack(input_item_t *item, const char *uri, enum slave_type type,
                     enum slave_priority priority, bool forced)
{
    input_item_slave_t *track = input_item_slave_New(uri, type, priority);
    assert(track);
    track->b_forced = forced;
    assert(input_item_AddSlave(item, track) == VLC_SUCCESS);
}

int main(void)
{
    const char *uri = "file:///movie.mkv";
    input_item_t *current = input_item_New(uri, NULL);
    input_item_t *parsed = input_item_New(uri, NULL);
    assert(current && parsed);
    AddTrack(current, "file:///audio.wav", SLAVE_TYPE_GENERIC, SLAVE_PRIORITY_USER, true);
    AddTrack(current, "file:///captions.srt", SLAVE_TYPE_SPU, SLAVE_PRIORITY_USER, true);
    input_item_SetTitle(parsed, "Parsed title");
    /* A result from an earlier preparse must not erase newer track links. */
    assert(input_item_Update(current, parsed) == VLC_SUCCESS);
    assert(current->i_slaves == 2);
    assert(current->pp_slaves[0]->b_forced && current->pp_slaves[1]->b_forced);
    char *title = input_item_GetTitle(current);
    assert(title && !strcmp(title, "Parsed title"));
    free(title);

    AddTrack(parsed, "file:///audio.wav", SLAVE_TYPE_GENERIC, SLAVE_PRIORITY_MATCH_NONE, false);
    AddTrack(parsed, "file:///automatic.srt", SLAVE_TYPE_SPU, SLAVE_PRIORITY_MATCH_ALL, false);
    for (unsigned i = 0; i < 3; ++i)
    {
        assert(input_item_Update(current, parsed) == VLC_SUCCESS);
        assert(current->i_slaves == 3);
        assert(current->pp_slaves[0]->i_priority == SLAVE_PRIORITY_USER);
        assert(current->pp_slaves[0]->b_forced);
        assert(current->pp_slaves[1]->b_forced);
        assert(!strcmp(current->pp_slaves[2]->psz_uri, "file:///automatic.srt"));
    }
    input_item_t *copy = input_item_Copy(current);
    assert(copy && copy->i_slaves == 3);
    assert(copy->pp_slaves[0]->b_forced && copy->pp_slaves[1]->b_forced);
    input_item_t *other = input_item_New("file:///other.mkv", NULL);
    assert(other);
    assert(input_item_Update(current, other) == VLC_EGENERIC);
    assert(current->i_slaves == 3);
    input_item_Release(other);
    input_item_Release(copy);
    input_item_Release(parsed);
    input_item_Release(current);
    return 0;
}
