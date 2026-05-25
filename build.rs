// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ Windows-only link fixups for the Perspective C++ engine.                  ┃
// ┃ No-op on Linux/macOS, so the upstream sample's behaviour is unchanged.    ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

fn main() {
    let is_windows = std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows");
    let is_msvc = std::env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc");
    if is_windows {
        // Arrow's vendored `date` library calls SHGetKnownFolderPath (Shell32) and
        // CoTaskMemFree (Ole32) to locate the IANA tz database on Windows. The
        // perspective-server build doesn't emit these system libs, so the final
        // link fails with LNK2019 unresolved externals -- add them here.
        println!("cargo:rustc-link-lib=dylib=Ole32");
        println!("cargo:rustc-link-lib=dylib=Shell32");
    }
    if is_windows && is_msvc {
        // The whole native tree links the static CRT (see cmake-msvc-runtime.cmake).
        // Arrow's bundled zstd/lz4 objects are compiled expecting the dynamic CRT
        // import lib (MSVCRT); the linker already redirects their allocator calls to
        // the static CRT, so drop MSVCRT to silence the LNK4098 conflict cleanly.
        println!("cargo:rustc-link-arg=/NODEFAULTLIB:MSVCRT");
    }
}
