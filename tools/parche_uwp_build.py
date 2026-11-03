#!/usr/bin/env python3
"""Anade la opcion UWP_BUILD al CMakeLists del juego y renombra su main() bajo _UWP.

Mismo arreglo que en los forks UWP de worleydl y en el port de Rush 2 de la casa:
  - con -DUWP_BUILD=ON el juego produce BIBLIOTECAS ESTATICAS en vez de un .exe, y define
    _UWP, que es lo que enciende los parches de plataforma (no el SDK de la Store);
  - lo que es solo del ejecutable de escritorio (flags de enlazado, el icono app.rc, el
    enlace con el SDL2 de escritorio y la copia de las DLL) queda fuera;
  - main() pasa a llamarse <juego>_uwp_main() y se exporta, para que uwp\\main.cpp la llame
    despues de que SDL cree la CoreWindow.

Uso:  py -3.13 parche_uwp_build.py <arbol> <objetivo> <prefijo>
      p. ej.  C:\\mp2\\src  MarioParty2Recompiled  marioparty2

El <arbol> es la raiz del checkout del juego, la que tiene CMakeLists.txt y src\\main\\main.cpp.
No hay ninguna ruta por defecto a proposito: el argumento es obligatorio.
"""
import sys
from pathlib import Path


def escribir(p: Path, texto: str) -> None:
    tmp = p.with_suffix(p.suffix + '.tmp')
    tmp.write_text(texto, encoding='utf-8')
    tmp.replace(p)


def parchear_cmake(arbol: Path, objetivo: str) -> bool:
    p = arbol / 'CMakeLists.txt'
    t = p.read_text(encoding='utf-8')
    if 'UWP_BUILD' in t:
        print('  CMakeLists: ya estaba')
        return True

    # 1. La opcion, justo despues del bloque de WIN32 que ya existe al principio.
    ancla = ('# Opt out of constexpr mutex constructor on windows to prevent vcruntime mismatch crashes\n'
             'if (WIN32)\n'
             '    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR")\n'
             'endif()\n')
    if t.count(ancla) != 1:
        print('  ERROR: no encuentro el bloque WIN32 del principio')
        return False
    nuevo = ancla + '''
# Xbox Series / Windows Store: el juego se construye como bibliotecas estaticas y uwp\\ las
# enlaza en el appx (uwp/CMakeLists.txt). Mismo montaje que los forks UWP de worleydl para esta
# familia. Lo que vuelve UWP a este codigo es la macro _UWP, no el SDK de la Store: MSBuild no
# tiene toolset ClangCL para «Application Type = UWP» (solo v143), asi que -T ClangCL da MSB8020,
# y con cl.exe se cae el ecosistema entero, escrito para clang.
option(UWP_BUILD "Solo bibliotecas estaticas; el ejecutable sale del proyecto uwp/." OFF)
if (UWP_BUILD)
    add_compile_definitions(_UWP)
endif()
'''
    t = t.replace(ancla, nuevo)

    # 2. El objetivo: ejecutable en escritorio, biblioteca estatica en UWP.
    ancla = f'add_executable({objetivo})\n'
    if t.count(ancla) != 1:
        print(f'  ERROR: «add_executable({objetivo})» aparece {t.count(ancla)} veces')
        return False
    t = t.replace(ancla, f'''# El ejecutable (una biblioteca estatica en la compilacion UWP: el punto de entrada lo pone uwp/).
if (NOT UWP_BUILD)
    add_executable({objetivo})
else()
    add_library({objetivo} STATIC)
endif()
''')

    # 3. Lo que es solo del ejecutable de escritorio.
    ancla = f'''    add_custom_command(TARGET {objetivo} POST_BUILD'''
    i = t.find(ancla)
    if i < 0:
        print('  ERROR: no encuentro el POST_BUILD de las DLL')
        return False
    fin_marca = f'    target_link_libraries({objetivo} PRIVATE SDL2 Winmm.lib)\n'
    j = t.find(fin_marca, i)
    if j < 0:
        print('  ERROR: no encuentro el target_link_libraries de escritorio')
        return False
    j += len(fin_marca)
    bloque = t[i:j]
    sangrado = '\n'.join(('    ' + l) if l.strip() else l for l in bloque.rstrip('\n').split('\n'))
    t = t[:i] + ('''    # Las DLL, los flags de enlazado, el icono y el SDL2 de escritorio son del .exe, que la
    # compilacion UWP no produce: alli los pone uwp/CMakeLists.txt desde el paquete de worleydl.
    if (NOT UWP_BUILD)
''' + sangrado + '''
    endif()
''') + t[j:]

    escribir(p, t)
    print('  CMakeLists: parcheado')
    return True


def parchear_main(arbol: Path, prefijo: str) -> bool:
    p = arbol / 'src' / 'main' / 'main.cpp'
    t = p.read_text(encoding='utf-8')
    if '_uwp_main' in t:
        print('  main.cpp: ya estaba')
        return True
    ancla = 'int main(int argc, char** argv) {\n'
    if t.count(ancla) != 1:
        print(f'  ERROR: «int main(...)» aparece {t.count(ancla)} veces')
        return False
    t = t.replace(ancla, f'''#ifdef _UWP
// En UWP el ejecutable es el envoltorio de uwp/: es suyo el WinMain, entrega el hilo al modelo
// de aplicacion WinRT de SDL (que crea la CoreWindow) y despues llama a esto.
extern "C" int {prefijo}_uwp_main(int argc, char** argv) {{
#else
int main(int argc, char** argv) {{
#endif
''')
    escribir(p, t)
    print('  main.cpp: parcheado')
    return True


def parchear_sdl(arbol: Path) -> bool:
    """SDL_INIT_HAPTIC fuera en UWP.

    El SDL de WinRT no trae soporte de vibracion y SDL_Init devuelve -1 **para todo el
    conjunto** si falla uno solo de los subsistemas, asi que el juego ni siquiera llega a crear
    la ventana: se queda en su exit_error con «SDL not built with haptic (force feedback)
    support». El propio codigo ya contempla el caso para la pagina web, asi que basta sumar
    _UWP a esa condicion.
    """
    p = arbol / 'src' / 'main' / 'main.cpp'
    t = p.read_text(encoding='utf-8')
    viejo = ('    // Emscripten\'s SDL2 is built without haptics, and asking for them there fails the whole call, gamepads with it.\n'
             '#ifdef __EMSCRIPTEN__\n')
    if 'defined(_UWP)\n    const Uint32 sdl_subsystems' in t or '|| defined(_UWP)' in t:
        print('  SDL_INIT: ya estaba')
        return True
    if t.count(viejo) != 1:
        print(f'  ERROR: el bloque de SDL_INIT aparece {t.count(viejo)} veces')
        return False
    nuevo = ("    // Emscripten's SDL2 is built without haptics, and asking for them there fails the whole call, gamepads with it.\n"
             "    // The same is true of SDL for WinRT (the Xbox package): «SDL not built with haptic (force feedback) support»,\n"
             "    // and SDL_Init returns -1 for the lot, so the window is never created and the game stops at exit_error.\n"
             "#if defined(__EMSCRIPTEN__) || defined(_UWP)\n")
    escribir(p, t.replace(viejo, nuevo))
    print('  SDL_INIT: parcheado')
    return True


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    arbol, objetivo, prefijo = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    ok = parchear_cmake(arbol, objetivo) and parchear_main(arbol, prefijo) and parchear_sdl(arbol)
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
