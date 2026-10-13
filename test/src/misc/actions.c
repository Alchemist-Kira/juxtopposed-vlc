// SPDX-License-Identifier: GPL-2.0-or-later
#include "../../libvlc/test.h"
#include "../lib/libvlc_internal.h"
#include <vlc_actions.h>

struct observed_action
{
    unsigned count;
    vlc_action_id_t action;
};

static int on_action(vlc_object_t *obj, const char *name, vlc_value_t previous,
                     vlc_value_t current, void *opaque)
{
    (void)obj; (void)name; (void)previous;
    struct observed_action *observed = opaque;
    observed->count++;
    observed->action = current.i_int;
    return VLC_SUCCESS;
}

static void check_key(libvlc_int_t *core, struct observed_action *observed,
                      uint32_t key, vlc_action_id_t expected)
{
    observed->count = 0;
    var_SetInteger(core, "key-pressed", key);
    assert(observed->count == (expected == ACTIONID_NONE ? 0 : 1));
    if (expected != ACTIONID_NONE) assert(observed->action == expected);
}

static void test_wheel(bool explicit_binding)
{
    const char *args[test_defaults_nargs + 2];
    memcpy(args, test_defaults_args, sizeof(test_defaults_args));
    args[test_defaults_nargs] = "--ignore-config";
    args[test_defaults_nargs + 1] = explicit_binding ? "--key-stop=Mouse Wheel Up" : "--key-stop=s";
    libvlc_instance_t *vlc = libvlc_new(ARRAY_SIZE(args), args);
    assert(vlc != NULL);
    libvlc_int_t *core = vlc->p_libvlc_int;
    struct observed_action observed = {0};
    var_AddCallback(core, "key-action", on_action, &observed);
    var_Create(core, "hotkeys-y-wheel-mode", VLC_VAR_INTEGER);
    var_Create(core, "hotkeys-x-wheel-mode", VLC_VAR_INTEGER);
    var_Create(core, "hotkeys-wheel-direction", VLC_VAR_BOOL);

    if (explicit_binding)
    {
        var_SetInteger(core, "hotkeys-y-wheel-mode", -1);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_STOP);
        var_SetBool(core, "hotkeys-wheel-direction", true);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_STOP);
        check_key(core, &observed, KEY_MOUSEWHEELDOWN, ACTIONID_NONE);
    }
    else
    {
        var_SetInteger(core, "hotkeys-y-wheel-mode", 0);
        var_SetInteger(core, "hotkeys-x-wheel-mode", 2);
        var_SetBool(core, "hotkeys-wheel-direction", false);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_COMBO_VOL_FOV_UP);
        check_key(core, &observed, KEY_MOUSEWHEELDOWN, ACTIONID_COMBO_VOL_FOV_DOWN);
        check_key(core, &observed, KEY_MOUSEWHEELRIGHT, ACTIONID_JUMP_FORWARD_EXTRASHORT);
        check_key(core, &observed, KEY_MOUSEWHEELLEFT, ACTIONID_JUMP_BACKWARD_EXTRASHORT);

        observed.count = 0;
        var_SetInteger(core, "global-key-pressed", KEY_MOUSEWHEELUP);
        assert(observed.count == 0);

        /* A preferences change must work without restarting the instance. */
        var_SetBool(core, "hotkeys-wheel-direction", true);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_COMBO_VOL_FOV_DOWN);
        check_key(core, &observed, KEY_MOUSEWHEELRIGHT, ACTIONID_JUMP_BACKWARD_EXTRASHORT);
        var_SetInteger(core, "hotkeys-y-wheel-mode", 2);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_JUMP_BACKWARD_EXTRASHORT);
        var_SetInteger(core, "hotkeys-y-wheel-mode", 3);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_JUMP_FORWARD_EXTRASHORT);
        var_SetBool(core, "hotkeys-wheel-direction", false);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_JUMP_BACKWARD_EXTRASHORT);
        var_SetInteger(core, "hotkeys-y-wheel-mode", -1);
        check_key(core, &observed, KEY_MOUSEWHEELUP, ACTIONID_NONE);
        check_key(core, &observed, KEY_MOUSEWHEELDOWN, ACTIONID_NONE);
    }
    var_DelCallback(core, "key-action", on_action, &observed);
    libvlc_release(vlc);
}

int main(void)
{
    test_init();
    test_wheel(false);
    test_wheel(true);
    return 0;
}
