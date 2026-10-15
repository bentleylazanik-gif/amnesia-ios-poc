#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <stdbool.h>
#include <stdatomic.h>
#include <stdio.h>

typedef struct AppState {
    SDL_Window *window;
    SDL_Renderer *renderer;
    atomic_bool paused;
    atomic_bool touching;
} AppState;

static AppState app_state;

SDL_AppResult SDLCALL SDL_AppInit(void **appstate, int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    atomic_init(&app_state.paused, false);
    atomic_init(&app_state.touching, false);
    *appstate = &app_state;

    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    app_state.window = SDL_CreateWindow(
        "SDL iOS Touch PoC",
        640,
        480,
        SDL_WINDOW_FULLSCREEN);
    if (app_state.window == NULL) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    app_state.renderer = SDL_CreateRenderer(app_state.window, NULL);
    if (app_state.renderer == NULL) {
        fprintf(stderr, "SDL_CreateRenderer failed: %s\n", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDLCALL SDL_AppEvent(void *state, SDL_Event *event)
{
    AppState *app = (AppState *)state;

    switch (event->type) {
    case SDL_EVENT_QUIT:
    case SDL_EVENT_TERMINATING:
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
    case SDL_EVENT_WILL_ENTER_BACKGROUND:
        atomic_store(&app->paused, true);
        atomic_store(&app->touching, false);
        break;
    case SDL_EVENT_DID_ENTER_FOREGROUND:
        atomic_store(&app->paused, false);
        atomic_store(&app->touching, false);
        break;
    default:
        break;
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDLCALL SDL_AppIterate(void *state)
{
    AppState *app = (AppState *)state;

    if (atomic_load(&app->paused)) {
        return SDL_APP_CONTINUE;
    }

    if (atomic_load(&app->touching)) {
        SDL_SetRenderDrawColor(app->renderer, 232, 88, 66, 255);
    } else {
        SDL_SetRenderDrawColor(app->renderer, 34, 90, 145, 255);
    }

    if (!SDL_RenderClear(app->renderer) || !SDL_RenderPresent(app->renderer)) {
        fprintf(stderr, "Rendering failed: %s\n", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    return SDL_APP_CONTINUE;
}

void SDLCALL SDL_AppQuit(void *state, SDL_AppResult result)
{
    AppState *app = (AppState *)state;
    (void)result;

    if (app != NULL) {
        if (app->renderer != NULL) {
            SDL_DestroyRenderer(app->renderer);
            app->renderer = NULL;
        }
        if (app->window != NULL) {
            SDL_DestroyWindow(app->window);
            app->window = NULL;
        }
    }

    SDL_Quit();
}
