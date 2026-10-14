// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtCore/qglobal.h>
#undef NDEBUG
#include <cassert>

#if defined(__MINGW32__) && defined(QT_STATIC)
#include <atomic>
#include <cstdint>
#include <new>
#include <thread>
#include <vector>

// Call the compiler ABI explicitly: MinGW GCC can use native TLS for this
// executable even though the prebuilt static Qt objects use emulated TLS.
extern "C" void *__emutls_get_address(void *);
struct Control {
    uintptr_t size, alignment, index;
    void *initialValue;
};
static unsigned initialValue = 17;
static Control initializedControl { sizeof(unsigned), alignof(unsigned), 0, &initialValue };
static Control zeroControl { sizeof(unsigned), alignof(unsigned), 0, nullptr };
static unsigned &initialized()
{
    return *static_cast<unsigned *>(__emutls_get_address(&initializedControl));
}
static unsigned &zeroInitialized()
{
    return *static_cast<unsigned *>(__emutls_get_address(&zeroControl));
}

static std::atomic<unsigned> constructed;
static std::atomic<unsigned> destroyed;

struct alignas(128) Value {
    unsigned value = 42;
    Value() { ++constructed; }
    ~Value()
    {
        // Destructors can read other TLS variables. Their storage must also
        // remain alive until all C++ destructors on this thread have finished.
        assert(value == 99);
        assert(initialized() == 18 && zeroInitialized() == 33);
        ++destroyed;
    }
};
static Control valueControl { sizeof(Value), alignof(Value), 0, nullptr };
static Value &value()
{
    return *static_cast<Value *>(__emutls_get_address(&valueControl));
}
struct Cleanup {
    ~Cleanup() { value().~Value(); }
};

int main()
{
    constexpr unsigned rounds = 8, count = 16;
    for (unsigned round = 0; round < rounds; ++round) {
        std::vector<std::thread> threads;
        for (unsigned i = 0; i < count; ++i) {
            threads.emplace_back([] {
                assert(initialized() == 17 && zeroInitialized() == 0);
                new (&value()) Value;
                thread_local Cleanup cleanup;
                (void)cleanup;
                assert(value().value == 42);
                assert(reinterpret_cast<uintptr_t>(&value()) % alignof(Value) == 0);
                ++initialized();
                zeroInitialized() = 33;
                value().value = 99;
            });
        }
        for (auto& thread : threads)
            thread.join();
        assert(constructed == (round + 1) * count);
        assert(destroyed == constructed);
    }
    return 0;
}
#else
int main() { return 77; }
#endif
