# Construir el port y meterlo en la consola

*(English: [INSTALL.md](INSTALL.md))*

⚠ **Lee «En qué punto está el port» del [`README.es.md`](../README.es.md) antes de dedicarle una
tarde.** El juego arranca, dibuja, responde al mando y va a 60 FPS; no se ha jugado entero con
un mando delante.

## 0. Dónde se escriben las órdenes

En **PowerShell**, la terminal normal de Windows: tecla **Windows**, escribe `powershell`,
**Enter** sobre *Windows PowerShell*. **No hace falta administrador** —y en el paso del
certificado, usarlo estropea las cosas, porque el certificado acaba en la cuenta que ejecutó la
orden—. **PowerShell 7 no es necesario**, y los ejemplos llevan `-ExecutionPolicy Bypass` porque
un Windows recién instalado se niega a ejecutar un `.ps1`.

## 1. Lo que hace falta antes

| | Para qué |
|---|---|
| **Visual Studio 2022** con las herramientas de C++, el componente **UWP** y **C++ Clang tools for Windows** | El entorno de MSVC (`vcvars64`), **clang-cl**, **Ninja** y el appx |
| **Tu ROM** de *Mario Party 2* (USA), SHA-1 `166eda1c05670d337e2c3f15a5db528ae1e5d6e3` | El recompilador la traduce a C |
| **MSYS2**, entorno CLANG64 | El único clang de por aquí con **backend MIPS**, que es lo que necesita `patches/`, más `make` |
| **LLVM 19** (solo por su `ld.lld.exe`) | ⚠ LLD 22 rechaza `-nostdlib`; ver la trampa 2 de [`HOW-IT-WORKS.es.md`](HOW-IT-WORKS.es.md) |
| **Los forks UWP de worleydl y su paquete `uwp-dep`, rama `rt64`** | SDL2 para WinRT, `libuwp`, freetype, dxil y dxcompiler, y los parches de plataforma |
| **Git y Python 3.13** | Clonar, parchear y las herramientas de aquí |
| **Una Xbox en modo desarrollador** y un certificado autofirmado | Instalar y firmar |
| **Unos 3 GB de disco** | El árbol, sus submódulos y dos compilaciones |

## 2. La receta

```powershell
powershell -ExecutionPolicy Bypass -File tools\compilar.ps1 -Arbol F:\mp -Rom "C:\roms\mp2.z64"
```

Eso corre todos los pasos en orden. Cada uno se puede repetir por su cuenta, que es lo que ayuda
cuando algo falla a medias:

| `-Paso` | Qué hace |
|---|---|
| `rom` | Pone la ROM donde el proyecto la espera y escribe su SHA-1 |
| `parches` | Los tres cambios del propio juego, los parches UWP de worleydl y los cuatro conflictos |
| `recompilar` | `tools/recompile.sh`: traduce el MIPS de la ROM a C (N64Recomp) y el microcódigo de audio (RSPRecomp) |
| `pc` | El ejecutable de **escritorio**. Hazlo primero: sin el camino de PC no hay dónde comparar un fallo gráfico |
| `libs` | El juego **como bibliotecas estáticas**, con **Ninja y clang-cl** |
| `appx` | El único proyecto `WindowsStore` de verdad: enlaza las bibliotecas y produce el `.msix` |

⚠ **El paso `libs` no puede usar el generador de Visual Studio.** El porqué es la primera
sección de [`HOW-IT-WORKS.es.md`](HOW-IT-WORKS.es.md), y es lo primero que hay que saber.

⚠ **`recompilar` también vuelve a sellar los parches de la web**, no solo `pc` y `libs`.
`recompile.sh` configura N64Recomp con el mismo CMake y corre el mismo `apply.cmake`, así que
sin eso muere con *«src/tools/shader_specializer/CMakeLists.txt: does not exist in index»*.

## 3. El proyecto envoltorio

Este repositorio **no** trae `uwp/`: deriva del de worleydl y es en sus repositorios donde
corresponde. Lo que tiene que contener, y por qué cada pieza está ahí, está desarrollado en
[`HOW-IT-WORKS.es.md`](HOW-IT-WORKS.es.md): un `WinMain` que llama a `SDL_WinRTRunApp`, la
carpeta de datos por `LocalFolder`, `AddVectoredExceptionHandler` declarado a mano, los
subsistemas levantados de uno en uno, y un archivo de registro propio porque el `stderr` del
contenedor es un *fail-fast*.

