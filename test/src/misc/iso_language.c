// SPDX-License-Identifier: LGPL-2.1-or-later
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#include <vlc_common.h>
#include <vlc_iso_lang.h>
#undef NDEBUG
#include <assert.h>

int main(void)
{
    size_t count = 0;
    const iso639_lang_t *languages = vlc_iso639_languages(&count);
    assert(languages && count > 100);
    for (size_t i = 0; i < count; ++i) {
        assert(languages[i].psz_eng_name);
        const char *code = languages[i].psz_iso639_1[0] ? languages[i].psz_iso639_1 : languages[i].psz_iso639_2T;
        if (*code) assert(vlc_find_iso639(code, false));
    }
#if !defined(_WIN32) && !defined(__APPLE__)
    const char *locales[] = { "en_AU.UTF-8", "ja_JP.UTF-8", "de-DE", "zh-Hant-TW", "fra_CA", "fr:en", "C.UTF-8", "invalid" };
    const char *expected[] = { "en", "ja", "de", "zh", "fr", "fr", NULL, NULL };
    for (size_t i = 0; i < ARRAY_SIZE(locales); ++i) {
        assert(setenv("LANGUAGE", locales[i], 1) == 0);
        const iso639_lang_t *language = vlc_get_system_language();
        if (expected[i]) assert(language && !strcmp(language->psz_iso639_1, expected[i]));
        else assert(!language);
    }
    unsetenv("LANGUAGE"); assert(setenv("LC_ALL", "ja_JP.UTF-8", 1) == 0);
    assert(!strcmp(vlc_get_system_language()->psz_iso639_1, "ja"));
#else
    const iso639_lang_t *language = vlc_get_system_language();
    if (language) fprintf(stderr, "System language: %s (%s)\n", language->psz_eng_name, language->psz_iso639_2T);
#endif
    fprintf(stderr, "Language table and system-language checks passed\n");
    return 0;
}
