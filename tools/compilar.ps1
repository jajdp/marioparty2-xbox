<#
.SYNOPSIS
    Construye el port UWP (Xbox Series X en modo desarrollador) de Mario Party 2: Recompiled.

.DESCRIPTION
    Dos compilaciones, como en los forks UWP de worleydl para la familia N64Recomp:

      1. el juego con -DUWP_BUILD=ON produce BIBLIOTECAS ESTATICAS en vez de un .exe, con
         Ninja + clang-cl y como objetivo de ESCRITORIO: lo que lo vuelve UWP es la macro _UWP
         que definen los parches, no el SDK de la Store;
      2. uwp\ las enlaza con el paquete SDL2/libuwp/dxc de worleydl y genera el appx, que es el
         unico proyecto WindowsStore de verdad.

    El porque de cada decision, y las diez trampas, en docs\HOW-IT-WORKS.md.

    Cada paso se salta si ya esta hecho, asi que el guion se puede repetir.

.PARAMETER Arbol
    Carpeta de trabajo. OBLIGATORIA: con los submodulos y los dos builds pasa de 3 GB, asi que
    no vive dentro de este repositorio.

.PARAMETER Rom
    Tu ROM de Mario Party (USA), SHA-1 166eda1c05670d337e2c3f15a5db528ae1e5d6e3. OBLIGATORIA.
    Aqui no se distribuye ninguna.

.PARAMETER Version
    Etiqueta del juego que se clona. Se fija a proposito: el proyecto publica casi a diario y
    sin esto el arbol saldria distinto cada vez.

.PARAMETER Msys2
    MSYS2, entorno CLANG64: el unico clang con backend MIPS que hace falta para patches\, y el
    make que pide su Makefile. Trampa 1 de HOW-IT-WORKS.

.PARAMETER Lld19
    ld.lld.exe de un LLVM 19. ⚠ NO vale el de MSYS2 (LLD 22): ya no acepta «-nostdlib», que es
    lo que pasa patches\Makefile. Trampa 2 de HOW-IT-WORKS.

.PARAMETER ParchesUwp
    Carpeta con los .patch UWP de worleydl (rt64-uwp.patch, N64ModernRuntime-uwp.patch,
    RecompFrontend-uwp.patch, plume-uwp.patch). No se distribuyen aqui: estan en sus
    repositorios, y el README dice cuales.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\compilar.ps1 -Arbol C:\mp -Rom C:\roms\mp2.z64
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Arbol,
    [Parameter(Mandatory)][string]$Rom,
    [ValidateSet('todos', 'rom', 'recompilar', 'parches', 'pc', 'libs', 'appx')]
    [string]$Paso = 'todos',
    [string]$Version = 'v0.2.4',
    [string]$Repositorio = 'https://github.com/n64hub/mario-party-2-recomp.git',
    [string]$RomNombre = 'marioparty2.us.z64',
    [string]$Objetivo = 'MarioParty2Recompiled',
    [string]$Prefijo = 'marioparty2',
    [string]$Msys2 = 'C:\msys64',
    [string]$Lld19 = '',
    [string]$ParchesUwp = ''
)

$ErrorActionPreference = 'Stop'
$src = Join-Path $Arbol 'src'
$here = $PSScriptRoot

