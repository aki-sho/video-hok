# 第三者ソフトウェアについて

Video HOKは、以下の第三者ソフトウェアを使用しているか、
それらを利用してビルドされています。各ソフトウェアの著作権表示と
ライセンス条件は引き続き適用されます。

## Tauri

- 対象: `tauri`, `tauri-build`, `tauri-runtime`, `tauri-utils`, `wry`
- ライセンス: Apache License 2.0 OR MIT License
- プロジェクト: https://github.com/tauri-apps/tauri

## Serde

- 対象: `serde`, `serde_derive`
- ライセンス: Apache License 2.0 OR MIT License
- プロジェクト: https://github.com/serde-rs/serde

## serde_json

- 対象: `serde_json`
- ライセンス: Apache License 2.0 OR MIT License
- プロジェクト: https://github.com/serde-rs/json

## Microsoft Edge WebView2

- 対象: Microsoft Edge WebView2 Runtime
- ライセンス: Microsoftソフトウェアライセンス条項
- プロジェクト: https://developer.microsoft.com/microsoft-edge/webview2/

ポータブルEXEにはWebView2 Runtimeを同梱していません。
インストール版のNSISパッケージは、必要に応じてEvergreen WebView2の
ブートストラッパーをダウンロードできます。

## NSIS

- 対象: Nullsoft Scriptable Install System
- ライセンス: zlib/libpng license
- プロジェクト: https://nsis.sourceforge.io/

## その他のRust依存パッケージ

その他の間接的なRust依存パッケージと正確なバージョンは
`src-tauri/Cargo.lock`に記録されています。パッケージ情報と
ライセンス識別子は、次のコマンドで確認できます。

```powershell
cargo metadata --manifest-path src-tauri/Cargo.toml --format-version 1
```

この文書は情報提供を目的としたものであり、各第三者プロジェクトが
配布するライセンス本文に代わるものではありません。
