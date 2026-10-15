/* SPDX-License-Identifier: LGPL-2.1-or-later */
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include <wchar.h>
#include <vlc_common.h>
#include <vlc_fs.h>
#include <windows.h>

/* Keep one process's first pipe open while other processes create theirs.
 * A process-local counter alone gives all of them the same global pipe name. */
int main(int argc, char **argv)
{
    (void)argv;
    int fds[2];
    if (vlc_pipe(fds) != 0) {
        fprintf(stderr, "Cannot create independent process pipe\n");
        return 1;
    }
    if (argc == 1) {
        wchar_t path[32768], command[32780];
        DWORD length = GetModuleFileNameW(NULL, path, ARRAY_SIZE(path));
        assert(length > 0 && length < ARRAY_SIZE(path));
        int result = swprintf(command, ARRAY_SIZE(command), L"\"%ls\" --child", path);
        assert(result > 0 && (size_t)result < ARRAY_SIZE(command));
        for (unsigned i = 0; i < 3; ++i) {
            STARTUPINFOW startup = { .cb = sizeof(startup) };
            PROCESS_INFORMATION process;
            assert(CreateProcessW(path, command, NULL, NULL, FALSE, 0,
                                  NULL, NULL, &startup, &process));
            DWORD wait = WaitForSingleObject(process.hProcess, 10000);
            if (wait != WAIT_OBJECT_0) {
                TerminateProcess(process.hProcess, 1);
                WaitForSingleObject(process.hProcess, INFINITE);
            }
            DWORD status;
            assert(GetExitCodeProcess(process.hProcess, &status));
            CloseHandle(process.hThread);
            CloseHandle(process.hProcess);
            assert(wait == WAIT_OBJECT_0 && status == 0);
        }
    }
    vlc_close(fds[0]);
    vlc_close(fds[1]);
    return 0;
}
