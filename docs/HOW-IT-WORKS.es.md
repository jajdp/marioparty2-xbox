# Cómo funciona el port, y las diez trampas

*(English: [HOW-IT-WORKS.md](HOW-IT-WORKS.md))*

## La forma: dos compilaciones, no una

| | Qué se construye | Cómo |
|---|---|---|
| 1 | **El juego, como bibliotecas estáticas** | Ninja + clang-cl, como objetivo de **escritorio**, con `-DUWP_BUILD=ON` |
| 2 | **El appx** | El proyecto `uwp/`, con el generador de Visual Studio — el único proyecto `WindowsStore` de verdad |

**Lo que vuelve UWP al código del juego es la macro `_UWP`, no el SDK de la Store.** Esa es la
única idea sobre la que se apoya el port entero, y es también por lo que el paso 1 no puede usar
el generador de Visual Studio:

- MSBuild solo trae el toolset `v143` para «Application Type = UWP», nunca `ClangCL`, así que
  `-T ClangCL` junto con `WindowsStore` da **`error MSB8020`**;
- y con `cl.exe` se cae el ecosistema, que está escrito para clang: flags `-Wno-*` en ultramodern
  y recompinput, y `C4146` tratado como error dentro de rabbitizer.

Los forks de worleydl hacen exactamente esto: su `CMakeSettings.json` pide generador Ninja y
entorno `clang_cl_x64`, y las rutas de `.lib` de su `uwp/CMakeLists.txt` no llevan subcarpeta de
configuración — que es la firma de Ninja y no la del generador de Visual Studio.

El `main.cpp` del envoltorio es un `WinMain` que llama a `SDL_WinRTRunApp`, que crea la
`CoreWindow` que el sistema exige, y desde ahí entra al juego por `marioparty2_uwp_main()`.

## Lo que hubo que cambiar en el juego

| Archivo | Cambio |
|---|---|
| `CMakeLists.txt` | La opción `UWP_BUILD`: define `_UWP`, convierte el ejecutable en biblioteca estática y deja fuera lo que es solo del `.exe` (flags de enlazado, el icono `app.rc`, el enlace con el SDL2 de escritorio y la copia de las DLL) |
| `src/main/main.cpp` | Bajo `_UWP`, `main()` pasa a llamarse `marioparty2_uwp_main()` y se exporta con `extern "C"` |
| `src/main/main.cpp` | Fuera `SDL_INIT_HAPTIC`, bajo la misma condición que el proyecto ya tenía para la compilación web |
| `uwp/` (nuevo) | `main.cpp`, `CMakeLists.txt`, `Package.appxmanifest`, `Assets/` y `patches/` |

Los tres primeros los aplica [`tools/parche_uwp_build.py`](../tools/parche_uwp_build.py), que
busca anclas exactas y no hace nada si el cambio ya está puesto. El cuarto es el proyecto
envoltorio, que este repositorio **no** trae: deriva del de worleydl, y de ahí es de donde hay
que tomarlo.

## Las bibliotecas: esta familia está a un commit de las de worleydl

Esto es lo que convirtió el port en el trabajo de una tarde y no de un mes. Mario Party fija los
commits contra los que están hechos los forks web de worleydl, con uno de diferencia:

| Biblioteca | Mario Party fija | Respecto a los parches de worleydl |
|---|---|---|
| `rt64` | `5473732` | **un commit** por detrás; los parches UWP aplican con `--3way` |
| `plume` (dentro de rt64) | `d890ac8` | el fork `worleydl/plume-uwp` (`46171c8`) está **tres commits** por delante y contiene su base entera |
| `N64ModernRuntime` | `cdf5abb` | 2 conflictos, los dos de «quedarse con ambos lados» |
| `RecompFrontend` | `b2c5c18` | **ni un conflicto** |

Los tres juegos de la familia fijan **los mismos cuatro commits**, que es por lo que un árbol
parcheado una vez se puede replicar a los otros dos copiando los archivos cambiados.

### Los cuatro conflictos, y por qué son todos iguales

El lado «ours» trae el soporte de la página web (bloques `__EMSCRIPTEN__`) que worleydl no tenía;
el lado «theirs» trae el cambio de plataforma. **Hay que quedarse con los dos**, condicionando el
de worleydl a `_UWP` para que el mismo árbol siga compilando también para escritorio — que es lo
primero que pide la receta, porque sin el camino de PC no hay dónde comparar un fallo gráfico.
Lo hace [`tools/resolver_conflictos.py`](../tools/resolver_conflictos.py):

| Archivo | Qué se hace |
|---|---|
| `rt64_application.cpp` | El `#include "hle/rt64_uwp_mods.h"` bajo `#ifdef _UWP`; `showing_inspector` queda global, porque lo usan los dos caminos |
| `rt64_application_window.cpp` | ⚠ worleydl dejó un **`#if 0`** donde debía ir un `#ifdef`, y eso mata el camino de escritorio (`undefined symbol: uwp_GetRefreshRate`). Pasa a `#ifndef _UWP` |
| `addresses.hpp` | Tres ramas: `mem_size` en Emscripten, **512 MB** en UWP (worleydl lo recortó porque 4K con 4x MSAA no cabe) y 4 GB en escritorio |
| `recomp.cpp` | `uwp_ProcessEvents()` —su declaración y su llamada en el bucle de la interfaz— bajo `#ifdef _UWP` |

