// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.
//
// Test-only libmpv interposer. Forwards the exact client-API subset
// mpv_audio_kit binds (see lib/src/mpv_bindings.dart) to the real libmpv,
// inserting a configurable sleep in front of the synchronous property /
// command entry points. The libmpv client API is synchronous: every
// set/get/command queues on the core's dispatch and waits for the playloop
// to serve it, so while the playloop is busy (e.g. CoreAudio waking a
// Bluetooth/AirPlay device for seconds during AO init) every one of these
// calls blocks its calling thread for just as long. The sleep models that
// stall deterministically, letting host tests prove which isolate pays it.
//
// Built at test runtime by test/_helpers/slow_core_shim.dart; never shipped.

#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void *real_lib;
static int get_delay_us; // sleep before mpv_get_property / _string
static int set_delay_us; // sleep before sync set-property / command calls

static void *(*real_mpv_create)(void);
static int (*real_mpv_initialize)(void *);
static void (*real_mpv_terminate_destroy)(void *);
static void (*real_mpv_wakeup)(void *);
static int (*real_mpv_set_option_string)(void *, const char *, const char *);
static int (*real_mpv_set_property_string)(void *, const char *, const char *);
static char *(*real_mpv_get_property_string)(void *, const char *);
static int (*real_mpv_get_property)(void *, const char *, int, void *);
static int (*real_mpv_set_property)(void *, const char *, int, void *);
static int (*real_mpv_command)(void *, const char **);
static int (*real_mpv_command_string)(void *, const char *);
static void *(*real_mpv_wait_event)(void *, double);
static int (*real_mpv_observe_property)(void *, uint64_t, const char *, int);
static void (*real_mpv_free)(void *);
static void (*real_mpv_free_node_contents)(void *);
static const char *(*real_mpv_error_string)(int);
static int (*real_mpv_request_log_messages)(void *, const char *);
static int (*real_mpv_hook_add)(void *, uint64_t, const char *, int);
static int (*real_mpv_hook_continue)(void *, uint64_t);
// Async entry points return as soon as the request is queued — no delay:
// they are the calls a stalled playloop CANNOT block, which is the very
// property the tests exercise.
static int (*real_mpv_set_property_async)(void *, uint64_t, const char *, int,
                                          void *);
static int (*real_mpv_get_property_async)(void *, uint64_t, const char *, int);
static int (*real_mpv_command_async)(void *, uint64_t, const char **);

