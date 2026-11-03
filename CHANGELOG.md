# Changelog

All notable changes to this repository. Dates are `YYYY-MM-DD`.

This file is not translated: it is a historical record that grows with each version, and
translating it would mean two histories that drift apart.

## [1.0.2] — 2026-11-03

### Changed

- **This repository no longer explains itself by pointing at other repositories of this
  catalogue.** Comments and documentation introduced a decision, a trap or a default as "the same
  as in such-and-such other port of ours" — which asked anyone who came here for this game to go
  and read about a different one first. Each of those comparisons carried a fact that reads better
  stated outright, so that is what is written now.

  What is still cited is everything that is **not** ours: the upstream project, the third-party
  forks the recipe is built on, and the files taken from them under their own license.

## [1.0.1] — 2026-11-02

**A gap in the recipe, found by following it on a game it was not written for.** Taking
`n64hub/rush-2049-recomp` to the same console with these tools, everything applied — the same four
conflicts, resolved by the same script — and then the appx refused to link:

```text
main.obj : error LNK2019: unresolved external symbol recompui_uwp_data_path
```

### Added

- **`tools/parche_data_path.py`.** It defines `recompui_uwp_data_path` in RecompFrontend and makes
  `get_app_folder_path` return it before looking at `portable.txt`. That change is **in none of
  worleydl's patches** — it is this recipe's own, and until now it had travelled by copying
  already-patched files rather than as a tool. Anyone starting from a clean checkout would have hit
  the same wall at the very last step.
- `tools/compilar.ps1` calls it at the end of the `parches` step, so the default path just works.

### Changed

- `docs/HOW-IT-WORKS.md` trap 9 and `docs/INSTALL.md`'s symptom table now name the error and the
  tool that fixes it, in both languages. `tools/README.md` lists four tools instead of three.

## [1.0.0] — 2026-11-02

First release. The recipe for taking **Mario Party: Recompiled** to an Xbox Series X in
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

Xbox Series X in Developer Mode, package 0.1.0.4, on 2026-10-31: boots, draws, takes controller
input, validates the ROM from `LocalState` on its own, and runs the intro complete at 1920×1080
and **60 FPS**. Not yet played through with a controller in hand.

### Known not to be covered

- The `uwp/` wrapper project is not here: it derives from worleydl's forks.
- worleydl's `.patch` files are not here either; the recipe applies them from his repositories.
- A Series S has never been tried.
