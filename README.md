# Video HOK

> 最新バージョン: 1.0.1（2026-10-31）。ローカルの未公開変更を反映し、ソースと配布物を揃えた同期リリースです。

Video HOK (`video-hok`) は、TauriとHTML/CSS/JavaScriptで作られた
Windows向けのシンプルなメディアプレイヤーです。

現在のバージョン: `1.0.1`

## 主な機能

- MP4、WebM、MP3、WAVファイルの再生
- 再生、一時停止、シーク、音量、ミュート、再生速度、フルスクリーン操作
- キーボード操作
  - `Space`: 再生・一時停止
  - `右矢印`: 5秒進む
  - `左矢印`: 5秒戻る
  - `上矢印`: 音量を1上げる
  - `下矢印`: 音量を1下げる
- 元動画のアスペクト比を維持
- インストール版とポータブル版のデータ保存先を分離

## データの保存場所

インストール版:

```text
%APPDATA%\video-hok\
├─ config.json
├─ data\
├─ logs\
├─ cache\
├─ temp\
└─ WebView\
```

ポータブル版:

```text
<ポータブルEXEのフォルダ>\video-hok-PortableData\
├─ config.json
├─ data\
├─ logs\
├─ cache\
├─ temp\
└─ WebView\
```

インストール版とポータブル版は、別々の動作モードとしてビルドされます。
ポータブル版はEXEのファイル名を変更しても、EXEと同じフォルダにデータを保存します。

## 開発

必要な環境:

- Windows 10以降
- Rust安定版とMSVCツールチェーン
- Node.jsとnpm
- Microsoft Edge WebView2 Runtime

依存パッケージをインストールして起動:

```powershell
npm install
npm run dev
```

ポータブルモードで開発起動:

```powershell
npm run portable:dev
```

## Windows向け配布ファイルの作成

正式配布では、Windows証明書ストアのコード署名証明書とWindows SDKの
SignToolが必要です。証明書の拇印を設定してからビルドしてください。
秘密鍵やパスワードはリポジトリに保存しません。

```powershell
$env:VIDEO_HOK_SIGNING_THUMBPRINT = "証明書の40桁の拇印"
npm run release:windows
```

標準は`Cert:\CurrentUser\My`を使用します。証明書が`LocalMachine`にある場合は
`VIDEO_HOK_SIGNING_STORE=LocalMachine`を指定してください。
SignToolを自動検出できない場合は`VIDEO_HOK_SIGNTOOL_PATH`を指定します。
タイムスタンプはRFC 3161 / SHA-256を使用し、サーバーは
`VIDEO_HOK_TIMESTAMP_URL`で変更できます（標準: `http://timestamp.digicert.com`）。

NSIS内のアプリ、インストーラー、ポータブルEXEに署名します。
ZIPとチェックサムは署名後に生成します。
証明書が未設定の場合は、既存の`dist`を変更する前に停止します。

既存の`dist`フォルダを検証（同じ証明書の拇印を設定）:

```powershell
npm run verify:release
```

SHA-256に加え、信頼されたAuthenticode署名、指定した署名者、タイムスタンプ、
ZIP内と単体配布のポータブルEXEが一致することを検証します。

証明書がない環境でのローカル動作確認用:

```powershell
npm run release:windows:unsigned
npm run verify:release:unsigned
```

未署名の確認用ファイルは`dist-unsigned`へ出力され、正式配布用の`dist`と分離します。
`npm run build`や`npm run portable:build`による単体ビルドも、正式配布の署名検証を
実行しません。正式配布には`release:windows`を使用してください。

セキュリティ改修の検証:

```powershell
cargo test --manifest-path src-tauri/Cargo.toml --locked
npm run test:release
```

`test:release`は`dist-unsigned`の確認用ビルドを使い、未署名の正式配布、
チェックサム不一致、ZIP内EXEの差し替え、重複エントリ、署名者やタイムスタンプの
不備を拒否することを検証します。

生成されるファイル:

```text
dist\
├─ video-hok-Setup-1.0.1.exe
├─ video-hok-Setup-1.0.1.exe.sha256
├─ video-hok-Portable-1.0.1.exe
├─ video-hok-Portable-1.0.1.exe.sha256
├─ video-hok-Portable-1.0.1.zip
└─ video-hok-Portable-1.0.1.zip.sha256
```

ポータブルZIPの内容:

```text
video-hok-Portable-1.0.0\
├─ video-hok-Portable-1.0.1.exe
└─ README.txt
```

## GitHub Release

リリースタグは`v1.0.0`です。配布ファイルはGitHub Releaseに添付し、
Gitリポジトリには直接保存していません。

プロジェクト: https://github.com/aki-sho/video-hok

## ライセンス

Copyright (c) 2026 aki-sho. All rights reserved.
詳細は[LICENSE](LICENSE)を参照してください。

使用している第三者ソフトウェアについては
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)を参照してください。
