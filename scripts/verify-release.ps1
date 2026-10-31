[CmdletBinding()]
param(
    [switch]$AllowUnsigned,
    [string]$ArtifactsDirectory
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "signing.ps1")
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$package = Get-Content -Raw -LiteralPath (Join-Path $root "package.json") | ConvertFrom-Json
$englishName = [string]$package.name
$version = [string]$package.version
$outputDirectory = if ($AllowUnsigned) { "dist-unsigned" } else { "dist" }
$distPath = if ($ArtifactsDirectory) { $ArtifactsDirectory } else { Join-Path $root $outputDirectory }
$expectedThumbprint = if ($AllowUnsigned) { "" } else { Get-ExpectedSigningThumbprint -Required }

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

$setupName = "$englishName-Setup-$version.exe"
$portableName = "$englishName-Portable-$version.exe"
$zipName = "$englishName-Portable-$version.zip"
$artifactNames = @($setupName, $portableName, $zipName)
$expectedFiles = @(
    $setupName,
    "$setupName.sha256",
    $portableName,
    "$portableName.sha256",
    $zipName,
    "$zipName.sha256"
)

if (-not (Test-Path -LiteralPath $distPath -PathType Container)) {
    throw "Release directory not found: $distPath"
}

$actualFiles = @(
    Get-ChildItem -LiteralPath $distPath -File |
        Select-Object -ExpandProperty Name |
        Sort-Object
)
$missingFiles = @($expectedFiles | Where-Object { $_ -notin $actualFiles })
$unexpectedFiles = @($actualFiles | Where-Object { $_ -notin $expectedFiles })
if ($missingFiles.Count -gt 0 -or $unexpectedFiles.Count -gt 0) {
    throw "Release file set mismatch. Missing: $($missingFiles -join ', '); Unexpected: $($unexpectedFiles -join ', ')"
}

$results = foreach ($artifactName in $artifactNames) {
    $artifactPath = Join-Path $distPath $artifactName
    $checksumPath = "$artifactPath.sha256"
    $checksumText = (Get-Content -Raw -LiteralPath $checksumPath).Trim()
    if ($checksumText -notmatch "^([0-9a-fA-F]{64})\s{2}(.+)$") {
        throw "Invalid checksum file format: $checksumPath"
    }

    $expectedHash = $Matches[1].ToLowerInvariant()
    $checksumFileName = $Matches[2]
    if ($checksumFileName -ne $artifactName) {
        throw "Checksum filename mismatch in $checksumPath."
    }

    $actualHash = Get-Sha256 -Path $artifactPath
    if ($actualHash -ne $expectedHash) {
        throw "SHA-256 verification failed for $artifactName."
    }

    $item = Get-Item -LiteralPath $artifactPath
    if ($item.Length -le 0) {
        throw "Artifact is empty: $artifactPath"
    }
    if ($artifactName.EndsWith(".exe")) {
        Assert-ReleaseSignature -Path $artifactPath -ExpectedThumbprint $expectedThumbprint -AllowUnsigned:$AllowUnsigned
    }

    [pscustomobject]@{
        File = $artifactName
        Bytes = $item.Length
        SHA256 = $actualHash
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $distPath $zipName
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $zipRootName = "$englishName-Portable-$version"
    $expectedEntries = @(
        "$zipRootName/$portableName",
        "$zipRootName/README.txt"
    )
    $actualEntries = @(
        $archive.Entries |
            Where-Object { -not [string]::IsNullOrEmpty($_.Name) } |
            ForEach-Object { $_.FullName.Replace("\", "/") } |
            Sort-Object
    )

    $missingEntries = @($expectedEntries | Where-Object { $_ -notin $actualEntries })
    $unexpectedEntries = @($actualEntries | Where-Object { $_ -notin $expectedEntries })
    if ($missingEntries.Count -gt 0 -or $unexpectedEntries.Count -gt 0) {
        throw "Portable ZIP structure mismatch. Missing: $($missingEntries -join ', '); Unexpected: $($unexpectedEntries -join ', ')"
    }
    if ($actualEntries.Count -ne $expectedEntries.Count) {
        throw "Portable ZIP contains duplicate entries."
    }

    # Checking only the outer EXE leaves a substituted EXE inside the ZIP undetected.
    $portableEntry = $archive.Entries |
        Where-Object { $_.FullName.Replace("\", "/") -eq "$zipRootName/$portableName" } |
        Select-Object -First 1
    $portableStream = $portableEntry.Open()
    $zipHashAlgorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $zipExeHash = ([BitConverter]::ToString($zipHashAlgorithm.ComputeHash($portableStream))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $zipHashAlgorithm.Dispose()
        $portableStream.Dispose()
    }
    if ($zipExeHash -ne (Get-Sha256 -Path (Join-Path $distPath $portableName))) {
        throw "The portable EXE in the ZIP does not match the verified standalone EXE."
    }

    $readmeEntry = $archive.Entries |
        Where-Object { $_.FullName.Replace("\", "/") -eq "$zipRootName/README.txt" } |
        Select-Object -First 1
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $reader = [IO.StreamReader]::new($readmeEntry.Open(), $utf8, $true)
    try {
        $readmeText = $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }

    $requiredJapaneseHeadings = @(
        (-join @([char]0x8D77, [char]0x52D5, [char]0x65B9, [char]0x6CD5)),
        (-join @([char]0x79FB, [char]0x52D5, [char]0x65B9, [char]0x6CD5)),
        (-join @([char]0x524A, [char]0x9664, [char]0x65B9, [char]0x6CD5))
    )
    foreach ($requiredText in @(
        $portableName,
        "$englishName-PortableData",
        "WebView2 Runtime"
    ) + $requiredJapaneseHeadings) {
        if (-not $readmeText.Contains($requiredText)) {
            throw "Portable README is missing required text: $requiredText"
        }
    }
    if ($readmeText.Contains("{{")) {
        throw "Portable README contains an unreplaced template token."
    }
}
finally {
    $archive.Dispose()
}

$results | Format-Table -AutoSize
if ($AllowUnsigned) {
    Write-Output "Unsigned local test build verification passed. These artifacts are not signed releases."
} else {
    Write-Output "Signed release verification passed."
}
