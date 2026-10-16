#ifndef HPL2_METAL_WINDOW_PRESENTER_H
#define HPL2_METAL_WINDOW_PRESENTER_H

#include <SDL3/SDL_video.h>
#include <stdbool.h>
#include <stddef.h>

typedef void *HPL2MetalWindowPresenterRef;

#ifdef __cplusplus
extern "C" {
#endif

// Creates an SDL_MetalView for an SDL_WINDOW_METAL window. This presenter owns
// the view, command queue, reusable HPL2-format test mesh and depth target.
HPL2MetalWindowPresenterRef HPL2MetalWindowPresenterCreate(
    SDL_Window *window, char *errorMessage, size_t errorMessageCapacity);

// Encodes the current clear color plus the indexed HPL2-format fixture to the
// drawable. Width/height are physical window pixels, not logical points.
bool HPL2MetalWindowPresenterRender(HPL2MetalWindowPresenterRef presenter,
                                    int width, int height, bool touching,
                                    char *errorMessage,
                                    size_t errorMessageCapacity);

// Must run on the main thread and before SDL_DestroyWindow(window).
void HPL2MetalWindowPresenterDestroy(HPL2MetalWindowPresenterRef presenter);

#ifdef __cplusplus
}
#endif

#endif
