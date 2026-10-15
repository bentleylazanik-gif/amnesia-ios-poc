#include "EngineHostCore.h"

#define ENGINE_HOST_MAX_FRAME_DELTA_SECONDS 0.25

void EngineHostFrameClockInit(EngineHostFrameClock *clock, uint64_t now_ns)
{
    if (clock == 0) {
        return;
    }

    clock->previous_ticks_ns = now_ns;
    clock->delta_seconds = 0.0;
}

double EngineHostFrameClockAdvance(EngineHostFrameClock *clock,
                                   uint64_t now_ns,
                                   bool suspended)
{
    uint64_t elapsed_ns;

    if (clock == 0) {
        return 0.0;
    }

    if (suspended || now_ns <= clock->previous_ticks_ns) {
        clock->previous_ticks_ns = now_ns;
        clock->delta_seconds = 0.0;
        return clock->delta_seconds;
    }

    elapsed_ns = now_ns - clock->previous_ticks_ns;
    clock->previous_ticks_ns = now_ns;
    clock->delta_seconds = (double)elapsed_ns / 1000000000.0;
    if (clock->delta_seconds > ENGINE_HOST_MAX_FRAME_DELTA_SECONDS) {
        clock->delta_seconds = ENGINE_HOST_MAX_FRAME_DELTA_SECONDS;
    }

    return clock->delta_seconds;
}
