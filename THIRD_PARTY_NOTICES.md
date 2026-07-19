# Third-Party Notices

Video HOK includes or is built with third-party software. Copyright notices
and license terms for those components remain in effect.

## Tauri

- Components: `tauri`, `tauri-build`, `tauri-runtime`, `tauri-utils`, `wry`
- License: Apache License 2.0 OR MIT License
- Project: https://github.com/tauri-apps/tauri

## Serde

- Components: `serde`, `serde_derive`
- License: Apache License 2.0 OR MIT License
- Project: https://github.com/serde-rs/serde

## serde_json

- Component: `serde_json`
- License: Apache License 2.0 OR MIT License
- Project: https://github.com/serde-rs/json

## Microsoft Edge WebView2

- Component: Microsoft Edge WebView2 Runtime
- License: Microsoft software license terms
- Project: https://developer.microsoft.com/microsoft-edge/webview2/

The WebView2 Runtime is not bundled with the portable EXE. The installed
NSIS package can download the Evergreen WebView2 bootstrapper when required.

## NSIS

- Component: Nullsoft Scriptable Install System
- License: zlib/libpng license
- Project: https://nsis.sourceforge.io/

## Additional Rust Dependencies

Additional transitive Rust dependencies and their exact versions are locked in
`src-tauri/Cargo.lock`. Their package metadata and license identifiers can be
inspected with:

```powershell
cargo metadata --manifest-path src-tauri/Cargo.toml --format-version 1
```

This notice is informational and does not replace the license text distributed
by each third-party project.
