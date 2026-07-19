[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$packagePath = Join-Path $root "package.json"
$tauriConfigPath = Join-Path $root "src-tauri\tauri.conf.json"
$cargoManifestPath = Join-Path $root "src-tauri\Cargo.toml"
$package = Get-Content -Raw -LiteralPath $packagePath | ConvertFrom-Json
$tauriConfig = Get-Content -Raw -LiteralPath $tauriConfigPath | ConvertFrom-Json

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $algorithm.ComputeHash($stream)
        return ([BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

$englishName = [string]$package.name
$displayName = [string]$package.displayName
$version = [string]$package.version

if ([string]::IsNullOrWhiteSpace($englishName) -or
    [string]::IsNullOrWhiteSpace($displayName) -or
    [string]::IsNullOrWhiteSpace($version)) {
    throw "package.json must define name, displayName, and version."
}

if ($tauriConfig.productName -ne $displayName -or $tauriConfig.version -ne $version) {
    throw "package.json and tauri.conf.json name/version values do not match."
}

$cargoManifest = Get-Content -Raw -LiteralPath $cargoManifestPath
if ($cargoManifest -notmatch "(?m)^version\s*=\s*`"$([regex]::Escape($version))`"$") {
    throw "package.json and Cargo.toml versions do not match."
}

$distPath = Join-Path $root "dist"
if (Test-Path -LiteralPath $distPath) {
    $resolvedDist = (Resolve-Path -LiteralPath $distPath).Path
    $rootPrefix = $root.TrimEnd("\") + "\"
    if (-not $resolvedDist.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a dist directory outside the project root."
    }
    Remove-Item -LiteralPath $resolvedDist -Recurse -Force
}
New-Item -ItemType Directory -Path $distPath | Out-Null

Push-Location $root
try {
    & npm.cmd run build -- --bundles nsis
    if ($LASTEXITCODE -ne 0) {
        throw "Tauri NSIS build failed with exit code $LASTEXITCODE."
    }

    $nsisDirectory = Join-Path $root "src-tauri\target\release\bundle\nsis"
    $installerSource = Get-ChildItem -LiteralPath $nsisDirectory -File -Filter "*.exe" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $installerSource) {
        throw "The NSIS installer was not found in $nsisDirectory."
    }

    $setupName = "$englishName-Setup-$version.exe"
    $portableName = "$englishName-Portable-$version.exe"
    $zipName = "$englishName-Portable-$version.zip"
    $setupPath = Join-Path $distPath $setupName
    $portablePath = Join-Path $distPath $portableName
    $zipPath = Join-Path $distPath $zipName

    Copy-Item -LiteralPath $installerSource.FullName -Destination $setupPath

    & cargo build --manifest-path $cargoManifestPath --release --features portable
    if ($LASTEXITCODE -ne 0) {
        throw "Portable Cargo build failed with exit code $LASTEXITCODE."
    }

    $portableSource = Join-Path $root "src-tauri\target\release\$englishName.exe"
    if (-not (Test-Path -LiteralPath $portableSource)) {
        throw "The portable executable was not found at $portableSource."
    }
    Copy-Item -LiteralPath $portableSource -Destination $portablePath

    $stagePath = Join-Path $root ".release-stage"
    if (Test-Path -LiteralPath $stagePath) {
        $resolvedStage = (Resolve-Path -LiteralPath $stagePath).Path
        $rootPrefix = $root.TrimEnd("\") + "\"
        if (-not $resolvedStage.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a staging directory outside the project root."
        }
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }

    $zipRootName = "$englishName-Portable-$version"
    $zipRootPath = Join-Path $stagePath $zipRootName
    New-Item -ItemType Directory -Path $zipRootPath | Out-Null
    Copy-Item -LiteralPath $portablePath -Destination (Join-Path $zipRootPath $portableName)

    $readmeTemplatePath = Join-Path $root "packaging\README-Portable.txt"
    $portableDataName = "$englishName-PortableData"
    $portableReadme = ([IO.File]::ReadAllText($readmeTemplatePath, [Text.Encoding]::UTF8)).
        Replace("{{VERSION}}", $version).
        Replace("{{PORTABLE_EXE}}", $portableName).
        Replace("{{PORTABLE_DATA}}", $portableDataName)
    [IO.File]::WriteAllText(
        (Join-Path $zipRootPath "README.txt"),
        $portableReadme,
        [Text.UTF8Encoding]::new($false)
    )

    Compress-Archive -LiteralPath $zipRootPath -DestinationPath $zipPath -CompressionLevel Optimal
    Remove-Item -LiteralPath $stagePath -Recurse -Force

    foreach ($artifactPath in @($setupPath, $portablePath, $zipPath)) {
        $artifact = Get-Item -LiteralPath $artifactPath
        $hash = Get-Sha256 -Path $artifact.FullName
        $checksumLine = "$hash  $($artifact.Name)`r`n"
        [IO.File]::WriteAllText(
            "$($artifact.FullName).sha256",
            $checksumLine,
            [Text.UTF8Encoding]::new($false)
        )
    }

    & (Join-Path $PSScriptRoot "verify-release.ps1")
}
finally {
    Pop-Location
}
