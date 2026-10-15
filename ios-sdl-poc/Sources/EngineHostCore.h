#ifndef ENGINE_HOST_CORE_H
#define ENGINE_HOST_CORE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EngineHostFrameClock {
    uint64_t previous_ticks_ns;
    double delta_seconds;
} EngineHostFrameClock;

/* Initializes a monotonic frame clock at now_ns. */
void EngineHostFrameClockInit(EngineHostFrameClock *clock, uint64_t now_ns);

/*
 * Advances the clock and returns a clamped delta in seconds. Suspended frames
 * return zero while still updating the clock, preventing a resume-time spike.
 */
double EngineHostFrameClockAdvance(EngineHostFrameClock *clock,
                                   uint64_t now_ns,
                                   bool suspended);

#ifdef __cplusplus
}
#endif

#endif
