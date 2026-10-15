// SPDX-License-Identifier: LGPL-2.1-or-later
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <vlc_common.h>
#undef msg_Warn
#define msg_Warn(...) ((void)0)
#ifdef TEST_EGL14
#undef EGL_VERSION_1_5
#endif
#ifdef TEST_NO_REFERENCE_HEADERS
#undef EGL_KHR_display_reference
#endif
#define USE_PLATFORM_WAYLAND
#define MODULE_NAME egl_wl
#define MODULE_STRING "egl_wl"
#include "../../../modules/video_output/opengl/egl.c"
static bool used_attrs;
static unsigned terminated;
EGLDisplay EGLAPIENTRY eglGetPlatformDisplay(EGLenum platform, void *native, const EGLAttrib *attrs) {
    (void)platform; (void)native; used_attrs = attrs != NULL;
    if(attrs) assert(attrs[0] == EGL_TRACK_REFERENCES_KHR && attrs[1] == EGL_TRUE);
    return (EGLDisplay)1;
}
static EGLDisplay EGLAPIENTRY test_get_display_ext(EGLenum platform, void *native, const EGLint *attrs) {
    (void)platform; (void)native; used_attrs = attrs != NULL;
    if(attrs) assert(attrs[0] == EGL_TRACK_REFERENCES_KHR && attrs[1] == EGL_TRUE);
    return (EGLDisplay)1;
}
EGLBoolean EGLAPIENTRY eglTerminate(EGLDisplay display) { assert(display==(EGLDisplay)1); ++terminated; return EGL_TRUE; }
int main(void) {
    getPlatformDisplayEXT = test_get_display_ext;
    for(unsigned reference = 0; reference < 2; ++reference) {
        vlc_window_t window = {.type=VLC_WINDOW_TYPE_WAYLAND};
        vlc_gl_t gl = {.surface=&window};
        vlc_gl_sys_t *sys = calloc(1,sizeof(*sys)); gl.sys = sys;
        clientExts = reference ? "EGL_KHR_platform_wayland EGL_EXT_platform_wayland EGL_KHR_display_reference" : "EGL_KHR_platform_wayland EGL_EXT_platform_wayland";
        sys->display = OpenDisplay(&gl);
        assert(sys->display==(EGLDisplay)1);
#ifdef TEST_NO_REFERENCE_HEADERS
        bool tracked = false;
#else
        bool tracked = reference;
#endif
        assert(used_attrs == tracked); assert(sys->skip_terminate == !tracked);
        terminated=0; Close(&gl); assert(terminated==(unsigned)tracked);
    }
    puts("PASS: tracked and untracked display lifetime");
}
