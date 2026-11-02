# Building the port and getting it onto the console

*(Español: [INSTALL.es.md](INSTALL.es.md))*

⚠ **Read "Where this port stands" in the [`README.md`](../README.md) before spending an evening
on this.** The game boots, draws, takes a controller and runs at 60 FPS; it has not been played
through with a controller in hand.

## 0. Where the commands go

In **PowerShell**, the ordinary Windows terminal: **Windows** key, type `powershell`, **Enter**
on *Windows PowerShell*. **No administrator needed** — and for the certificate step, using an
administrator window actively breaks things, because the certificate lands in whichever account
ran the command. **PowerShell 7 is not required**, and the examples carry `-ExecutionPolicy
Bypass` because a stock Windows refuses to run a `.ps1`.

## 1. What you need first

| | What for |
|---|---|
| **Visual Studio 2022** with the C++ tools, the **UWP** component and **C++ Clang tools for Windows** | The MSVC environment (`vcvars64`), **clang-cl**, **Ninja** and the appx |
| **Your ROM** of *Mario Party 2* (USA), SHA-1 `166eda1c05670d337e2c3f15a5db528ae1e5d6e3` | The recompiler translates it to C |
| **MSYS2**, CLANG64 environment | The only clang here with a **MIPS backend**, which `patches/` needs, plus `make` |
| **LLVM 19** (just for `ld.lld.exe`) | ⚠ LLD 22 rejects `-nostdlib`; see trap 2 in [`HOW-IT-WORKS.md`](HOW-IT-WORKS.md) |
| **worleydl's UWP forks and his `uwp-dep` bundle, branch `rt64`** | SDL2 for WinRT, `libuwp`, freetype, dxil and dxcompiler, and the platform patches |
| **Git and Python 3.13** | Cloning, patching and the tools here |
| **An Xbox in Developer Mode** and a self-signed certificate | Installing and signing |
| **About 3 GB of disk** | The tree, its submodules and two builds |

## 2. The recipe

```powershell
powershell -ExecutionPolicy Bypass -File tools\compilar.ps1 -Arbol F:\mp -Rom "C:\roms\mp2.z64"
```

That runs every step in order. Each can be repeated on its own, which is what helps when
something fails halfway:

| `-Paso` | What it does |
|---|---|
| `rom` | Puts the ROM where the project expects it and prints its SHA-1 |
| `recompilar` | `tools/recompile.sh`: translates the ROM's MIPS to C (N64Recomp) and the audio microcode (RSPRecomp) |
| `parches` | The game's own three changes, worleydl's UWP patches, and the four conflict resolutions |
| `pc` | The **desktop** executable. Build it first: without a PC build there is nowhere to compare a graphics fault against |
| `libs` | The game **as static libraries**, with **Ninja and clang-cl** |
| `appx` | The only genuine `WindowsStore` project: links the libraries and produces the `.msix` |

⚠ **The `libs` step cannot use the Visual Studio generator.** The why is the first section of
[`HOW-IT-WORKS.md`](HOW-IT-WORKS.md), and it is the one thing to know before starting.

⚠ **`recompilar` re-stamps the web patches too**, not just `pc` and `libs`. `recompile.sh`
configures N64Recomp with the same CMake and runs the same `apply.cmake`, so without it the step
dies with *«src/tools/shader_specializer/CMakeLists.txt: does not exist in index»*.

## 3. The wrapper project

This repository does **not** carry `uwp/` — it derives from worleydl's and belongs in his
repositories. What it has to contain, and why each piece is there, is written out in
[`HOW-IT-WORKS.md`](HOW-IT-WORKS.md): a `WinMain` that calls `SDL_WinRTRunApp`, the data path
through `LocalFolder`, `AddVectoredExceptionHandler` declared by hand, the subsystems brought up
one at a time, and a log file of its own because the container's `stderr` is a fail-fast.

## 4. Installing it on the console

### Before touching anything: how the console has to be

- **In Developer Mode**, with Dev Home installed.
- **On, and with your profile signed in.** ⚠ With no user signed in the console **will not launch
  apps**.
- **On the same network**, with its address at hand. The Device Portal listens on port **11443**
  over HTTPS and asks for the username and password you set in Dev Home.

Open `https://<ip>:11443`. ⚠ The browser will warn that the certificate is not trusted: it is the
console's own. Go in anyway — in Edge and Chrome, **Advanced** → **Continue to … (unsafe)**; in
Firefox, **Advanced** → **Accept the Risk and Continue**. Then **My games & apps → Add**.

## 5. The ROM and the switches, inside the package

⚠ **`LocalState` does not exist until the first launch.** Upload before that and the portal says
it cannot find the path. So: install, **open the game once**, close it, and only then upload the
ROM with the portal's **File explorer**, named `marioparty2.n64.us.1.0.z64`.

Two optional files in that same folder make testing without a controller possible:
`autoarranque.txt` (boots straight into the ROM) and `fps.txt` (the FPS counter starts on).

## If something goes wrong

| Symptom | Cause |
|---|---|
| `error MSB8020` building the libraries | The Visual Studio generator was used: it has to be Ninja + clang-cl |
| `lld: error: unknown argument: -nostdlib` | `PATCHES_LD` is LLD 22. Point it at an LLVM 19 `ld.lld.exe` |
| `does not exist in index` during a configure | The web patches' stamp went stale: `tools/sellar.cmake` before configuring |
| `does not match index` from `git apply --3way` | `git add -A` in that submodule first — and `git reset` afterwards |
| `lld-link: error: duplicate symbol: osPfsIsPlug_recomp` | The patch's and the game's both defined. Keep the game's |
| `error C3861: AddVectoredExceptionHandler` | Not declared for UWP: declare it by hand in the wrapper |
| The link leaves `uwp_PickMultipleFiles` unresolved | The UWP bundle is from the wrong branch: for this family it is `rt64` |
| Boots with no video and hangs creating the window | `SDL_INIT_HAPTIC`: WinRT's SDL has no haptics and `SDL_Init` fails the whole set |
| No button responds | `SDL_HINT_JOYSTICK_WGI` is missing |
| The portal cannot find the path when uploading the ROM | `LocalState` does not exist until the first launch (§5) |
| The console answers `0x800B0100` | The `.msix` is unsigned (below) |

## Reinstalling: three things that bite

1. **MSBuild leaves the appx unsigned.** Sign it with a self-signed certificate whose **subject
   is exactly the manifest's `Publisher`** — that is what keeps the package family name, so the
   console treats it as an update and keeps `LocalState`:
   `signtool sign /fd SHA256 /sha1 <thumbprint> <msix>`.
2. ⚠ **Installing the same version with different contents is refused**, with
   `-2147009285`: *«the provided package has the same identity as an already-installed package
   but the contents are different»*. Bump the manifest's `Identity Version` first, and anchor
   the regular expression that does it (`\sVersion="…"`), because `MinVersion` contains
   `Version`. Uninstalling also clears it, but that takes `LocalState` and the ROM with it.
3. **A shader cache written by an older build is no good.** Delete `LocalState\shadercache\`;
   the game rebuilds it.