### Lo que se trae del port de Rush 2, y lo que se deja fuera

**Se deja fuera:** la lista de **siete shaders precompilados** que worleydl envía al arrancar
(`desc_multitexture`, `desc_mountain`, `desc_ice`…). Son de **Donkey Kong 64**: los materiales
que en *su* juego el ubershader deja en negro. No valen para otro juego y no escalan; dejarlos
rompe la compilación (`use of undeclared identifier 'desc_multitexture'`), así que el bloque sale
entero.

**Se trae**, porque son la causa de aquello y los dos hallazgos que hicieron jugable el port
anterior de esta familia:

- **El culling emulado del ubershader** (`src/shaders/RasterPS.hlsl`). En la Xbox,
  `SV_IsFrontFace` llega con la orientación cambiada respecto a lo que hace el rasterizador con
  `CULL_MODE_FRONT`, así que el ubershader descarta **justo las caras que se ven** y toda
  descripción con `culling = 1` sale negra mientras no exista su shader especializado. Como ese
  pipeline ya se crea con `culling = false` y solo se usa *mientras* se compila el especializado,
  lo barato es no descartar nada.
  ⚠ **El blob del shader es el mismo para todas las plataformas y no recibe `_UWP` por su
  cuenta**: hay que añadirlo a `DXC_COMMON_OPTS` en el `CMakeLists.txt` de rt64 cuando
  `UWP_BUILD` está activo, o el `#ifdef` no llega nunca al HLSL.
- **Los modos de direccionamiento del mipmap** (`src/hle/rt64_state.cpp`). Si algún nivel difiere
  del 0, RT64 descarta el sampler nativo y genera un shader con ramas, que en la consola cuesta
  **~200 s de compilación** frente a 0,3 s. Y en el RDP es normal que los niveles altos vengan en
  CLAMP mientras los bajos van en WRAP. Tomando el modo del nivel 0 para todos, el arranque del
  port anterior pasó de 298-322 s a 40 s con la imagen idéntica.

## Las diez trampas

**1. `patches/` necesita un clang con backend MIPS.** Ni el `clang-cl` de Visual Studio 2022
(19.1.5) ni un clang 22 de serie lo traen. El `clang.exe` de CLANG64 de MSYS2 (22.1.8) sí
(`mips`, 32-bit big endian).

**2. ⚠⚠ Pero el enlazador NO puede ser el de MSYS2.** `patches/Makefile` pasa `-nostdlib` en sus
`LDFLAGS`, y **LLD 22 ya no lo acepta**:

```text
lld: error: unknown argument: -nostdlib
lld: error: unknown argument: -T
lld: error: unknown argument: --unresolved-symbols=ignore-all
```

Los tres errores salen juntos y despistan hacia «el enlazador está en modo COFF», que no es el
caso (`ld.lld --version` dice «compatible with GNU linkers»). **LLD 19 sí la acepta**, y un
enlazador ELF entiende MIPS venga de donde venga el objeto. Resumiendo: `PATCHES_C_COMPILER` de
MSYS2 y `PATCHES_LD` de un LLVM 19.

**3. ⚠⚠ `vcvars64.bat` rehace el `PATH` y deja fuera el git de Windows.** Si además se añade
MSYS2 al final —para `make`, que el Makefile de los parches necesita—, el primer `git` que se
encuentra es `C:\msys64\usr\bin\git.exe`, que contesta en **rutas Unix** (`/f/...`). Con eso,
`git rev-parse --path-format=absolute --git-path` apunta a otro sitio, el `apply.cmake` de
`N64Recomp-browser` **no encuentra el sello de su parche**, lo da por no aplicado y el configure
muere en una fusión a tres bandas que no puede hacer. El arreglo es una línea: poner
`C:\Program Files\Git\cmd` explícitamente delante.

**4. ⚠⚠ El sello de los parches de la web caduca en cuanto el port toca los mismos archivos.**
`apply.cmake` reconoce que su parche ya está puesto por dos caminos: que el parche **salga** otra
vez al revés (`git apply --reverse --check`) o que un **sello** —el SHA1 del parche más el SHA1
de `git diff HEAD` del checkout— coincida con el guardado. El parche UWP toca los mismos
archivos, así que el primer camino deja de funcionar; y el propio build escribe en `lib/rt64`,
así que el sello tampoco cuadra. Entonces intenta aplicarlo otra vez y falla:

```text
error: src/render/rt64_prebuilt_shaders.h: does not exist in index
```

porque su fusión a tres bandas arma el índice con `git add -u`, que **solo incluye archivos ya
rastreados**, y el parche de la web *crea* archivos. La salida es **volver a sellar antes de cada
configure** ([`tools/sellar.cmake`](../tools/sellar.cmake), que repite el cálculo que hace
`apply.cmake` al terminar de aplicar un parche). El parche de la web sigue puesto: lo único que
cambió es que encima hay más.

