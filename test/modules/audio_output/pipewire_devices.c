// SPDX-License-Identifier: LGPL-2.1-or-later
#define MODULE_NAME aout_pipewire
#define MODULE_STRING "aout_pipewire"
#include "../../../modules/audio_output/pipewire.c"

/* Test the actual module callbacks with a controlled registry and output.
 * No running audio server or hardware is needed. */
static unsigned lock_depth;
static char reported[64];
static unsigned restarts;

void vlc_pw_lock(struct vlc_pw_context *ctx)
{
    (void)ctx;
    ++lock_depth;
}

void vlc_pw_unlock(struct vlc_pw_context *ctx)
{
    (void)ctx;
    assert(lock_depth > 0);
    --lock_depth;
}

void *vlc_pw_registry_bind(struct vlc_pw_context *ctx, uint32_t id,
                           const char *type, uint32_t version)
{
    (void)ctx; (void)id; (void)type; (void)version;
    return NULL;
}

static void device_report(audio_output_t *aout, const char *id)
{
    (void)aout;
    assert(lock_depth > 0);
    snprintf(reported, sizeof reported, "%s", id ? id : "");
}

static void hotplug_report(audio_output_t *aout, const char *id, const char *name)
{
    (void)aout; (void)id; (void)name;
}

static void restart_request(audio_output_t *aout, bool dec)
{
    (void)aout;
    assert(dec);
    ++restarts;
}

static const struct vlc_audio_output_events test_events = {
    .device_report = device_report,
    .hotplug_report = hotplug_report,
    .restart_request = restart_request,
};

static void add_node(audio_output_t *aout, unsigned id,
                     const char *serial, const char *name)
{
    struct spa_dict_item props[] = {
        SPA_DICT_ITEM_INIT(PW_KEY_MEDIA_CLASS, "Audio/Sink"),
        SPA_DICT_ITEM_INIT(PW_KEY_OBJECT_SERIAL, serial),
        SPA_DICT_ITEM_INIT(PW_KEY_NODE_NAME, name),
        SPA_DICT_ITEM_INIT(PW_KEY_NODE_DESCRIPTION, name),
    };
    struct spa_dict dict = SPA_DICT_INIT(props, ARRAY_SIZE(props));
    vlc_pw_lock(NULL);
    registry_node(aout, id, 0, 0, &dict);
    vlc_pw_unlock(NULL);
}

static void set_default(audio_output_t *aout, const char *value)
{
    vlc_pw_lock(NULL);
    metadata_property(aout, PW_ID_CORE, "default.audio.sink", "Spa:String:JSON", value);
    vlc_pw_unlock(NULL);
}

static void remove_node(audio_output_t *aout, unsigned id)
{
    vlc_pw_lock(NULL);
    registry_global_remove(aout, id);
    vlc_pw_unlock(NULL);
}

int main(void)
{
    struct vlc_pw_aout sys = { .initial = { .target = SPA_ID_INVALID } };
    vlc_list_init(&sys.node_list);
    audio_output_t aout = { .sys = &sys, .events = &test_events };
    add_node(&aout, 10, "18446744073709551614", "speakers");
    add_node(&aout, 11, "200", "headphones");
    set_default(&aout, "{\"name\":\"speakers\"}");
    assert(!strcmp(reported, "18446744073709551614"));

    /* Clearing or losing the default must clear its old checkmark. */
    set_default(&aout, NULL);
    assert(!strcmp(reported, ""));
    set_default(&aout, "{\"name\":\"missing\"}");
    assert(!strcmp(reported, ""));
    set_default(&aout, "{\"name\":\"speakers\"}");
    assert(!DeviceSelect(&aout, ""));
    assert(sys.initial.target == SPA_ID_INVALID);
    assert(!strcmp(reported, "18446744073709551614"));
    assert(DeviceSelect(&aout, "200junk") != 0);
    assert(DeviceSelect(&aout, "-1") != 0);
    assert(sys.initial.target == SPA_ID_INVALID);

    /* Selection is synchronized, retains the full serial and restarts playback. */
    sys.stream = (void *)&sys;
    assert(!DeviceSelect(&aout, "18446744073709551614"));
    assert(sys.initial.target == UINT64_MAX - 1);
    assert(restarts == 1);
    assert(!lock_depth);
    assert(!DeviceSelect(&aout, "200"));
    assert(sys.initial.target == 200);
    assert(!strcmp(reported, "200"));
    set_default(&aout, "{\"name\":\"speakers\"}");
    assert(!strcmp(reported, "200"));
    assert(!DeviceSelect(&aout, NULL));
    assert(sys.initial.target == SPA_ID_INVALID);
    assert(!strcmp(reported, "18446744073709551614"));
    sys.stream = NULL;

    /* Unplugging an explicit target resumes following the default. */
    DeviceSelect(&aout, "200");
    remove_node(&aout, 11);
    assert(sys.initial.target == SPA_ID_INVALID);
    assert(!strcmp(reported, "18446744073709551614"));
    remove_node(&aout, 10);
    assert(!strcmp(reported, ""));
    add_node(&aout, 12, "300", "speakers");
    assert(!strcmp(reported, "300"));
    /* Replacing an existing node must not leave a dangling name-list entry. */
    add_node(&aout, 12, "301", "speakers");
    assert(!strcmp(reported, "301"));
    tdestroy(sys.nodes, node_free);
    assert(vlc_list_is_empty(&sys.node_list));
    assert(!lock_depth);
    return 0;
}
