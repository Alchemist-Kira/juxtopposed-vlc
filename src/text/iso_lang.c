/*****************************************************************************
 * iso_lang.c: function to decode language code (in dvd or a52 for instance).
 *****************************************************************************
 * Copyright (C) 1998-2004 VLC authors and VideoLAN
 *
 * Author: Stéphane Borel <stef@via.ecp.fr>
 *         Arnaud de Bossoreille de Ribou <bozo@via.ecp.fr>
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

/*****************************************************************************
 * Preamble
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>

#include <vlc_common.h>

#include "vlc_iso_lang.h"
#ifdef _WIN32
# include <windows.h>
#elif defined(__APPLE__)
# include <CoreFoundation/CoreFoundation.h>
#endif

/*****************************************************************************
 * Local tables
 *****************************************************************************/
#include "iso-639_def.h"

const iso639_lang_t *vlc_iso639_languages(size_t *count)
{
    *count = ARRAY_SIZE(p_languages) - 1;
    return p_languages;
}

#ifndef _WIN32
static const iso639_lang_t *LanguageFromLocale(const char *locale)
{
    size_t length = strcspn(locale, "_-.:@ ");
    if (length != 2 && length != 3) return NULL;
    char code[4];
    memcpy(code, locale, length); code[length] = '\0';
    return vlc_find_iso639(code, false);
}
#endif

#ifdef _WIN32
static const iso639_lang_t *LanguageFromWindowsLocale(const wchar_t *name)
{
    wchar_t code[4];
    if (!GetLocaleInfoEx(name, LOCALE_SISO639LANGNAME, code, ARRAY_SIZE(code))) return NULL;
    char ascii[4] = {0};
    for (size_t i = 0; i < 3 && code[i]; ++i) ascii[i] = (char)code[i];
    return vlc_find_iso639(ascii, false);
}
#endif

const iso639_lang_t *vlc_get_system_language(void)
{
#ifdef _WIN32
# if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
    ULONG count = 0, length = 0;
    const iso639_lang_t *language = NULL;
    if (GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, &count, NULL, &length) && length)
    {
        wchar_t *names = vlc_alloc(length, sizeof(*names));
        if (names && GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, &count, names, &length))
        {
            language = LanguageFromWindowsLocale(names);
        }
        free(names);
    }
    if (language) return language;
# endif
    wchar_t name[LOCALE_NAME_MAX_LENGTH];
    if (LCIDToLocaleName(MAKELCID(GetUserDefaultUILanguage(), SORT_DEFAULT), name, ARRAY_SIZE(name), 0))
        return LanguageFromWindowsLocale(name);
    return NULL;
#elif defined(__APPLE__)
    const iso639_lang_t *language = NULL;
    CFArrayRef languages = CFLocaleCopyPreferredLanguages();
    if (languages && CFArrayGetCount(languages))
    {
        char locale[128];
        if (CFStringGetCString(CFArrayGetValueAtIndex(languages, 0), locale, sizeof(locale), kCFStringEncodingUTF8))
            language = LanguageFromLocale(locale);
    }
    if (languages) CFRelease(languages);
    return language;
#else
    const char *variables[] = { "LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG" };
    for (size_t i = 0; i < ARRAY_SIZE(variables); ++i)
    {
        const char *locale = getenv(variables[i]);
        if (locale && *locale) return LanguageFromLocale(locale);
    }
    return NULL;
#endif
}

static const iso639_lang_t * GetLang_1( const char * psz_code )
{
    const iso639_lang_t *p_lang;

    for( p_lang = p_languages; p_lang->psz_eng_name; p_lang++ )
        if( !strcasecmp( p_lang->psz_iso639_1, psz_code ) )
            return p_lang;

    return NULL;
}

static const iso639_lang_t * GetLang_2T( const char * psz_code )
{
    const iso639_lang_t *p_lang;

    for( p_lang = p_languages; p_lang->psz_eng_name; p_lang++ )
        if( !strcasecmp( p_lang->psz_iso639_2T, psz_code ) )
            return p_lang;

    return NULL;
}

static const iso639_lang_t * GetLang_2B( const char * psz_code )
{
    const iso639_lang_t *p_lang;

    for( p_lang = p_languages; p_lang->psz_eng_name; p_lang++ )
        if( !strcasecmp( p_lang->psz_iso639_2B, psz_code ) )
            return p_lang;

    return NULL;
}

static const iso639_lang_t * GetLang_name( const char * psz_lang )
{
    const iso639_lang_t *p_lang;

    for( p_lang = p_languages; p_lang->psz_eng_name; p_lang++ )
        if( !strcasecmp( p_lang->psz_eng_name, psz_lang ) )
            return p_lang;

    return NULL;
}

const iso639_lang_t * vlc_find_iso639( const char *code, bool try_name )
{
    const iso639_lang_t *result = NULL;
    size_t len = strlen(code);

    if (len == 2)
        result = GetLang_1(code);
    else if (len == 3)
    {
        result = GetLang_2B(code);
        if (result == NULL)
            result = GetLang_2T(code);
    }

    if (try_name && !result && len != 0)
        result = GetLang_name(code);

    return result;
}
