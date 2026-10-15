#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "EngineHostCore.h"

#include <stdbool.h>
#include <stdatomic.h>

typedef struct AppState {
    SDL_Window *window;
    SDL_Renderer *renderer;
    const char *bundle_resource_root;
    char *writable_data_root;
    int drawable_width;
    int drawable_height;
    EngineHostFrameClock frame_clock;
    atomic_bool paused;
    atomic_bool touching;
    atomic_bool clock_reset_pending;
    atomic_bool terminating;
    bool event_watch_registered;
} AppState;

static AppState app_state;

static bool SDLCALL AppLifecycleEventWatch(void *userdata, SDL_Event *event)
{
    AppState *app = (AppState *)userdata;

    switch (event->type) {
    case SDL_EVENT_WILL_ENTER_BACKGROUND:
    case SDL_EVENT_DID_ENTER_BACKGROUND:
        atomic_store(&app->paused, true);
        atomic_store(&app->touching, false);
        break;
    case SDL_EVENT_WILL_ENTER_FOREGROUND:
        atomic_store(&app->paused, true);
        break;
    case SDL_EVENT_DID_ENTER_FOREGROUND:
        atomic_store(&app->clock_reset_pending, true);
        atomic_store(&app->paused, false);
        atomic_store(&app->touching, false);
        break;
    case SDL_EVENT_TERMINATING:
        atomic_store(&app->terminating, true);
        break;
    default:
        break;
    }

    return true;
}

SDL_AppResult SDLCALL SDL_AppInit(void **appstate, int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    atomic_init(&app_state.paused, false);
    atomic_init(&app_state.touching, false);
    atomic_init(&app_state.clock_reset_pending, false);
    atomic_init(&app_state.terminating, false);
    app_state.event_watch_registered = false;
    *appstate = &app_state;

    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "SDL_Init failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    if (!SDL_AddEventWatch(AppLifecycleEventWatch, &app_state)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_AddEventWatch failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }
    app_state.event_watch_registered = true;

    EngineHostFrameClockInit(&app_state.frame_clock, SDL_GetTicksNS());
    app_state.bundle_resource_root = SDL_GetBasePath();
    app_state.writable_data_root = SDL_GetPrefPath("Amnesia", "The Dark Descent");
    if (app_state.bundle_resource_root == NULL || app_state.writable_data_root == NULL) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Could not resolve app bundle or writable data directory: %s",
                     SDL_GetError());
        return SDL_APP_FAILURE;
    }
    SDL_Log("Bundle resource root: %s", app_state.bundle_resource_root);
    SDL_Log("Writable app data root: %s", app_state.writable_data_root);

    app_state.window = SDL_CreateWindow(
        "SDL iOS Touch PoC",
        640,
        480,
        SDL_WINDOW_FULLSCREEN);
    if (app_state.window == NULL) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_CreateWindow failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    app_state.renderer = SDL_CreateRenderer(app_state.window, NULL);
    if (app_state.renderer == NULL) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_CreateRenderer failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    if (SDL_GetWindowSizeInPixels(app_state.window,
                                  &app_state.drawable_width,
                                  &app_state.drawable_height)) {
        SDL_Log("Initial drawable size: %d x %d pixels",
                app_state.drawable_width, app_state.drawable_height);
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDLCALL SDL_AppEvent(void *state, SDL_Event *event)
{
    AppState *app = (AppState *)state;

    switch (event->type) {
    case SDL_EVENT_QUIT:
        return SDL_APP_SUCCESS;
    case SDL_EVENT_FINGER_DOWN:
    case SDL_EVENT_MOUSE_BUTTON_DOWN:
        atomic_store(&app->touching, true);
        break;
    case SDL_EVENT_FINGER_UP:
    case SDL_EVENT_FINGER_CANCELED:
    case SDL_EVENT_MOUSE_BUTTON_UP:
        atomic_store(&app->touching, false);
        break;
    case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
        if (app->window != NULL &&
            SDL_GetWindowSizeInPixels(app->window,
                                      &app->drawable_width,
                                      &app->drawable_height)) {
            SDL_Log("Drawable size changed: %d x %d pixels",
                    app->drawable_width, app->drawable_height);
        }
        break;
    default:
        break;
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDLCALL SDL_AppIterate(void *state)
{
    AppState *app = (AppState *)state;

    if (atomic_load(&app->terminating)) {
        return SDL_APP_SUCCESS;
    }

    const uint64_t now_ns = SDL_GetTicksNS();
    if (atomic_exchange(&app->clock_reset_pending, false)) {
        EngineHostFrameClockInit(&app->frame_clock, now_ns);
    }

    const bool paused = atomic_load(&app->paused);
    (void)EngineHostFrameClockAdvance(&app->frame_clock, now_ns, paused);
    if (paused) {
        return SDL_APP_CONTINUE;
    }

    if (atomic_load(&app->touching)) {
        SDL_SetRenderDrawColor(app->renderer, 232, 88, 66, 255);
    } else {
        SDL_SetRenderDrawColor(app->renderer, 34, 90, 145, 255);
    }

    if (!SDL_RenderClear(app->renderer) || !SDL_RenderPresent(app->renderer)) {
        SDL_LogError(SDL_LOG_CATEGORY_RENDER,
                     "Rendering failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    return SDL_APP_CONTINUE;
}

void SDLCALL SDL_AppQuit(void *state, SDL_AppResult result)
{
    AppState *app = (AppState *)state;
    (void)result;

    if (app != NULL) {
        if (app->event_watch_registered) {
            SDL_RemoveEventWatch(AppLifecycleEventWatch, app);
            app->event_watch_registered = false;
        }
        if (app->renderer != NULL) {
            SDL_DestroyRenderer(app->renderer);
            app->renderer = NULL;
        }
        if (app->window != NULL) {
            SDL_DestroyWindow(app->window);
            app->window = NULL;
        }
        // SDL owns the cached base path; SDL_GetPrefPath returns an owned buffer.
        app->bundle_resource_root = NULL;
        SDL_free(app->writable_data_root);
        app->writable_data_root = NULL;
    }

    SDL_Quit();
}
