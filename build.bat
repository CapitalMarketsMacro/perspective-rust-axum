@echo off
setlocal
REM ===========================================================================
REM  build.bat - one-step build for the Perspective Rust + Axum sample.
REM
REM  Works from a fresh clone on any PC: it uses its own folder as the project
REM  root, so you can double-click it or run it from any terminal / location.
REM
REM  Usage:
REM     build.bat          Build the release binary.
REM     build.bat run      Build, then start the server (http://localhost:3000).
REM ===========================================================================

REM --- Move to the repo root (the folder containing this script) -------------
cd /d "%~dp0"

echo ===========================================================================
echo  Perspective Rust + Axum : build
echo  Project root: %CD%
echo ===========================================================================
echo.

REM --- Prerequisites ---------------------------------------------------------
where cargo >nul 2>&1
if errorlevel 1 ( echo [ERROR] 'cargo' not found. Install Rust from https://rustup.rs & goto :fail )

where cmake >nul 2>&1
if errorlevel 1 ( echo [ERROR] 'cmake' not found. Install CMake and add it to PATH. & goto :fail )

REM Best-effort check for the MSVC C++ toolchain (cargo finds it via vswhere).
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    "%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath >nul 2>&1
    if errorlevel 1 echo [WARN] Visual Studio C++ tools not detected - the build may fail. Install VS with "Desktop development with C++".
) else (
    echo [WARN] vswhere not found - ensure Visual Studio with "Desktop development with C++" is installed.
)

REM --- Build configuration ---------------------------------------------------
REM The Perspective C++ engine links the static MSVC CRT; this toolchain file
REM aligns protobuf/Abseil onto it. Path is relative to this script so it works
REM wherever the repo is cloned. (Also set in .cargo\config.toml; this pins it.)
set "CMAKE_TOOLCHAIN_FILE=%~dp0cmake-msvc-runtime.cmake"

REM Some corporate networks intercept TLS, which breaks cargo's certificate
REM revocation check. Disable it so cargo can reach crates.io. Delete this line
REM if your network does not filter HTTPS.
set "CARGO_HTTP_CHECK_REVOKE=false"

REM --- Vendor the runtime assets (viewer bundles + superstore.arrow) ----------
REM Needed to RUN the server (serve the page + data), not to compile.
where npm >nul 2>&1
if errorlevel 1 (
    echo [WARN] 'npm' not found - skipping asset vendoring. Install Node.js and run
    echo        'npm install' before starting the server.
) else (
    echo === npm install ^(viewer bundles + superstore.arrow^) ===
    call npm install --strict-ssl=false --no-audit --no-fund
    if errorlevel 1 ( echo [ERROR] npm install failed. & goto :fail )
)

REM --- Build (release + _hack; a debug build does NOT link on MSVC) -----------
echo.
echo === cargo build --release --features=_hack ===
echo First build compiles protobuf, Abseil, Arrow and the Perspective engine
echo from source ^(~15-20 min^). Subsequent builds are incremental.
echo.
cargo build --release --features=_hack
if errorlevel 1 ( echo. & echo [ERROR] Build failed - see the output above. & goto :fail )

echo.
echo ===========================================================================
echo  BUILD OK
echo  Binary: %CD%\target\release\rust-axum.exe
echo.
echo  Start the server ^(http://localhost:3000^):
echo      cargo run --release --features=_hack
echo  or re-run this script as:  build.bat run
echo ===========================================================================

if /I "%~1"=="run" (
    echo.
    echo === Starting server ^(Ctrl+C to stop^) ===
    cargo run --release --features=_hack
)

echo.
pause
endlocal
exit /b 0

:fail
echo.
pause
endlocal
exit /b 1
