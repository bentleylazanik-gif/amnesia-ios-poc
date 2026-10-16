# Prioritized Port Tasks

Updated: 2026-10-16

| Priority | Task | Acceptance criteria | Dependencies | Status |
|---:|---|---|---|---|
| 1 | Validate XcodeGen Metal-probe exclusion and offscreen probe | Generated project/build logs prove probe is excluded from SDLTouchPoC and included in XCTest; probe checks real Metal readback, clear pixels, invalid/oversized sizes, repeat rendering. | None | **Verified** in Actions `38806244632` (eight XCTest methods passed; app/device SDK builds also passed). |
| 2 | Visible SDL Metal triangle | SDL app uses SDL's Metal renderer and draws geometry through its own drawable; Simulator UI test launches app and inspects screenshot pixels; handle size/lifecycle and cleanup. | SDL3 iOS app | **Ready for CI**: renderer geometry, UI target/scheme, screenshot pixel assertion, lifecycle/resize path, and `.xcresult` upload are locally wired and syntax-checked. XcodeGen/Simulator UI launch remain unverified; no physical iPhone observation. |
| 3 | HPL2 renderer integration seam | Inspect HPL2 `iLowLevelGraphics` and render interfaces; compile a minimal HPL2 Metal-backed clear/draw path without desktop OpenGL/GLEW. | Visible Metal probe; HPL2 interfaces | **Not started**: desktop renderer uses compatibility OpenGL and GL extensions. |
| 4 | Load a genuine HPL2 mesh/material | Load a licensed, user-supplied or otherwise authorized resource; upload vertex/index buffers, texture/material, render a real asset. | Metal backend; resource adapter; permitted asset corpus | **Blocked** on asset corpus and renderer/backend. This source checkout contains no game assets/shader corpus. |
| 5 | Load and render a genuine Amnesia scene | Boot Amnesia, load a real map with camera/world/resources, and show it in app. | HPL2 backend, resource system, engine bootstrap, physics/script/audio decisions, authorized assets | **Not started**. |
| 6 | Physical iPhone 11 Pro validation and signing | Build/sign/install/run and capture diagnostic evidence on the actual device. | Developer signing/provisioning or supported sideload workflow | Earlier blue/red SDL PoC was owner-reported; current renderer changes have not been run on a physical iPhone. |
| 7 | Dependency/engine integration audit | Resolve SDL2-to-SDL3, OpenAL, Newton, AngelScript, Devil, Theora, FBX and platform-path requirements; document legal/source/ABI constraints. | Upstream dependency availability and licensing decisions | **In progress as source audit**; several prebuilt dependencies and game assets are absent from the source checkout. |
