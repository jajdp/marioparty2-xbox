# Aviso

*(English: [NOTICE.md](NOTICE.md))*

## Sin afiliación

Este proyecto no está afiliado, respaldado ni relacionado con **Nintendo** ni **Hudson Soft**,
titulares de los derechos de *Mario Party*; ni con **Microsoft**; ni con los autores de
[N64Recomp](https://github.com/N64Recomp/N64Recomp), [RT64](https://github.com/rt64/rt64),
[N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime),
[RecompFrontend](https://github.com/N64Recomp/RecompFrontend), el proyecto del juego
[`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp) o los forks UWP de
**worleydl**. Aquí no se vende nada ni se pide nada a cambio.

## Lo que aquí no se distribuye

- **Ni ROM, ni datos, ni arte del juego.** La ROM la pones tú; la receta no descarga ninguna y
  este repositorio nunca ha contenido una.
- **Ni código recompilado.** El C que el recompilador saca de la ROM es obra derivada de la ROM
  y se queda en la máquina que lo construyó.
- **Ni ejecutable ni paquete.** Ni `.exe`, ni `.msix`, ni `.appx`.
- **Ni arte.** Los mosaicos del paquete no están aquí, y menos el arte del juego.
- **Ninguno de los parches de worleydl**, ni su paquete de dependencias UWP. La receta los toma
  de sus repositorios.
- **Ni el proyecto envoltorio.** La carpeta `uwp/` que produce el appx deriva de la suya y es en
  sus repositorios donde corresponde.

## Cuánto se cita de obra ajena, y por qué

Las herramientas de `tools/` funcionan buscando **anclas exactas** en los árboles que parchean:
encuentran un texto conocido y ponen otro en su lugar. Esas anclas son líneas de código ajeno, y
la única forma de publicar una herramienta que funcione es publicarlas. Medido línea a línea,
atribuyendo cada una al archivo en el que se encontró:

| Proyecto | Licencia | Líneas citadas | Dónde |
|---|---|---|---|
| [`rt64`](https://github.com/rt64/rt64) | MIT | **27** | `resolver_conflictos.py` — los marcadores de conflicto de `rt64_application.cpp` y `rt64_application_window.cpp` |
| [`N64ModernRuntime`](https://github.com/N64Recomp/N64ModernRuntime) | GPL-3.0 | **22** | `resolver_conflictos.py` — `addresses.hpp` y `recomp.cpp` |
| [`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp) | GPL-3.0 | **16** | `parche_uwp_build.py` — las anclas de `CMakeLists.txt` y `src/main/main.cpp` |
| | | **65 en total** | |

`tools/sellar.cmake` **no cita nada**: repite con sus propias palabras el cálculo que hace el
`apply.cmake` de `N64Recomp-browser`, que es por lo que son diez líneas y no una copia.

Algunas de esas líneas citadas llevan comentarios de **worleydl** (`// DLW: …`), porque son el
lado «theirs» de sus parches dentro de esos dos proyectos. Un fork conserva la licencia del
original, así que las líneas de rt64 son MIT y las de N64ModernRuntime GPL-3.0, y así están
listadas arriba.

Todo lo citado es GPL-3.0 o MIT, y este repositorio es **GPL-3.0** para que las partes GPL-3.0
conserven su licencia. Ver [`LICENSE`](LICENSE).

## El proyecto del juego está escrito por IA

[`n64hub/mario-party-2-recomp`](https://github.com/n64hub/mario-party-2-recomp) dice en su propio
README que lo escriben agentes de IA, dirigidos y probados por una persona. Es la declaración de
sus autores, repetida aquí porque quien siga esta receta debería saber qué está construyendo, no
como juicio sobre ello.

## Contacto

Si tienes derechos sobre algo de lo anterior y quieres que se retire, escribe a
**jajdpmail@gmail.com** y se retira.
