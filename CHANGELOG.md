# Changelog

All notable changes to this repository. Dates are `YYYY-MM-DD`.

This file is not translated: it is a historical record that grows with each version, and
translating it would mean two histories that drift apart.

## [1.0.0] — 2026-11-02

First release. The recipe for taking **Mario Party 2: Recompiled** to an Xbox Series X in
Developer Mode, as it was actually done on 2026-10-31.

### Added

- `tools/compilar.ps1` — the whole recipe in six steps (`rom`, `parches`, `recompilar`, `pc`,
  `libs`, `appx`), each repeatable on its own, with the reason for each decision beside it.
- `tools/parche_uwp_build.py` — the three changes the game itself needs, by exact anchors,
  idempotent.
- `tools/resolver_conflictos.py` — the four conflicts worleydl's UWP patches hit on this tree,
  and why all four resolve by keeping both sides.
- `tools/sellar.cmake` — re-stamps `N64Recomp-browser`'s web patches before every configure.
- `docs/HOW-IT-WORKS.md` — the two builds, the library commits this family pins, and the ten
  traps, each with the error it actually produces.
- `docs/INSTALL.md` — requirements, the commands, getting it onto the console, and a symptom
  table.
- `NOTICE.md` — what is not distributed, and the 65 lines of other people's code this repository
  quotes, measured and attributed one by one.
- Spanish versions of the README, the notice and the docs.

### Measured on the console

Xbox Series X in Developer Mode, package 0.1.0.1, on 2026-10-31: boots, draws, takes controller
input, validates the ROM from `LocalState` on its own, and runs the intro complete at 1920×1080
and **60 FPS**. Not yet played through with a controller in hand.

### Known not to be covered

- The `uwp/` wrapper project is not here: it derives from worleydl's forks.
- worleydl's `.patch` files are not here either; the recipe applies them from his repositories.
- A Series S has never been tried.
