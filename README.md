# Video HOK

Video HOK (`video-hok`) は、TauriとHTML/CSS/JavaScriptで作られた
Windows向けのシンプルなメディアプレイヤーです。

現在のバージョン: `1.0.0`

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

NSISインストーラー、単体ポータブルEXE、ポータブルZIP、SHA-256ファイルを生成:

```powershell
npm run release:windows
```

既存の`dist`フォルダを検証:

```powershell
npm run verify:release
```

生成されるファイル:

```text
dist\
├─ video-hok-Setup-1.0.0.exe
├─ video-hok-Setup-1.0.0.exe.sha256
├─ video-hok-Portable-1.0.0.exe
├─ video-hok-Portable-1.0.0.exe.sha256
├─ video-hok-Portable-1.0.0.zip
└─ video-hok-Portable-1.0.0.zip.sha256
```

ポータブルZIPの内容:

```text
video-hok-Portable-1.0.0\
├─ video-hok-Portable-1.0.0.exe
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