function Paso([string]$t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Hacer([string]$n) { $Paso -eq 'todos' -or $Paso -eq $n }

# --- el entorno de MSVC, que clang-cl necesita para INCLUDE/LIB del SDK -----------------------
function Import-EntornoVS {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw 'No esta vswhere: instala Visual Studio 2022.' }
    $vs = & $vswhere -latest -products * -property installationPath
    $bat = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path $bat)) { throw "No esta vcvars64.bat en $bat" }
    $llvm = Join-Path $vs 'VC\Tools\Llvm\x64\bin'
    if (-not (Test-Path (Join-Path $llvm 'clang-cl.exe'))) {
        throw 'Falta clang-cl: instala «C++ Clang tools for Windows» en Visual Studio.'
    }
    cmd /c "call `"$bat`" > nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$' -and $matches[1] -ne 'PSModulePath') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
    # clang-cl de VS al frente, y MSYS2 AL FINAL: si fuera al principio, su propio clang-cl
    # (que no es compatible con MSVC) ganaria la busqueda y la build principal se rompe.
    #
    # ⚠ Y el git de Windows ANTES que MSYS2, explicitamente. vcvars64 rehace el PATH entero y
    # deja fuera «C:\Program Files\Git\cmd», asi que el primer git que se encuentra es el de
    # MSYS2, que devuelve las rutas al estilo Unix (/c/...). Con eso, el apply.cmake de
    # N64Recomp-browser no encuentra el sello de su parche, lo da por no aplicado y el configure
    # muere en una fusion a tres bandas que no puede hacer. Trampa 3 de HOW-IT-WORKS.
    $git = 'C:\Program Files\Git\cmd'
    $env:PATH = "$llvm;$git;$env:PATH;$Msys2\usr\bin;$Msys2\clang64\bin"
    Write-Host "  clang-cl: $(Join-Path $llvm 'clang-cl.exe')"
}

# Vuelve a sellar los parches de la web antes de cada configure (trampa 4).
function Sellar {
    $sellar = Join-Path $here 'sellar.cmake'
    if (Test-Path $sellar) { cmake -P $sellar $src 2>&1 | Select-String 'sellado' | Out-Null }
}

# --- 0. el arbol --------------------------------------------------------------------------
if (-not (Test-Path $src)) {
    Paso "Clonando el juego en $Version"
    New-Item -ItemType Directory -Force $Arbol | Out-Null
    git clone --recurse-submodules $Repositorio $src
    git -C $src checkout --quiet $Version
    git -C $src submodule update --init --recursive --quiet
}

# --- 1. la ROM ------------------------------------------------------------------------------
if (Hacer 'rom') {
    Paso 'La ROM'
    if (-not (Test-Path -LiteralPath $Rom)) { throw "No esta la ROM: $Rom" }
    New-Item -ItemType Directory -Force (Join-Path $src 'roms') | Out-Null
    $destino = Join-Path $src "roms\$RomNombre"
    if (-not (Test-Path -LiteralPath $destino)) {
        Copy-Item -LiteralPath $Rom -Destination $destino -Force
    }
    $sha1 = (Get-FileHash -LiteralPath $destino -Algorithm SHA1).Hash.ToLower()
    Write-Host "  $destino"
    Write-Host "  SHA-1 $sha1"
}

# --- 2. los parches -------------------------------------------------------------------------
# Tres cosas, en este orden: lo que necesita el juego mismo, los parches UWP de worleydl sobre
# los submodulos, y la resolucion de los cuatro conflictos que dan.
if (Hacer 'parches') {
    Paso 'Parcheando'

    Write-Host '  el juego (UWP_BUILD, el punto de entrada y SDL_INIT_HAPTIC):'
    py -3.13 -X utf8 (Join-Path $here 'parche_uwp_build.py') $src $Objetivo $Prefijo
    if ($LASTEXITCODE -ne 0) { throw 'parche_uwp_build.py fallo' }

    if ($ParchesUwp) {
        if (-not (Test-Path $ParchesUwp)) { throw "No esta la carpeta de parches: $ParchesUwp" }
        foreach ($n in 'rt64', 'N64ModernRuntime', 'RecompFrontend') {
            $lib = Join-Path $src "lib\$n"
            $parche = Join-Path $ParchesUwp "$n-uwp.patch"
            if (-not (Test-Path $parche)) { Write-Host "  OJO: falta $parche"; continue }
            # --3way pide que el estado este en el indice... y hay que deshacerlo despues, o se
            # rompe el sellado de los parches de la web. Las dos mitades de la trampa 5.
            git -C $lib add -A | Out-Null
            $excluir = if ($n -eq 'rt64') { @('--exclude=src/contrib/plume') } else { @() }
            git -C $lib apply --3way --whitespace=nowarn @excluir $parche
            git -C $lib reset | Out-Null
            Write-Host "  $n : parche UWP aplicado (o ya estaba)"
        }
        Write-Host '  los cuatro conflictos:'
        py -3.13 -X utf8 (Join-Path $here 'resolver_conflictos.py') $src
        if ($LASTEXITCODE -ne 0) { throw 'resolver_conflictos.py fallo' }
    }
    else {
        Write-Host '  OJO: sin -ParchesUwp no se aplican los parches de plataforma.' -ForegroundColor Yellow
        Write-Host '       Estan en los repositorios de worleydl; ver docs\INSTALL.md.' -ForegroundColor Yellow
    }
}

Import-EntornoVS

# --- 3. traducir la ROM a C -----------------------------------------------------------------
if (Hacer 'recompilar') {
    Paso 'Traduciendo el codigo de la ROM (N64Recomp + RSPRecomp)'
    # ⚠ Sellar TAMBIEN aqui, no solo antes de «pc» y «libs»: recompile.sh configura N64Recomp
    # con el mismo CMake y corre el mismo apply.cmake, asi que sin esto muere con
    # «src/tools/shader_specializer/CMakeLists.txt: does not exist in index».
    Sellar
    $bash = 'C:\Program Files\Git\bin\bash.exe'
    if (-not (Test-Path $bash)) { throw "No esta bash de Git for Windows en $bash" }
    # bash -c (no -lc): el perfil de login rehace el PATH y se pierde el entorno de MSVC.
    $srcUnix = $src -replace '\\', '/'
    & $bash -c "cd '$srcUnix' && tools/recompile.sh -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl"
    if ($LASTEXITCODE -ne 0) { throw "recompile.sh fallo con $LASTEXITCODE" }
    $n = (Get-ChildItem (Join-Path $src 'RecompiledFuncs') -File -ErrorAction SilentlyContinue).Count
    Write-Host "  RecompiledFuncs: $n archivos"
}

# Los dos compiladores que pide patches\: MIPS de MSYS2, y el enlazador de LLVM 19 (trampas 1 y 2).
$mipsCC = Join-Path $Msys2 'clang64\bin\clang.exe'
if (-not $Lld19) {
    $cand = Get-ChildItem 'C:\', 'D:\', 'F:\' -Filter 'llvm-19*' -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'bin\ld.lld.exe' } | Where-Object { Test-Path $_ } |
            Select-Object -First 1
    if ($cand) { $Lld19 = $cand }
}
$patchesArgs = @()
if ((Test-Path $mipsCC) -and $Lld19 -and (Test-Path $Lld19)) {
    $patchesArgs = @("-DPATCHES_C_COMPILER=$mipsCC", "-DPATCHES_LD=$Lld19")
}
elseif (Hacer 'pc') {
    Write-Host '  OJO: sin clang de MSYS2 y ld.lld de LLVM 19, patches\ no compila.' -ForegroundColor Yellow
}

# --- 4. el ejecutable de escritorio ---------------------------------------------------------
# Primero el PC: sin el camino de escritorio no hay donde comparar un fallo grafico.
if (Hacer 'pc') {
    Paso 'Compilando para Windows (clang-cl + ninja)'
    Sellar
    $build = Join-Path $Arbol 'build-pc'
    cmake -S $src -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release `
        -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl `
        @patchesArgs -DCMAKE_NINJA_CMCLDEPS_RC=OFF
    if ($LASTEXITCODE -ne 0) { throw 'cmake configure (pc) fallo' }
    ninja -C $build $Objetivo
    if ($LASTEXITCODE -ne 0) { throw 'ninja (pc) fallo' }
    Write-Host "  $build\$Objetivo.exe" -ForegroundColor Green
}

# --- 5. el juego como bibliotecas estaticas -------------------------------------------------
# ⚠ Ninja + clang-cl, NO el generador de Visual Studio: MSBuild solo tiene el toolset v143 para
# «Application Type = UWP», asi que -T ClangCL da MSB8020, y con cl.exe se cae el ecosistema.
if (Hacer 'libs') {
    Paso 'Compilando el juego para UWP (bibliotecas estaticas)'
    Sellar
    $build = Join-Path $Arbol 'build-uwp'
    cmake -S $src -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release -DUWP_BUILD=ON `
        -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl `
        @patchesArgs -DCMAKE_NINJA_CMCLDEPS_RC=OFF
    if ($LASTEXITCODE -ne 0) { throw 'cmake configure (uwp) fallo' }
    ninja -C $build
    if ($LASTEXITCODE -ne 0) { throw 'ninja (uwp) fallo' }
    $libs = (Get-ChildItem -Recurse $build -Filter *.lib).Count
    Write-Host "  $libs bibliotecas estaticas en $build" -ForegroundColor Green
}

# --- 6. el appx ------------------------------------------------------------------------------
if (Hacer 'appx') {
    Paso 'Generando el appx'
    $uwp = Join-Path $src 'uwp'
    if (-not (Test-Path (Join-Path $uwp 'CMakeLists.txt'))) {
        throw "No esta el proyecto envoltorio en $uwp. Deriva del de worleydl; ver docs\INSTALL.md."
    }
    $build = Join-Path $Arbol 'build-appx'
    # ⚠ La ruta se arma ANTES: «-DRECOMP_DIR=(Join-Path …)» lo parte PowerShell en dos
    # argumentos y cmake acaba viendo el directorio como posicional.
    $recompDir = Join-Path $Arbol 'build-uwp'
    cmake -S $uwp -B $build -G 'Visual Studio 17 2022' -A x64 "-DRECOMP_DIR=$recompDir"
    if ($LASTEXITCODE -ne 0) { throw 'cmake configure (appx) fallo' }
    # AppxPackageValidationEnabled=false: MSBuild rechaza imagenes de mas de 204.800 B con
    # APPX3207, que es una regla de la Tienda y no de la consola.
    cmake --build $build --config Release -- /p:AppxPackageValidationEnabled=false
    if ($LASTEXITCODE -ne 0) { throw 'MSBuild (appx) fallo' }
    Get-ChildItem -Recurse $build -Include *.appx, *.msix -ErrorAction SilentlyContinue |
        Select-Object FullName, Length | Format-Table -AutoSize
}

Write-Host "`nListo." -ForegroundColor Green
