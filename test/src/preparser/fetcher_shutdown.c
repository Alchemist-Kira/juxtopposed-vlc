// SPDX-License-Identifier: LGPL-2.1-or-later
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#include <vlc/vlc.h>
#include <vlc_common.h>
#undef NDEBUG
#include <assert.h>
#include "../../../lib/libvlc_internal.h"
#include <vlc_atomic.h>
const char vlc_module_name[] = "fetcher-shutdown-test";
/* These fixtures have no per-item options. The configuration registry is
 * private to the core and is not part of the stage-cancellation test. */
bool config_IsSafe(const char *name);
bool config_IsSafe(const char *name) { (void)name; return false; }

/* The fetcher is private to the core. Exercise its stage handoff directly,
 * without a module loader or a network service controlling the timing. */
#include "../../../src/preparser/fetcher.c"

struct test_context {
    input_fetcher_t *fetcher;
    vlc_executor_t *next;
    input_item_t *queued;
    vlc_sem_t started;
    vlc_sem_t cancelled;
    vlc_sem_t resume;
    atomic_uint completions;
};

static void on_ended(input_item_t *item, bool fetched, void *opaque)
{
    struct test_context *ctx = opaque;
    assert(!fetched);
    atomic_fetch_add(&ctx->completions, 1);
    if (item == ctx->queued)
        vlc_sem_post(&ctx->cancelled);
}

static const input_fetcher_callbacks_t callbacks = {
    .on_art_fetch_ended = on_ended,
};

static void blocked_stage(void *opaque)
{
    struct task *task = opaque;
    struct test_context *ctx = task->userdata;
    vlc_interrupt_set(&task->interrupt);
    vlc_sem_post(&ctx->started);
    vlc_sem_wait(&ctx->resume);

    /* Deletion cancels queued work and interrupts this running stage. Even
     * if the stage finishes its search, it must not enqueue a successor. */
    assert(vlc_killed());
    int ret = Submit(ctx->fetcher, ctx->next, task->item, task->options,
                     task->cbs, task->userdata);
    assert(ret == VLC_EGENERIC);
    NotifyArtFetchEnded(task, false);
    vlc_interrupt_set(NULL);
    FetcherRemoveTask(ctx->fetcher, task);
    TaskDelete(task);
}

static void *delete_fetcher(void *opaque)
{
    input_fetcher_Delete(opaque);
    return NULL;
}

static void check_shutdown(vlc_object_t *owner, bool network_stage,
                           bool download_next)
{
    struct test_context ctx;
    ctx.fetcher = input_fetcher_New(owner, VLC_PREPARSER_TYPE_FETCHMETA_ALL);
    assert(ctx.fetcher);
    ctx.next = download_next ? ctx.fetcher->executor_downloader
                             : ctx.fetcher->executor_network;
    ctx.queued = input_item_New("file:///fetcher-queued", "queued");
    input_item_t *running = input_item_New("file:///fetcher-running", "running");
    assert(ctx.queued && running);
    vlc_sem_init(&ctx.started, 0);
    vlc_sem_init(&ctx.cancelled, 0);
    vlc_sem_init(&ctx.resume, 0);
    atomic_init(&ctx.completions, 0);
    vlc_executor_t *first = network_stage ? ctx.fetcher->executor_network
                                         : ctx.fetcher->executor_local;
    struct task *task = TaskNew(ctx.fetcher, first, running,
                               VLC_PREPARSER_TYPE_FETCHMETA_ALL, &callbacks, &ctx);
    assert(task);
    task->runnable.run = blocked_stage;
    vlc_mutex_lock(&ctx.fetcher->lock);
    vlc_list_append(&task->node, &ctx.fetcher->submitted_tasks);
    vlc_executor_Submit(first, &task->runnable);
    vlc_mutex_unlock(&ctx.fetcher->lock);
    vlc_sem_wait(&ctx.started);
    assert(Submit(ctx.fetcher, first, ctx.queued,
                  VLC_PREPARSER_TYPE_FETCHMETA_ALL, &callbacks, &ctx) == VLC_SUCCESS);

    vlc_thread_t deleting;
    int ret = vlc_clone(&deleting, delete_fetcher, ctx.fetcher);
    assert(ret == 0);
    vlc_sem_wait(&ctx.cancelled);
    vlc_sem_post(&ctx.resume);
    vlc_join(deleting, NULL);
    assert(atomic_load(&ctx.completions) == 2);
    input_item_Release(running);
    input_item_Release(ctx.queued);
}

int main(void)
{
    /* The test runner supplies the timeout on every platform. */
    const char *args[] = { "--quiet", "--no-media-library", "--fetch-art-threads=1" };
    libvlc_instance_t *vlc = libvlc_new(ARRAY_SIZE(args), args);
    assert(vlc);
    for (unsigned i = 0; i < 20; ++i) {
        check_shutdown(VLC_OBJECT(vlc->p_libvlc_int), false, false);
        check_shutdown(VLC_OBJECT(vlc->p_libvlc_int), false, true);
        check_shutdown(VLC_OBJECT(vlc->p_libvlc_int), true, true);
    }
    libvlc_release(vlc);
    return 0;
}
