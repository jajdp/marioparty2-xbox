# Notice

*(Español: [NOTICE.es.md](NOTICE.es.md))*

## No affiliation

This project is not affiliated with, endorsed by or connected to **Nintendo** or **Hudson Soft**,
the rights holders of *Mario Party*; nor **Microsoft**; nor the authors of
[N64Recomp](https://github.com/N64Recomp/N64Recomp), [RT64](https://github.com/rt64/rt64),
[N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime),
[RecompFrontend](https://github.com/N64Recomp/RecompFrontend), the game project
[`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp) or the UWP forks by
**worleydl**. Nothing here is sold, and nothing here is asked for in return.

## What is not distributed here

- **No ROM, no game data, no game assets.** You bring your own ROM; the recipe never downloads
  one and this repository never contained one.
- **No recompiled code.** The C the recompiler produces from the ROM is a derivative of the ROM
  and stays on the machine that built it.
- **No executable and no package.** No `.exe`, no `.msix`, no `.appx`.
- **No art.** The package's tiles are not in here; the game's own art least of all.
- **None of worleydl's patches**, and none of his UWP dependency bundle. The recipe fetches both
  from his repositories.
- **No wrapper project.** The `uwp/` folder that produces the appx derives from worleydl's and
  belongs in his repositories, not here.

## How much of other people's work is quoted, and why

The tools in `tools/` work by matching **exact anchors** in the trees they patch: they find a
known piece of text and put something in its place. Those anchors are lines of other people's
code, and the only way to publish a working tool is to publish them. Measured line by line,
with the matching lines attributed to the file they were found in:

| Project | License | Lines quoted | Where |
|---|---|---|---|
| [`rt64`](https://github.com/rt64/rt64) | MIT | **27** | `resolver_conflictos.py` — the conflict markers of `rt64_application.cpp` and `rt64_application_window.cpp` |
| [`N64ModernRuntime`](https://github.com/N64Recomp/N64ModernRuntime) | GPL-3.0 | **22** | `resolver_conflictos.py` — `addresses.hpp` and `recomp.cpp` |
| [`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp) | GPL-3.0 | **16** | `parche_uwp_build.py` — the anchors in `CMakeLists.txt` and `src/main/main.cpp` |
| | | **65 in total** | |

`tools/sellar.cmake` quotes **nothing**: it repeats, in its own words, the calculation
`N64Recomp-browser`'s `apply.cmake` performs, which is why it is ten lines instead of a copy.

Some of those quoted lines carry **worleydl**'s comments (`// DLW: …`), because they are the
"theirs" side of his patches inside those two projects. A fork keeps its original's license, so
rt64's lines are MIT and N64ModernRuntime's are GPL-3.0, and they are listed above as such.

Everything quoted is either GPL-3.0 or MIT, and this repository is **GPL-3.0** so that the
GPL-3.0 parts keep their license. See [`LICENSE`](LICENSE).

## The game project is written by AI

[`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp) states in its own
README that it is written by AI agents, directed and play-tested by a person. That is its
authors' statement, repeated here because anyone following this recipe should know what they are
building, not as a judgement of it.

## Contact

If you hold rights in any of the above and want something here taken down, write to
**jajdpmail@gmail.com** and it will be removed.
