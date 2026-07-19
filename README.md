# Video HOK

Video HOK (`video-hok`) is a small Windows media player built with Tauri and
HTML/CSS/JavaScript.

Current version: `1.0.0`

## Features

- Plays MP4, WebM, MP3, and WAV files
- Play/pause, seek, volume, mute, playback speed, and fullscreen controls
- Keyboard controls:
  - `Space`: play/pause
  - `Right Arrow`: seek forward 5 seconds
  - `Left Arrow`: seek backward 5 seconds
  - `Up Arrow`: increase volume by 1
  - `Down Arrow`: decrease volume by 1
- Preserves the source video's aspect ratio
- Separate installed and portable data locations

## Data Locations

Installed build:

```text
%APPDATA%\video-hok\
├─ config.json
├─ data\
├─ logs\
├─ cache\
├─ temp\
└─ WebView\
```

Portable build:

```text
<portable EXE folder>\video-hok-PortableData\
├─ config.json
├─ data\
├─ logs\
├─ cache\
├─ temp\
└─ WebView\
```

The installed and portable binaries are compiled as separate runtime modes.
Portable behavior does not depend on the EXE filename.

## Development

Requirements:

- Windows 10 or later
- Rust stable with the MSVC toolchain
- Node.js and npm
- Microsoft Edge WebView2 Runtime

Install dependencies and run:

```powershell
npm install
npm run dev
```

Run in portable development mode:

```powershell
npm run portable:dev
```

## Windows Release

Generate the NSIS installer, standalone portable EXE, portable ZIP, and
SHA-256 files:

```powershell
npm run release:windows
```

Verify an existing `dist` directory:

```powershell
npm run verify:release
```

Release output:

```text
dist\
├─ video-hok-Setup-1.0.0.exe
├─ video-hok-Setup-1.0.0.exe.sha256
├─ video-hok-Portable-1.0.0.exe
├─ video-hok-Portable-1.0.0.exe.sha256
├─ video-hok-Portable-1.0.0.zip
└─ video-hok-Portable-1.0.0.zip.sha256
```

The portable ZIP contains:

```text
video-hok-Portable-1.0.0\
├─ video-hok-Portable-1.0.0.exe
└─ README.txt
```

## Release Publication

The release tag is `v1.0.0`. Release binaries are attached to the GitHub
Release and are not committed to the repository.

Project: https://github.com/aki-sho/video-hok

## License

Copyright (c) 2026 aki-sho. All rights reserved. See [LICENSE](LICENSE).

Third-party software notices are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