## 4. Instalarlo en la consola

### Antes de tocar nada: cómo tiene que estar la consola

- **En modo desarrollador**, con Dev Home instalado.
- **Encendida y con tu perfil con la sesión iniciada.** ⚠ Sin un usuario dentro, la consola
  **no lanza aplicaciones**.
- **En la misma red**, con su dirección a mano. El Device Portal escucha en el puerto **11443**
  por HTTPS y pide el usuario y la contraseña que pusiste en Dev Home.

Abre `https://<ip>:11443`. ⚠ El navegador avisará de que el certificado no es de fiar: es el de
la propia consola. Entra igual —en Edge y Chrome, **Configuración avanzada** → **Continuar a…
(no seguro)**; en Firefox, **Avanzado** → **Aceptar el riesgo y continuar**—. Luego, en **Mis
juegos y aplicaciones → Agregar**, tu paquete.

## 5. La ROM y los interruptores, dentro del paquete

⚠ **`LocalState` no existe hasta el primer arranque.** Si subes algo antes, el portal dice que
no encuentra la ruta. Así que: instala, **abre el juego una vez**, ciérralo, y entonces sube la
ROM con el **Explorador de archivos** del portal, llamada `marioparty2.n64.us.1.0.z64`.

Dos archivos opcionales en esa misma carpeta permiten probar sin mando: `autoarranque.txt`
(entra directo a la ROM) y `fps.txt` (el contador de FPS arranca encendido).

## Si algo sale mal

| Síntoma | Causa |
|---|---|
| `error MSB8020` al compilar las bibliotecas | Se usó el generador de Visual Studio: tiene que ser Ninja + clang-cl |
| `lld: error: unknown argument: -nostdlib` | `PATCHES_LD` es LLD 22. Apúntalo al `ld.lld.exe` de un LLVM 19 |
| `does not exist in index` en un configure | El sello de los parches de la web caducó: `tools/sellar.cmake` antes de configurar |
| `does not match index` al hacer `git apply --3way` | `git add -A` en ese submódulo primero — y `git reset` después |
| `lld-link: error: duplicate symbol: osPfsIsPlug_recomp` | La del parche y la del juego, las dos definidas. Manda la del juego |
| `error C3861: AddVectoredExceptionHandler` | No se declara para UWP: hay que declararla a mano en el envoltorio |
| `LNK2019: unresolved external symbol recompui_uwp_data_path` **al enlazar el appx** | No se corrió `tools/parche_data_path.py`. Es el único cambio que no está en ninguno de los parches de worleydl, y nada se queja hasta el último paso |
| El enlace deja `uwp_PickMultipleFiles` sin resolver | El paquete UWP es de la rama equivocada: para esta familia es `rt64` |
| Arranca sin vídeo y se queda creando la ventana | `SDL_INIT_HAPTIC`: el SDL de WinRT no tiene vibración y `SDL_Init` falla para todo el conjunto |
| Ningún botón responde | Falta `SDL_HINT_JOYSTICK_WGI` |
| El portal no encuentra la ruta al subir la ROM | `LocalState` no existe hasta el primer arranque (§5) |
| La consola responde `0x800B0100` | El `.msix` va sin firmar (abajo) |

## Reinstalar: tres cosas que muerden

1. **MSBuild deja el appx sin firmar.** Fírmalo con un certificado autofirmado cuyo **sujeto sea
   exactamente el `Publisher` del manifiesto** — eso es lo que mantiene el nombre de familia del
   paquete, así que la consola lo trata como actualización y conserva `LocalState`:
   `signtool sign /fd SHA256 /sha1 <huella> <msix>`.
2. ⚠ **Instalar la misma versión con otro contenido se rechaza**, con `-2147009285`: *«the
   provided package has the same identity as an already-installed package but the contents are
   different»*. Sube antes el `Identity Version` del manifiesto, y ancla la expresión regular que
   lo hace (`\sVersion="…"`), porque `MinVersion` contiene `Version`. Desinstalar también lo
   desbloquea, pero se lleva `LocalState` y la ROM con él.
3. **Una caché de shaders escrita por una compilación anterior no sirve.** Borra
   `LocalState\shadercache\`; el juego la rehace.
