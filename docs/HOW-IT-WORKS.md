# How the port works, and the ten traps

*(Español: [HOW-IT-WORKS.es.md](HOW-IT-WORKS.es.md))*

## The shape of it: two builds, not one

| | What is built | How |
|---|---|---|
| 1 | **The game, as static libraries** | Ninja + clang-cl, as a **desktop** target, with `-DUWP_BUILD=ON` |
| 2 | **The appx** | The `uwp/` project, with the Visual Studio generator — the only genuine `WindowsStore` project |

**What makes the game's code UWP is the `_UWP` macro, not the Store SDK.** That is the single
idea the whole port rests on, and it is also why step 1 cannot use the Visual Studio generator:

- MSBuild only ships the `v143` toolset for "Application Type = UWP", never `ClangCL`, so
  `-T ClangCL` together with `WindowsStore` gives **`error MSB8020`**;
- and with `cl.exe` the ecosystem falls over, because it is written for clang: `-Wno-*` flags in
  ultramodern and recompinput, and `C4146` treated as an error inside rabbitizer.

worleydl's forks do exactly this: their `CMakeSettings.json` asks for the Ninja generator and the
`clang_cl_x64` environment, and the `.lib` paths in their `uwp/CMakeLists.txt` carry no
configuration subfolder — which is Ninja's signature and not the Visual Studio generator's.

The wrapper's `main.cpp` is a `WinMain` that calls `SDL_WinRTRunApp`, which creates the
`CoreWindow` the system demands, and from there enters the game through `marioparty2_uwp_main()`.

## What had to change in the game

| File | Change |
|---|---|
| `CMakeLists.txt` | The `UWP_BUILD` option: defines `_UWP`, turns the executable into a static library, and leaves out what belongs to the `.exe` alone (link flags, the `app.rc` icon, linking against desktop SDL2, and copying the DLLs) |
| `src/main/main.cpp` | Under `_UWP`, `main()` becomes `marioparty2_uwp_main()` and is exported with `extern "C"` |
| `src/main/main.cpp` | `SDL_INIT_HAPTIC` out, under the same condition the project already had for the web build |
| `uwp/` (new) | `main.cpp`, `CMakeLists.txt`, `Package.appxmanifest`, `Assets/` and `patches/` |

The first three are applied by [`tools/parche_uwp_build.py`](../tools/parche_uwp_build.py), which
looks for exact anchors and does nothing if the change is already in. The fourth is the wrapper
project, which this repository does **not** carry: it derives from worleydl's, and his is where
it should be taken from.

## The libraries: this family is one commit away from worleydl's

This is what made the port a one-evening job rather than a month. Mario Party pins the commits
worleydl's web forks were cut against, give or take one:

| Library | Mario Party pins | Against worleydl's patches |
|---|---|---|
| `rt64` | `5473732` | **one commit** behind; the UWP patches apply with `--3way` |
| `plume` (inside rt64) | `d890ac8` | the `worleydl/plume-uwp` fork (`46171c8`) is **three commits** ahead and contains its whole base |
| `N64ModernRuntime` | `cdf5abb` | 2 conflicts, both of the "keep both sides" kind |
| `RecompFrontend` | `b2c5c18` | **no conflicts at all** |

All three games in the family pin **the same four commits**, which is why a tree patched once can
be replicated to the other two by copying the changed files.

### The four conflicts, and why they are all the same

The "ours" side carries the project's web support (`__EMSCRIPTEN__` blocks) that worleydl did not
have; the "theirs" side carries the platform change. **You have to keep both**, with worleydl's
side conditioned on `_UWP`, so that the same tree still builds for the desktop too — which is the
first thing the recipe needs, because without the PC path there is nowhere to compare a graphics
fault against. [`tools/resolver_conflictos.py`](../tools/resolver_conflictos.py) does it:

| File | What is done |
|---|---|
| `rt64_application.cpp` | The `#include "hle/rt64_uwp_mods.h"` under `#ifdef _UWP`; `showing_inspector` stays global, because both paths use it |
| `rt64_application_window.cpp` | ⚠ worleydl left a **`#if 0`** where an `#ifdef` belonged, and that kills the desktop path (`undefined symbol: uwp_GetRefreshRate`). It becomes `#ifndef _UWP` |
| `addresses.hpp` | Three branches: `mem_size` on Emscripten, **512 MB** on UWP (worleydl trimmed it because 4K with 4x MSAA does not fit) and 4 GB on the desktop |
| `recomp.cpp` | `uwp_ProcessEvents()` — its declaration and its call in the UI loop — under `#ifdef _UWP` |