#define RESOLVE(name)                                                        \
  do {                                                                       \
    real_##name = dlsym(real_lib, #name);                                    \
    if (!real_##name) {                                                      \
      fprintf(stderr, "mak_slow_core_shim: missing symbol %s\n", #name);     \
      abort();                                                               \
    }                                                                        \
  } while (0)

// Called once from the test (via FFI on the shim's own handle) BEFORE any
// Player is created. dlopen of the same shim path in other isolates maps
// the same image, so this configuration is process-wide.
void mak_shim_configure(const char *real_path, int get_us, int set_us) {
  if (!real_lib) {
    real_lib = dlopen(real_path, RTLD_NOW | RTLD_LOCAL);
    if (!real_lib) {
      fprintf(stderr, "mak_slow_core_shim: dlopen(%s) failed: %s\n",
              real_path, dlerror());
      abort();
    }
    RESOLVE(mpv_create);
    RESOLVE(mpv_initialize);
    RESOLVE(mpv_terminate_destroy);
    RESOLVE(mpv_wakeup);
    RESOLVE(mpv_set_option_string);
    RESOLVE(mpv_set_property_string);
    RESOLVE(mpv_get_property_string);
    RESOLVE(mpv_get_property);
    RESOLVE(mpv_set_property);
    RESOLVE(mpv_command);
    RESOLVE(mpv_command_string);
    RESOLVE(mpv_wait_event);
    RESOLVE(mpv_observe_property);
    RESOLVE(mpv_free);
    RESOLVE(mpv_free_node_contents);
    RESOLVE(mpv_error_string);
    RESOLVE(mpv_request_log_messages);
    RESOLVE(mpv_hook_add);
    RESOLVE(mpv_hook_continue);
    RESOLVE(mpv_set_property_async);
    RESOLVE(mpv_get_property_async);
    RESOLVE(mpv_command_async);
  }
  get_delay_us = get_us;
  set_delay_us = set_us;
}

static void stall(int us) {
  if (us > 0) usleep((useconds_t)us);
}

// Optional read tracing (MAK_SHIM_TRACE=1 in the environment): logs every
// stalled property read with its calling thread, letting a failing test
// attribute a main-isolate gap to the exact read.
#include <pthread.h>
static void trace_get(const char *fn, const char *name) {
  static int trace = -1;
  if (trace < 0) {
    const char *e = getenv("MAK_SHIM_TRACE");
    trace = (e && *e == '1') ? 1 : 0;
  }
  if (trace) {
    fprintf(stderr, "[shim] %s(%s) thread=%p\n", fn, name,
            (void *)pthread_self());
  }
}

void *mpv_create(void) { return real_mpv_create(); }
int mpv_initialize(void *h) { return real_mpv_initialize(h); }
void mpv_terminate_destroy(void *h) { real_mpv_terminate_destroy(h); }
void mpv_wakeup(void *h) { real_mpv_wakeup(h); }

int mpv_set_option_string(void *h, const char *n, const char *v) {
  return real_mpv_set_option_string(h, n, v);
}

int mpv_set_property_string(void *h, const char *n, const char *v) {
  stall(set_delay_us);
  return real_mpv_set_property_string(h, n, v);
}

char *mpv_get_property_string(void *h, const char *n) {
  trace_get("mpv_get_property_string", n);
  stall(get_delay_us);
  return real_mpv_get_property_string(h, n);
}

int mpv_get_property(void *h, const char *n, int fmt, void *out) {
  trace_get("mpv_get_property", n);
  stall(get_delay_us);
  return real_mpv_get_property(h, n, fmt, out);
}

int mpv_set_property(void *h, const char *n, int fmt, void *data) {
  stall(set_delay_us);
  return real_mpv_set_property(h, n, fmt, data);
}

int mpv_command(void *h, const char **args) {
  stall(set_delay_us);
  return real_mpv_command(h, args);
}

int mpv_command_string(void *h, const char *args) {
  stall(set_delay_us);
  return real_mpv_command_string(h, args);
}

void *mpv_wait_event(void *h, double timeout) {
  return real_mpv_wait_event(h, timeout);
}

int mpv_observe_property(void *h, uint64_t ud, const char *n, int fmt) {
  return real_mpv_observe_property(h, ud, n, fmt);
}

void mpv_free(void *p) { real_mpv_free(p); }
void mpv_free_node_contents(void *p) { real_mpv_free_node_contents(p); }
const char *mpv_error_string(int e) { return real_mpv_error_string(e); }

int mpv_request_log_messages(void *h, const char *level) {
  return real_mpv_request_log_messages(h, level);
}

int mpv_hook_add(void *h, uint64_t ud, const char *n, int priority) {
  return real_mpv_hook_add(h, ud, n, priority);
}

int mpv_hook_continue(void *h, uint64_t id) {
  return real_mpv_hook_continue(h, id);
}

int mpv_set_property_async(void *h, uint64_t ud, const char *n, int fmt,
                           void *data) {
  return real_mpv_set_property_async(h, ud, n, fmt, data);
}

int mpv_get_property_async(void *h, uint64_t ud, const char *n, int fmt) {
  return real_mpv_get_property_async(h, ud, n, fmt);
}

int mpv_command_async(void *h, uint64_t ud, const char **args) {
  return real_mpv_command_async(h, ud, args);
}
