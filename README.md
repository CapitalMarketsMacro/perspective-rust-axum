# Perspective Rust + Axum Sample

[![CI](https://github.com/CapitalMarketsMacro/perspective-rust-axum/actions/workflows/ci.yml/badge.svg)](https://github.com/CapitalMarketsMacro/perspective-rust-axum/actions/workflows/ci.yml)

A minimal [Perspective](https://perspective.finos.org/) server built with the
[Axum](https://github.com/tokio-rs/axum) web framework, adapted from the
upstream [`examples/rust-axum`](https://github.com/perspective-dev/perspective/tree/master/examples/rust-axum)
example so that it runs **stand-alone** outside the Perspective monorepo.

The Rust process:

1. Loads the bundled `superstore.arrow` sample dataset from disk and registers
   it with an in-process Perspective `Server` as a table named `my_data_source`.
2. Serves a single-page app (`src/index.html`) over HTTP and exposes the
   Perspective table to the browser over a WebSocket at `/ws`.

The browser loads the `<perspective-viewer>` WebAssembly client, connects to the
WebSocket, opens `my_data_source`, and renders an interactive datagrid / charts UI.

## Prerequisites

- **Rust** 1.85+ (edition 2024 — this project was built with 1.94).
- **Node.js / npm** — used only to vendor the frontend assets and the sample
  Arrow file into `node_modules/` (no JS build step is run).
- A C/C++ toolchain + CMake. The `perspective` crate builds its native C++
  engine (plus protobuf and Apache Arrow) **from source**, so this is required.
  On Windows that means Visual Studio with the "Desktop development with C++"
  workload (provides `cl.exe`); `protoc` does **not** need to be installed (the
  `protobuf-src` build dependency compiles its own).

## Run

```sh
# 1. Vendor the Perspective frontend bundles + sample data into node_modules/
npm install

# 2. Build and run the Axum server (the `_hack` feature enables perspective/axum-ws)
npm start
# equivalently: cargo run --release --features=_hack
```

Then open <http://localhost:3000>. The browser loads `<perspective-viewer>`,
connects to the server over the `/ws` WebSocket, opens the `my_data_source`
table, and renders the interactive datagrid / charts UI.

## Windows / MSVC notes

Building Perspective's native engine on Windows MSVC needs a consistent
C-runtime across protobuf, Abseil, Arrow, the engine, and Rust. This project
already wires that up, but it's worth knowing why:

- **Build in release** (`--release`, which `npm start`/`npm run build` use).
  Rust's MSVC standard library always links the *release* C-runtime, while the
  Perspective engine hardcodes the *static* runtime. A debug build mixes the
  debug and release CRTs and fails to link (`unresolved external _calloc_dbg`).
  Release keeps everything on the static release CRT (`/MT`).
- **`.cargo/config.toml` + `cmake-msvc-runtime.cmake`** force the whole native
  tree onto the static CRT (`+crt-static` for Rust; `CMAKE_MSVC_RUNTIME_LIBRARY`
  / `protobuf_MSVC_STATIC_RUNTIME` / `ABSL_MSVC_STATIC_RUNTIME` for CMake). All
  three are scoped to the MSVC target and are no-ops elsewhere.
- **`build.rs`** links `Ole32`/`Shell32` (Arrow's vendored `date` library uses
  `SHGetKnownFolderPath`/`CoTaskMemFree` to find the tz database) and drops the
  stray dynamic-CRT default lib. Windows-only; no-op on Linux/macOS.
- If your network blocks certificate revocation / CRL/OCSP lookups, set
  `CARGO_HTTP_CHECK_REVOKE=false` for `cargo` and run `npm install
  --strict-ssl=false`.

The first build is slow (it compiles protobuf, Abseil, Arrow and the Perspective
engine from source); subsequent builds are incremental.

## Layout

```
.
├── Cargo.toml                # Rust manifest (faithful to upstream)
├── package.json              # Vendors frontend assets + sample data
├── build.rs                  # Windows-only link fixups (no-op elsewhere)
├── cmake-msvc-runtime.cmake  # Windows-only CRT alignment for the native build
├── .cargo
│   └── config.toml           # Wires in the above + +crt-static on MSVC
├── src
│   ├── main.rs               # Axum HTTP + WebSocket Perspective server (faithful to upstream)
│   └── index.html            # <perspective-viewer> single-page app (faithful to upstream)
└── README.md
```

The server reads the dataset from
`node_modules/superstore-arrow/superstore.arrow` and the browser loads the
viewer/client/plugin bundles from `node_modules/@perspective-dev/*`, so
`npm install` must run before `npm start`.

## Differences from the upstream monorepo example

The `src/main.rs`, `src/index.html`, and `Cargo.toml` are reproduced verbatim.
The rest of the changes make the project self-contained and buildable on
Windows; all build/CRT tweaks are scoped to the MSVC target and are no-ops on
Linux/macOS, so the example still matches upstream there.

`package.json`:

- `superstore-arrow` is pinned to `1.0.0` (which ships `superstore.arrow`)
  instead of the monorepo's `catalog:` workspace reference.
- The `@perspective-dev/client`, `@perspective-dev/viewer`,
  `@perspective-dev/viewer-datagrid`, and `@perspective-dev/viewer-charts`
  packages are declared explicitly (`4.5.0`); upstream relied on these being
  hoisted into the monorepo's shared `node_modules`.
- The `start` script is `cargo run --release --features=_hack`. Upstream forces
  the host target via `--target=$(rustc -vV | sed -n 's|host: ||p')` to override
  a wasm default target set by the monorepo's `.cargo/config.toml`; that override
  is unnecessary (and not cross-platform) here. `--release` is required on
  Windows (see the Windows / MSVC notes above).

Added for the Windows build (no-ops on other platforms):

- `.cargo/config.toml`, `cmake-msvc-runtime.cmake`, and `build.rs` — see the
  Windows / MSVC notes above.

The `_hack` Cargo feature (which enables `perspective/axum-ws`) is kept exactly
as upstream documents it — see the comment in `Cargo.toml`.

## License

Apache-2.0, © the Perspective Authors.