### What is brought in from the Rush 2 port, and what is left out

**Left out:** the list of **seven precompiled shaders** worleydl submits at startup
(`desc_multitexture`, `desc_mountain`, `desc_ice`…). They are **Donkey Kong 64's**: the materials
his ubershader leaves black in *his* game. They are no good for another game and do not scale;
leaving them in breaks the build (`use of undeclared identifier 'desc_multitexture'`), so the
block comes out whole.

**Brought in**, because they are the cause of that and the two findings that made the previous
port in this family playable:

- **Emulated culling in the ubershader** (`src/shaders/RasterPS.hlsl`). On the Xbox,
  `SV_IsFrontFace` arrives with the opposite winding to what the rasteriser does with
  `CULL_MODE_FRONT`, so the ubershader discards **exactly the faces you can see** and every
  description with `culling = 1` comes out black until its specialised shader exists. Since that
  pipeline is already created with `culling = false` and is only used *while* the specialised one
  compiles, the cheap fix is to discard nothing.
  ⚠ **The shader blob is the same for every platform and does not get `_UWP` on its own**: it has
  to be added to `DXC_COMMON_OPTS` in rt64's `CMakeLists.txt` when `UWP_BUILD` is on, or the
  `#ifdef` never reaches the HLSL.
- **The mipmap addressing modes** (`src/hle/rt64_state.cpp`). If any level differs from level 0,
  RT64 drops the native sampler and generates a shader with branches, which on the console costs
  **~200 s to compile** against 0.3 s. And in the RDP it is normal for the high levels to come in
  CLAMP while the low ones are WRAP. Taking level 0's mode for all of them took the previous
  port's startup from 298–322 s down to 40 s, with an identical picture.

## The ten traps

**1. `patches/` needs a clang with a MIPS backend.** Neither Visual Studio 2022's `clang-cl`
(19.1.5) nor a stock clang 22 toolchain carries it. MSYS2's CLANG64 `clang.exe` (22.1.8) does
(`mips`, 32-bit big endian).

**2. ⚠⚠ But the linker must NOT be MSYS2's.** `patches/Makefile` passes `-nostdlib` in its
`LDFLAGS`, and **LLD 22 no longer accepts it**:

```text
lld: error: unknown argument: -nostdlib
lld: error: unknown argument: -T
lld: error: unknown argument: --unresolved-symbols=ignore-all
```

The three errors come out together and point you at "the linker is in COFF mode", which is not
the case (`ld.lld --version` says "compatible with GNU linkers"). **LLD 19 does accept it**, and
an ELF linker understands MIPS wherever the object came from. So: `PATCHES_C_COMPILER` from
MSYS2, `PATCHES_LD` from an LLVM 19.

**3. ⚠⚠ `vcvars64.bat` rebuilds `PATH` and drops Windows' git.** If you then append MSYS2 — for
`make`, which the patches' Makefile needs — the first `git` found is `C:\msys64\usr\bin\git.exe`,
which answers in **Unix paths** (`/f/...`). With that, `git rev-parse --path-format=absolute
--git-path` points somewhere else, `N64Recomp-browser`'s `apply.cmake` **cannot find its patch
stamp**, decides the patch is not applied, and the configure dies in a three-way merge it cannot
do. The fix is one line: put `C:\Program Files\Git\cmd` explicitly in front.

**4. ⚠⚠ The web patches' stamp goes stale as soon as the port touches the same files.**
`apply.cmake` recognises its patch is already in by two routes: the patch **reversing** cleanly
(`git apply --reverse --check`), or a **stamp** — the patch's SHA1 plus the SHA1 of the
checkout's `git diff HEAD` — matching what it saved. The UWP patch touches the same files, so the
first route stops working; and the build itself writes into `lib/rt64`, so the stamp stops
matching too. Then it tries to apply the patch again and fails:

```text
error: src/render/rt64_prebuilt_shaders.h: does not exist in index
```

because its three-way merge builds the index with `git add -u`, which **only includes already
tracked files**, and the web patch *creates* files. The way out is to **re-stamp before every
configure** ([`tools/sellar.cmake`](../tools/sellar.cmake), which repeats the calculation
`apply.cmake` does when it finishes applying a patch). The web patch is still applied; all that
changed is that there is more on top of it.

⚠ And it is not only the `pc` and `libs` steps: **`tools/recompile.sh` configures N64Recomp with
the same CMake** and runs the same `apply.cmake`, so it dies the same way. Re-stamp there too.

