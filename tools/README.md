# The four tools, and which one you actually run

**You run one: [`compilar.ps1`](compilar.ps1).** The other three it calls itself, in this order.
They are listed here so you can run one on its own when something fails halfway, and so you can
read what each does before letting it touch your tree.

| # | Tool | When `compilar.ps1` calls it | What it does |
|---|---|---|---|
| 1 | [`parche_uwp_build.py`](parche_uwp_build.py) | step `parches`, first | The three changes the **game itself** needs: the `UWP_BUILD` option in its `CMakeLists.txt`, renaming `main()` to `<prefix>_uwp_main()`, and taking `SDL_INIT_HAPTIC` out under `_UWP` |
| 2 | [`resolver_conflictos.py`](resolver_conflictos.py) | step `parches`, after worleydl's patches | The four conflicts those patches hit on this tree. All four resolve the same way: **keep both sides**, with worleydl's under `#ifdef _UWP` so the tree still builds for the desktop |
| 3 | [`sellar.cmake`](sellar.cmake) | before **every** configure — `recompilar`, `pc` and `libs` | Re-stamps `N64Recomp-browser`'s web patches so the next configure does not try to apply them again and die in a three-way merge |

All three are **idempotent**: run them twice and the second time they say "already there" and
change nothing. All three take the game's tree as an argument and have **no path of their own**
baked in.

## Running one by hand

```powershell
py -3.13 -X utf8 tools\parche_uwp_build.py <tree> MarioParty2Recompiled marioparty
py -3.13 -X utf8 tools\resolver_conflictos.py <tree>
cmake -P tools\sellar.cmake <tree>
```

## Roughly how long each step takes

Measured on a desktop with a recent 8-core CPU and an NVMe disk. Yours will differ, but the
*shape* will not: the recompile and the two builds are where the time goes.

| Step | Time |
|---|---|
| `rom` | seconds |
| `parches` | seconds |
| `recompilar` | a few minutes the first time |
| `pc` | a few minutes the first time, under a minute after a code change |
| `libs` | a few minutes the first time |
| `appx` | about a minute |

The hours are the one-off ones, and they are not in this table: installing Visual Studio with
the UWP workload and the Clang tools, installing MSYS2, and the first `git clone
--recurse-submodules`, which pulls a few GB.

⚠ A rebuild being fast does **not** mean nothing happened — CMake and Ninja only redo what
depends on what changed. The way to check that a recompile really happened is the file count in
`RecompiledFuncs\`.
