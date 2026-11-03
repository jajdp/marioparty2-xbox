# Mario Party 2 on Xbox — the UWP port

How to take **Mario Party 2: Recompiled**
([`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp)) — a static
recompilation built on **N64Recomp + RT64** — to an **Xbox Series X in Developer Mode**.

*(Español: [README.es.md](README.es.md))*

The same recipe builds its two siblings, which share an engine
([`n64hub/mario-party-engine`](https://github.com/n64hub/mario-party-engine)) and pin the same
four library commits: [`marioparty-xbox`](https://github.com/jajdp/marioparty-xbox) and
[`marioparty3-xbox`](https://github.com/jajdp/marioparty3-xbox).

## Which console this was tested on

**An Xbox Series X**, in Developer Mode. Both consoles this was built and tested on are Series X,
so that is the only hardware anything here covers.

**A Series S has never been tried — not once.** It is a different machine: less memory available
to a game and a weaker GPU. This may work on one, it may run slower, or it may not start at all;
nothing here has been measured on it.

## Where this port stands

Built from the game's **v0.2.4**. Measured on an Xbox Series X on 2026-10-31:

| | |
|---|---|
| ✅ Boots, draws and takes controller input | Package «Mario Party 2 Recomp» 0.1.0.1, installed through the Device Portal |
| ✅ **60 FPS**, measured with the game's own counter | The logic runs at 30 Hz and RT64 interpolates; the counter reports presented frames |
| ✅ The launcher comes up | Start Game / Controls / Settings / Mods / Exit |
| ✅ The ROM validates by itself | From `LocalState`, with no dialog: the launcher offers **Start Game** straight away |
| ✅ The opening scene draws **complete**, at 1920×1080 and widescreen, with no black surfaces | The six characters on the stage. That is the ubershader culling fix and the mipmap addressing fix doing their job from the first launch — see [`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md) |
| ⚠ Not yet tested with a controller in hand | Getting to a board and a minigame, and the FPS counter on **R3**, are still untested |

**What is NOT claimed here:** that a whole party runs cleanly end to end. What was measured is the
launch, the intro and the frame rate, by Device Portal screenshot. Anything past that is untested.

## What this repository is

**A recipe, not a product.** There is no ROM, no recompiled code, no executable and no `.msix`
here — and that is deliberate, not an oversight.

| Piece | What it is |
|---|---|
| [`tools/compilar.ps1`](tools/compilar.ps1) | **The whole recipe**, in five steps you can repeat one at a time: ROM, recompile, patch, static libraries, appx. With the *why* of each decision beside it |
| [`tools/parche_uwp_build.py`](tools/parche_uwp_build.py) | The three changes **the game itself** needs: the `UWP_BUILD` option, renaming `main()`, and `SDL_INIT_HAPTIC`. By exact anchors, idempotent |
| [`tools/resolver_conflictos.py`](tools/resolver_conflictos.py) | The four conflicts worleydl's UWP patches hit on this tree, and why all four resolve the same way: **keep both sides** |
| [`tools/sellar.cmake`](tools/sellar.cmake) | Re-stamps the web patches of `N64Recomp-browser` so the next configure does not try to apply them again and die |
| [`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md) | The two builds, and the ten traps that cost real time |
| [`docs/INSTALL.md`](docs/INSTALL.md) | What you need, the five commands, and getting it onto the console |

Unlike most of the ports in this catalogue, **the changes to the game are published here**: the
game is GPL-3.0, so its code can be quoted. What is quoted, how much and from where is measured
in [`NOTICE.md`](NOTICE.md).

## The two things to understand before trying

**1. The Visual Studio generator will NOT do for the game's libraries.** MSBuild only has the
`v143` toolset for "Application Type = UWP", not `ClangCL`, so `-T ClangCL` with `WindowsStore`
gives `error MSB8020`; and with `cl.exe` the whole ecosystem falls over, because it is written
for clang (`-Wno-*` in ultramodern and recompinput, `C4146` as an error in rabbitizer). The right
way is **Ninja + clang-cl**, with the libraries as a **desktop** target: what makes them UWP is
the `_UWP` macro the patches define. The only genuine `WindowsStore` project is the appx one.

**2. The platform work comes from worleydl's forks**, not from here: `rt64-dev` (branch
`uwp-dk64`), `N64ModernRuntime-dev` (`uwp-rebase`), `RecompFrontend-dev` (`uwp-compat`) and the
[`worleydl/uwp-dep`](https://github.com/worleydl/uwp-dep) bundle. ⚠ That bundle **has one branch
per engine**: for this family it is `rt64`, not the commit the Star Fox 64 fork pins, whose
`libuwp` does not export `uwp_PickMultipleFiles` and leaves the link unfinished.

**And the good news, which is what made this port a one-evening job:** Mario Party pins
`rt64` at `5473732`, `N64ModernRuntime` at `cdf5abb` and `RecompFrontend` at `b2c5c18` — within a
commit or two of what worleydl's patches were cut against. Three of the four apply with
`--3way`; the fourth needs no conflict resolution at all.

## The traps

Every one of these came up on the console. They are written out in
[`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md); the short list:

| | What happens |
|---|---|
| 1 | **`patches/` needs a clang with a MIPS backend.** Visual Studio's clang-cl does not have one |
| 2 | ⚠ **But the linker must not be LLD 22**: it no longer accepts `-nostdlib`, which `patches/Makefile` passes. LLD 19 does |
| 3 | ⚠ **`vcvars64.bat` rebuilds `PATH` and drops Windows' git.** MSYS2's git answers in Unix paths, `apply.cmake` cannot find its stamp, and the configure dies in a three-way merge |
| 4 | ⚠ **The web patches' stamp goes stale** the moment the UWP patch touches the same files. Re-stamp before every configure |
| 5 | **`git apply --3way` wants the state in the index**: `add -A` before… and `reset` after, or you break trap 4 |
| 6 | **A duplicate symbol between the patch and the game** (`osPfsIsPlug_recomp`). The game's wins |
| 7 | **`AddVectoredExceptionHandler` is not declared for UWP** — `error C3861`. Declare it by hand |
| 8 | ⚠ **`SDL_INIT_HAPTIC` does not exist in WinRT's SDL**, and `SDL_Init` returns -1 **for the whole set**, so the window is never created |
| 9 | ⚠ **Portable mode is no way around the data folder.** `FOLDERID_LocalAppData` returns a folder the Device Portal does not expose; it has to be `LocalFolder` |
| 10 | **To test with nobody in front of the console** you need two switches, and both are **files** in `LocalState` |

## What it is not

No **ROM**, no recompiled code, no executable, no appx, no game art. Not worleydl's patches
either — they are in his repositories — nor the UWP bundle, nor the `uwp/` wrapper project
itself, which derives from his. What this repository holds is the recipe, the four tools, and the
record of what went wrong.

## Credits and license

**Almost none of what makes this work is ours.** This repository is a recipe that glues together other people's work; without any one of these pieces there would be no port at all.

| What it does | Who made it | License |
|---|---|---|
| **[mario-party-2-recomp](https://github.com/n64hub/mario-party-2-recomp)** — recompiles *Mario Party 2* | **n64hub** | GPL-3.0 |
| **[mario-party-engine](https://github.com/n64hub/mario-party-engine)** — the engine the Mario Party recompilations share | **n64hub** | GPL-3.0 |
| **[uwp-dep](https://github.com/worleydl/uwp-dep)** — Dawn, SDL3, nod and dxcompiler **built for UWP** — the single reason any of this runs on an Xbox | **Daniel Worley** (worleydl) | libuwp: zlib, © 2025 |
| **[N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime)** — the runtime those recompilations run on | the **N64Recomp** project | GPL-3.0 |
| **[RecompFrontend](https://github.com/N64Recomp/RecompFrontend)** — the in-game menus and configuration UI | the **N64Recomp** project | GPL-3.0 |
| **[N64Recomp](https://github.com/N64Recomp/N64Recomp)** — statically recompiles N64 games into native executables | **Mr-Wiseguy** and the N64Recomp project | MIT |
| **[rt64](https://github.com/rt64/rt64)** — the N64 renderer, with its enhancements | the **RT64** project | MIT |
| **[SDL](https://github.com/libsdl-org/SDL)** — window, input and audio | **Sam Lantinga** and the SDL contributors | zlib |

Special mention to **Daniel Worley**: the UWP builds in `uwp-dep` are what make an Xbox port of this possible. We did not build them, we used them.

**The packaging recipe, the tooling and this documentation** are by **Recompilaciones**.


Recipe and tooling by **Recompilaciones**, under the **[GPL-3.0](LICENSE)** — the license of the
game project this recipe patches,
[`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp), and of
[N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime) and
[RecompFrontend](https://github.com/N64Recomp/RecompFrontend), two of whose lines the conflict
resolutions quote. [N64Recomp](https://github.com/N64Recomp/N64Recomp) and
[RT64](https://github.com/rt64/rt64) are MIT. The UWP forks the recipe builds on are
**worleydl**'s.

The game project is **written by AI** and says so itself; it is directed and play-tested by a
person. That is its authors' statement, not a claim made here.

*Mario Party 2* is © Nintendo / Hudson Soft. This project is not affiliated with them, with
Microsoft, or with the authors of N64Recomp, RT64, the game project or the UWP forks. Rights
holders: **jajdpmail@gmail.com**.
