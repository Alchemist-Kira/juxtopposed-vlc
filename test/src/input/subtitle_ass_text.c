// SPDX-License-Identifier: LGPL-2.1-or-later
#include "../../libvlc/test.h"
#include "../../../modules/codec/libass_plaintext.h"

int main(void)
{
    const struct { const char *ass; const char *plain; } cases[] = {
        {"A {\\fnSerif\\fs80\\1c&H00FF00&}styled{\\r} subtitle", "A styled subtitle"},
        {"First\\NSecond\\nThird\\hword", "First\nSecond\nThird\xc2\xa0word"},
        {"{\\an7\\pos(10,20)\\p1}m 0 0 l 10 10{\\p0}Readable", "Readable"},
        {"{\\p 2}m 0 0 l 20 20{\\rDefault}Text", "Text"},
        {"{\\p1}m 0 0 l 10 10", ""},
        {"{\\pos(10,20)\\pbo5}Positioned text", "Positioned text"},
        {"A {comment}subtitle with {an unfinished brace", "A subtitle with {an unfinished brace"},
        {"Unicode: café 日本語", "Unicode: café 日本語"},
        {"{\\k20}Sing{\\k30}ing", "Singing"},
    };
    for (size_t i = 0; i < ARRAY_SIZE(cases); ++i) {
        char *plain = AssPlainText(cases[i].ass);
        assert(plain != NULL && strcmp(plain, cases[i].plain) == 0);
        free(plain);
    }
    return 0;
}
