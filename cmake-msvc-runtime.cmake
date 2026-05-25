# Force a single, consistent MSVC C-runtime across the entire native build.
#
# The Perspective C++ engine (perspective-server's cpp/perspective/CMakeLists.txt)
# hardcodes the *static* MSVC runtime on Windows (`/MT`, and
# CMAKE_MSVC_RUNTIME_LIBRARY = MultiThreaded[Debug]). So the whole native tree
# must be static too, or the link fails with LNK2038 mismatches.
#
# Two axes have to agree:
#   1. static vs dynamic  -> everything static (/MT), matching the engine.
#   2. debug vs release   -> everything RELEASE. Rust's MSVC std always links the
#      *release* CRT even in debug builds, so the C++ side must use the release
#      CRT as well. Build with `--release` (a debug C++ build would use /MTd and
#      fail to resolve `_calloc_dbg`). See README.
#
# This file aligns protobuf and Abseil (which otherwise default to mismatched
# runtimes) onto the static CRT. Rust links the static CRT via
# `-C target-feature=+crt-static` (see .cargo/config.toml).
#
# NOTE: a CMake *toolchain* file runs before compiler detection, so `MSVC` /
# CMAKE_<LANG>_COMPILER_ID are NOT defined yet -- do not guard on them. These
# variables are simply ignored by non-MSVC toolchains.
#
# Wired in via `CMAKE_TOOLCHAIN_FILE` (see .cargo/config.toml).
set(CMAKE_POLICY_DEFAULT_CMP0091 NEW)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
    CACHE STRING "Static MSVC runtime for all native targets" FORCE)
set(protobuf_MSVC_STATIC_RUNTIME ON
    CACHE BOOL "Build protobuf against the static CRT" FORCE)
# Abseil's own option defaults OFF (dynamic) and overrides
# CMAKE_MSVC_RUNTIME_LIBRARY -- flip it ON so Abseil links the static CRT too.
set(ABSL_MSVC_STATIC_RUNTIME ON
    CACHE BOOL "Build Abseil against the static CRT" FORCE)
