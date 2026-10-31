[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSHOME "Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1") -ErrorAction Stop
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$package = Get-Content -Raw -LiteralPath (Join-Path $root "package.json") | ConvertFrom-Json
$testRoot = Join-Path $root ".release-test"
$fixture = Join-Path $testRoot ([Guid]::NewGuid().ToString("N"))
$source = Join-Path $root "dist-unsigned"
$verify = Join-Path $PSScriptRoot "verify-release.ps1"
$portableName = "$($package.name)-Portable-$($package.version).exe"
$zipName = "$($package.name)-Portable-$($package.version).zip"
$originalThumbprint = $env:VIDEO_HOK_SIGNING_THUMBPRINT

function Assert-Fails {
    param([Parameter(Mandatory)][scriptblock]$Action, [Parameter(Mandatory)][string]$Message)
    $failure = $null
    try { & $Action | Out-Null } catch { $failure = $_.Exception.Message }
    if (-not $failure -or $failure -notlike "*$Message*") {
        throw "Expected failure containing '$Message'; received '$failure'."
    }
}

function Update-ZipChecksum {
    $hash = (Get-FileHash -LiteralPath (Join-Path $fixture $zipName) -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $fixture "$zipName.sha256"), "$hash  $zipName`r`n")
}

if (-not (Test-Path -LiteralPath (Join-Path $source $portableName))) {
    throw "Run npm run release:windows:unsigned before testing the release verifier."
}

try {
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    Get-ChildItem -LiteralPath $source -File | Copy-Item -Destination $fixture
    $env:VIDEO_HOK_SIGNING_THUMBPRINT = ""
    & $verify -AllowUnsigned -ArtifactsDirectory $fixture | Out-Null

    # Recomputed hashes must not make an unsigned release acceptable.
    $env:VIDEO_HOK_SIGNING_THUMBPRINT = "A" * 40
    Assert-Fails { & $verify -ArtifactsDirectory $fixture } "Authenticode verification failed"
    $env:VIDEO_HOK_SIGNING_THUMBPRINT = ""

    $portablePath = Join-Path $fixture $portableName
    $stream = [IO.File]::Open($portablePath, [IO.FileMode]::Append)
    try { $stream.WriteByte(0) } finally { $stream.Dispose() }
    Assert-Fails { & $verify -AllowUnsigned -ArtifactsDirectory $fixture } "SHA-256 verification failed"
    Copy-Item -LiteralPath (Join-Path $source $portableName) -Destination $portablePath -Force

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipRoot = "$($package.name)-Portable-$($package.version)"
    $archive = [IO.Compression.ZipFile]::Open((Join-Path $fixture $zipName), [IO.Compression.ZipArchiveMode]::Update)
    try {
        $portableEntry = $archive.Entries |
            Where-Object { $_.FullName.Replace("\", "/") -eq "$zipRoot/$portableName" } |
            Select-Object -First 1
        $portableEntry.Delete()
        $entryStream = $archive.CreateEntry("$zipRoot/$portableName").Open()
        try { $entryStream.WriteByte(0) } finally { $entryStream.Dispose() }
    } finally { $archive.Dispose() }
    Update-ZipChecksum
    Assert-Fails { & $verify -AllowUnsigned -ArtifactsDirectory $fixture } "does not match the verified standalone EXE"

    Copy-Item -LiteralPath (Join-Path $source $zipName) -Destination (Join-Path $fixture $zipName) -Force
    $archive = [IO.Compression.ZipFile]::Open((Join-Path $fixture $zipName), [IO.Compression.ZipArchiveMode]::Update)
    try { $archive.CreateEntry("$zipRoot/README.txt") | Out-Null } finally { $archive.Dispose() }
    Update-ZipChecksum
    Assert-Fails { & $verify -AllowUnsigned -ArtifactsDirectory $fixture } "duplicate entries"

    # Model the trust provider's results to cover certificate-specific rejection paths
    # without creating or installing a trusted certificate on the developer's PC.
    . (Join-Path $PSScriptRoot "signing.ps1")
    function Get-AuthenticodeSignature {
        [CmdletBinding()]
        param([string]$LiteralPath)
        return $script:signatureFixture
    }
    $script:signatureFixture = [pscustomobject]@{
        Status = "Valid"
        SignerCertificate = [pscustomobject]@{ Thumbprint = "B" * 40 }
        TimeStamperCertificate = [pscustomobject]@{ Subject = "Test Timestamp" }
    }
    Assert-Fails { Assert-ReleaseSignature -Path $portablePath -ExpectedThumbprint ("A" * 40) } "Unexpected signing certificate"
    $script:signatureFixture.TimeStamperCertificate = $null
    Assert-Fails { Assert-ReleaseSignature -Path $portablePath } "timestamp is required"
    $script:signatureFixture.Status = "HashMismatch"
    Assert-Fails { Assert-ReleaseSignature -Path $portablePath -AllowUnsigned } "Authenticode verification failed"
    Write-Output "Release security tests passed (valid fixture, unsigned release, hash tampering, ZIP substitution, duplicate entries, wrong signer, missing timestamp, invalid signature)."
}
finally {
    $env:VIDEO_HOK_SIGNING_THUMBPRINT = $originalThumbprint
    if (Test-Path -LiteralPath $fixture) {
        $resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
        $testPrefix = [IO.Path]::GetFullPath($testRoot).TrimEnd("\") + "\"
        if (-not $resolvedFixture.StartsWith($testPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a fixture outside the release test directory."
        }
        Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
    }
}