⚠ Y no es solo en los pasos `pc` y `libs`: **`tools/recompile.sh` configura N64Recomp con el
mismo CMake** y corre el mismo `apply.cmake`, así que muere igual. Hay que sellar también ahí.

**5. `git apply --3way` pide el estado en el índice** («does not match index»): hay que hacer
`git -C lib/<n> add -A` antes… y `git -C lib/<n> reset` después, o se rompe la trampa 4. Las dos
mitades de la misma trampa.

**6. Un símbolo duplicado entre el parche y el juego.** El parche UWP define
`osPfsIsPlug_recomp` en `librecomp/src/pak.cpp` diciendo que hay un Controller Pak en el puerto
1, y Mario Party ya trae la suya en `src/game/libultra.cpp` diciendo lo contrario (ningún
Controller Pak, como el `osPfsInitPak` del propio runtime). Las dos juntas rompen el enlace
(`lld-link: error: duplicate symbol`). **Manda la del juego.**

**7. ⚠ `AddVectoredExceptionHandler` no se declara para UWP.** La función existe para los
contenedores de aplicación, pero las cabeceras del SDK solo la declaran para la partición de
escritorio, y MSBuild corta con `error C3861: identifier not found`. Se declara a mano con
`__declspec(dllimport)` en el `main.cpp` del envoltorio.

**8. ⚠⚠ El juego pide `SDL_INIT_HAPTIC` y el SDL de WinRT no lo tiene.** El escollo clásico de la
familia, y aquí sale con nombre y apellidos:

```text
Failed to initialize SDL2: SDL not built with haptic (force feedback) support
Exiting with exit status '1'. Function exit_error, at file ...\src\main\main.cpp:67
```

`SDL_Init` devuelve **-1 para todo el conjunto** si falla uno solo de los subsistemas, así que el
juego no llega ni a crear la ventana. Lo bueno: el propio proyecto ya contempla el caso **para la
compilación web** (`#ifdef __EMSCRIPTEN__`, con el comentario *«Emscripten's SDL2 is built
without haptics, and asking for them there fails the whole call»*), así que añadir
`|| defined(_UWP)` a esa condición es el arreglo entero. El envoltorio levanta además los
subsistemas uno a uno antes de entrar.

**9. ⚠⚠ El modo portátil NO vale en el contenedor, y el parche de worleydl tampoco lo arregla.**
`get_app_folder_path()` mira `portable.txt` en el **directorio de trabajo**, y el juego cambia
ese directorio a la carpeta de instalación en cuanto no encuentra `assets/` donde está
(`src/main/main.cpp`) — y esa carpeta es de **solo lectura**. Por el otro camino,
`FOLDERID_LocalAppData` devuelve `…\AC\<id>`, que el Device Portal **no expone**: la ROM no
habría forma de subirla. La salida es que el frontend use **LocalFolder**, que es lo que el
portal llama `LocalState`.

⚠ Y no se puede preguntar a SDL desde ahí: las bibliotecas del juego se compilan con el **SDL2 de
escritorio** (el `FetchContent` de su CMakeLists), cuyas cabeceras no declaran
`SDL_WinRTGetFSPathUTF8` ni `SDL_WINRT_PATH_LOCAL_FOLDER` — el SDL de WinRT solo entra al enlazar
el appx. La ruta viaja por una variable global que escribe el envoltorio antes de entrar al
juego.

**10. Para probar sin nadie delante de la consola hacen falta dos interruptores, y los dos son
ARCHIVOS** de `LocalState` — se suben o se quitan en segundos, sin recompilar ni reinstalar:

| Archivo | Qué hace |
|---|---|
| `autoarranque.txt` | El envoltorio añade `--boot` a los argumentos del juego, que es el interruptor de desarrollo del propio proyecto: entra a la ROM en el primer fotograma del launcher, sin que nadie pulse «Start Game» |
| `fps.txt` | El contador de FPS arranca encendido, que en una consola es la única forma de verlo sin un mando delante para pulsar **R3** |

⚠ `fps.txt` **se busca en la carpeta de datos, no en el directorio de trabajo**, justo por la
trampa 9: para cuando el contador mira, el juego ya se mudó a la carpeta de instalación.

## Lo que NO fue culpa del port

Conviene dejarlo escrito, porque le ahorra a quien venga perseguir lo que no es:

- El fallo de **gamma** que tuvo el tercer juego de esta familia —todo lo plano pálido y
  quemado— era **del proyecto del juego**, no del port: el juego apaga la corrección de gamma del
  N64 al arrancar y esa llamada no llegaba al código recompilado, así que cada fotograma pasaba
  por la curva de la consola. Reportado aguas arriba y arreglado el mismo día. **Mario Party 1 y
  2 nunca lo tuvieron**: sus archivos de símbolos nombran bien `osViSetSpecialFeatures`, así que
  la llamada siempre llegó al runtime.
- Las **superficies negras** de la intro sí eran del port: el culling del ubershader, que es una
  diferencia de la consola en `SV_IsFrontFace`, y está arreglado más arriba.