**5. `git apply --3way` wants the state in the index** ("does not match index"): you have to
`git -C lib/<n> add -A` first… and `git -C lib/<n> reset` afterwards, or you break trap 4. Two
halves of the same trap.

**6. A duplicate symbol between the patch and the game.** The UWP patch defines
`osPfsIsPlug_recomp` in `librecomp/src/pak.cpp` saying there is a Controller Pak in port 1, and
Mario Party already has its own in `src/game/libultra.cpp` saying the opposite (no Controller
Pak, matching the runtime's own `osPfsInitPak`). Both together break the link
(`lld-link: error: duplicate symbol`). **The game's wins.**

**7. ⚠ `AddVectoredExceptionHandler` is not declared for UWP.** The function exists for app
containers, but the SDK headers only declare it for the desktop partition, and MSBuild stops with
`error C3861: identifier not found`. Declare it by hand with `__declspec(dllimport)` in the
wrapper's `main.cpp`.

**8. ⚠⚠ The game asks for `SDL_INIT_HAPTIC` and WinRT's SDL does not have it.** The classic
stumble of this family, and here it comes with a name:

```text
Failed to initialize SDL2: SDL not built with haptic (force feedback) support
Exiting with exit status '1'. Function exit_error, at file ...\src\main\main.cpp:67
```

`SDL_Init` returns **-1 for the whole set** if a single subsystem fails, so the game never even
creates its window. The good part: the project already handles this **for the web build**
(`#ifdef __EMSCRIPTEN__`, with the comment *"Emscripten's SDL2 is built without haptics, and
asking for them there fails the whole call"*), so adding `|| defined(_UWP)` to that condition is
the whole fix. The wrapper also brings the subsystems up one at a time before entering.

**9. ⚠⚠ Portable mode does NOT work in the container, and worleydl's patch does not fix it
either.** `get_app_folder_path()` looks for `portable.txt` in the **working directory**, and the
game changes that directory to the install folder the moment it does not find `assets/` where it
started (`src/main/main.cpp`) — and that folder is **read-only**. Down the other road,
`FOLDERID_LocalAppData` returns `…\AC\<id>`, which the Device Portal **does not expose**: there
would be no way to upload the ROM. The answer is for the frontend to use **LocalFolder**, which
is what the portal calls `LocalState`.

⚠ And you cannot ask SDL from in there: the game's libraries are compiled against **desktop
SDL2** (its CMakeLists' `FetchContent`), whose headers declare neither `SDL_WinRTGetFSPathUTF8`
nor `SDL_WINRT_PATH_LOCAL_FOLDER` — WinRT's SDL only enters when the appx is linked. The path
travels through a global the wrapper writes before entering the game.

⚠⚠ **That global is not in any of worleydl's patches, and forgetting it costs a whole build.**
It is defined in RecompFrontend's `recompui/src/util/file.cpp`, and `get_app_folder_path` has to
return it before it looks at `portable.txt`. Nothing complains until the very last step, when the
appx links:

```text
main.obj : error LNK2019: unresolved external symbol recompui_uwp_data_path
```

[`tools/parche_data_path.py`](../tools/parche_data_path.py) does it, and `compilar.ps1` calls it
at the end of the `parches` step.

**10. To test with nobody in front of the console you need two switches, and both are FILES** in
`LocalState` — they go up or come down in seconds, with no recompiling and no reinstalling:

| File | What it does |
|---|---|
| `autoarranque.txt` | The wrapper adds `--boot` to the game's arguments, which is the project's own development switch: it enters the ROM on the launcher's first frame, with nobody pressing "Start Game" |
| `fps.txt` | The FPS counter starts switched on, which on a console is the only way to see it without a controller in hand to press **R3** |

⚠ `fps.txt` **is looked for in the data folder, not the working directory**, precisely because of
trap 9: by the time the counter looks, the game has already moved to the install folder.

## What was NOT the port's fault

Worth recording, because it saves the next person from chasing the wrong thing:

- The **gamma** fault that the third game in this family had — everything flat looking washed out
  and blown — was the **game project's**, not the port's: the game switches the N64's gamma
  correction off at boot and that call was not reaching the recompiled code, so every frame went
  through the console's curve. Reported upstream and fixed the same day. **Mario Party 1 and 2
  never had it**: their symbol files name `osViSetSpecialFeatures` correctly, so the call always
  reached the runtime.
- The **black surfaces** in the intro were the ubershader culling, which is a console-side
  difference in `SV_IsFrontFace` — that one *is* the port's, and it is fixed above.
