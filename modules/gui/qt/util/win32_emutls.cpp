// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtCore/qglobal.h>

#if defined(__MINGW32__) && defined(QT_STATIC)
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>

namespace {
// The compiler's emulated TLS ABI uses four pointer-sized fields. Each static
// Qt TLS variable supplies one control block with an initially zero index.
struct Control {
    uintptr_t size;
    uintptr_t alignment;
    uintptr_t index;
    void *initialValue;
};

struct ThreadStorage {
    unsigned destructorRounds;
    size_t count;
    void **values;
};

pthread_once_t once = PTHREAD_ONCE_INIT;
pthread_mutex_t indexLock = PTHREAD_MUTEX_INITIALIZER;
pthread_key_t storageKey;
uintptr_t nextIndex = 0;

void destroyStorage(void *pointer)
{
    auto *storage = static_cast<ThreadStorage *>(pointer);
    // MinGW's fallback C++ destructors also use pthread keys. Their order is
    // unspecified, so keep the storage alive while Qt's thread_local objects
    // are destroyed. Free it in the final key-destructor pass instead.
    if (++storage->destructorRounds < PTHREAD_DESTRUCTOR_ITERATIONS) {
        if (pthread_setspecific(storageKey, storage) != 0)
            abort();
        return;
    }
    for (size_t i = 0; i < storage->count; ++i)
        _aligned_free(storage->values[i]);
    free(storage->values);
    free(storage);
}

void initialize()
{
    if (pthread_key_create(&storageKey, destroyStorage) != 0)
        abort();
}
} // namespace

// Keep this implementation inside the static MinGW Qt plugin. Using libgcc's
// allocator can release emulated TLS before the C++ destructor that uses it,
// crashing Qt's render thread and preventing the interface thread from joining.
extern "C" void *__emutls_get_address(void *pointer)
{
    auto *control = static_cast<Control *>(pointer);
    if (pthread_once(&once, initialize) != 0)
        abort();
    uintptr_t index = __atomic_load_n(&control->index, __ATOMIC_ACQUIRE);
    if (index == 0) {
        pthread_mutex_lock(&indexLock);
        index = control->index;
        if (index == 0) {
            if (nextIndex == UINTPTR_MAX)
                abort();
            index = ++nextIndex;
            __atomic_store_n(&control->index, index, __ATOMIC_RELEASE);
        }
        pthread_mutex_unlock(&indexLock);
    }

    auto *storage = static_cast<ThreadStorage *>(pthread_getspecific(storageKey));
    if (!storage) {
        storage = static_cast<ThreadStorage *>(calloc(1, sizeof(*storage)));
        if (!storage || pthread_setspecific(storageKey, storage) != 0)
            abort();
    }
    if (index > storage->count) {
        if (index > SIZE_MAX / sizeof(void *))
            abort();
        auto **values = static_cast<void **>(realloc(storage->values, index * sizeof(void *)));
        if (!values)
            abort();
        memset(values + storage->count, 0, (index - storage->count) * sizeof(void *));
        storage->values = values;
        storage->count = index;
    }
    if (!storage->values[index - 1]) {
        const size_t alignment = control->alignment < sizeof(void *) ? sizeof(void *) : control->alignment;
        if (alignment & (alignment - 1))
            abort();
        void *value = _aligned_malloc(control->size ? control->size : 1, alignment);
        if (!value)
            abort();
        if (control->initialValue)
            memcpy(value, control->initialValue, control->size);
        else
            memset(value, 0, control->size);
        storage->values[index - 1] = value;
    }
    return storage->values[index - 1];
}
#endif
