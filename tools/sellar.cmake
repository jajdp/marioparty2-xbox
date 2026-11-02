# Vuelve a sellar los parches de N64Recomp-browser despues de que el port UWP toque los mismos
# archivos.
#
# apply.cmake reconoce que su parche ya esta puesto por dos caminos: que el parche salga otra vez
# (`git apply --reverse --check`) o que el sello del checkout coincida con lo que se guardo al
# ponerlo. Cuando encima se aplica otro parche que toca los mismos archivos -- el UWP de worleydl
# --, el primero deja de salir al reves y el sello ya no cuadra, asi que el configure intenta
# ponerlo otra vez y muere: su fusion a tres bandas arma un indice con `git add -u`, que solo
# incluye archivos YA rastreados, y el parche de la web CREA archivos (rt64_prebuilt_shaders.h,
# WebGPU.hlsli, shader_specializer\...), de modo que no estan en ese indice.
#
# Esto reescribe el sello con el estado actual, que es exactamente lo que apply.cmake hace cuando
# termina de aplicar un parche. El parche de la web sigue puesto: lo unico que cambio es que
# encima hay mas.
#
# Uso:  cmake -P sellar.cmake <arbol>

cmake_minimum_required(VERSION 3.16)

set(arbol "${CMAKE_ARGV3}")
if (NOT arbol)
    message(FATAL_ERROR "Uso: cmake -P sellar.cmake <arbol>")
endif()
set(N64RECOMP_BROWSER_PATCHES_DIR "${arbol}/lib/N64Recomp-browser/patches")

function(sellar name dir)
    set(patch "${N64RECOMP_BROWSER_PATCHES_DIR}/${name}.patch")
    get_filename_component(dir "${dir}" ABSOLUTE)
    if (NOT EXISTS "${dir}/.git")
        message(STATUS "  ${name}: no esta, se omite")
        return()
    endif()
    execute_process(COMMAND git rev-parse --show-toplevel WORKING_DIRECTORY "${dir}"
        RESULT_VARIABLE result OUTPUT_VARIABLE top OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    if (NOT result EQUAL 0)
        message(STATUS "  ${name}: no es un checkout de git")
        return()
    endif()
    get_filename_component(top "${top}" REALPATH)
    get_filename_component(real "${dir}" REALPATH)
    file(RELATIVE_PATH sub "${top}" "${real}")

    execute_process(COMMAND git rev-parse --path-format=absolute --git-path "n64recomp-browser-${name}"
        WORKING_DIRECTORY "${top}" OUTPUT_VARIABLE stamp OUTPUT_STRIP_TRAILING_WHITESPACE)
    file(SHA1 "${patch}" patch_hash)
    string(SHA1 patch_hash "${patch_hash} ")
    execute_process(COMMAND git diff HEAD --binary --ignore-submodules=all -- "./${sub}"
        WORKING_DIRECTORY "${top}" OUTPUT_VARIABLE diff)
    string(SHA1 changes "${diff}")
    file(WRITE "${stamp}" "${patch_hash} ${changes}")
    message(STATUS "  ${name}: sellado en ${stamp}")
endfunction()

file(STRINGS "${N64RECOMP_BROWSER_PATCHES_DIR}/patches.txt" rows REGEX "^[^#]")
foreach (row IN LISTS rows)
    string(REGEX REPLACE " +" ";" row "${row}")
    list(GET row 0 name)
    list(GET row 1 path)
    sellar(${name} "${arbol}/lib/${path}")
endforeach()
