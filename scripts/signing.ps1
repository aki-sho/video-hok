# Shared by the release builder, Tauri signing hook, and release verifier.
Set-StrictMode -Version Latest
# npm launched from PowerShell 7 can pass its module path to Windows PowerShell.
# Import this host's built-in module rather than autoloading an incompatible one.
Import-Module (Join-Path $PSHOME "Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1") -ErrorAction Stop

function Get-ExpectedSigningThumbprint {
    param([switch]$Required)

    $thumbprint = ([string]$env:VIDEO_HOK_SIGNING_THUMBPRINT).Replace(" ", "").Trim()
    if ([string]::IsNullOrWhiteSpace($thumbprint) -and -not $Required) {
        return ""
    }
    if ($thumbprint -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Set VIDEO_HOK_SIGNING_THUMBPRINT to the code-signing certificate's 40-digit thumbprint. Use release:windows:unsigned for a local test build."
    }
    return $thumbprint.ToUpperInvariant()
}

function Get-WindowsSigningOptions {
    $thumbprint = Get-ExpectedSigningThumbprint -Required
    $store = [string]$env:VIDEO_HOK_SIGNING_STORE
    if ([string]::IsNullOrWhiteSpace($store)) { $store = "CurrentUser" }
    if ($store -notin @("CurrentUser", "LocalMachine")) {
        throw "VIDEO_HOK_SIGNING_STORE must be CurrentUser or LocalMachine."
    }
    $certificate = Get-Item -LiteralPath "Cert:\$store\My\$thumbprint" -ErrorAction Stop
    if (-not $certificate.HasPrivateKey -or
        $certificate.NotBefore -gt (Get-Date) -or $certificate.NotAfter -le (Get-Date)) {
        throw "The signing certificate must be valid and have an accessible private key."
    }
    $codeSigningOid = "1.3.6.1.5.5.7.3.3"
    $usageOids = @($certificate.Extensions |
        Where-Object { $_.Oid.Value -eq "2.5.29.37" } |
        ForEach-Object { $_.EnhancedKeyUsages } |
        ForEach-Object { $_.Value })
    if ($codeSigningOid -notin $usageOids) {
        throw "The certificate is not a code-signing certificate."
    }

    $signToolPath = [string]$env:VIDEO_HOK_SIGNTOOL_PATH
    if ([string]::IsNullOrWhiteSpace($signToolPath)) {
        $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
        if ($command) {
            $signToolPath = $command.Source
        } else {
            $sdkBin = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
            $sdk = Get-ChildItem -LiteralPath $sdkBin -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' } |
                Sort-Object { [version]$_.Name } -Descending |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "x64\signtool.exe") } |
                Select-Object -First 1
            if ($sdk) { $signToolPath = Join-Path $sdk.FullName "x64\signtool.exe" }
        }
    }
    if ([string]::IsNullOrWhiteSpace($signToolPath) -or
        -not (Test-Path -LiteralPath $signToolPath -PathType Leaf)) {
        throw "Install the Windows SDK signing tools or set VIDEO_HOK_SIGNTOOL_PATH."
    }

    $timestampUrl = [string]$env:VIDEO_HOK_TIMESTAMP_URL
    if ([string]::IsNullOrWhiteSpace($timestampUrl)) { $timestampUrl = "http://timestamp.digicert.com" }
    $timestampUri = $null
    if (-not [Uri]::TryCreate($timestampUrl, [UriKind]::Absolute, [ref]$timestampUri) -or
        $timestampUri.Scheme -notin @("http", "https")) {
        throw "VIDEO_HOK_TIMESTAMP_URL must be an HTTP(S) RFC 3161 timestamp service URL."
    }
    return [pscustomobject]@{
        Thumbprint = $thumbprint
        Store = $store
        SignToolPath = $signToolPath
        TimestampUrl = $timestampUrl
    }
}

function Assert-ReleaseSignature {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$ExpectedThumbprint,
        [switch]$AllowUnsigned
    )

    $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    if ($AllowUnsigned -and $signature.Status -eq "NotSigned") { return }
    if ($signature.Status -ne "Valid") {
        throw "Authenticode verification failed for ${Path}: $($signature.Status)"
    }
    if ($ExpectedThumbprint -and $signature.SignerCertificate.Thumbprint -ne $ExpectedThumbprint) {
        throw "Unexpected signing certificate for $Path."
    }
    if (-not $signature.TimeStamperCertificate) {
        throw "An RFC 3161 timestamp is required for $Path."
    }
}

function Invoke-WindowsSigning {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Options
    )

    $resolvedFile = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $arguments = @("sign", "/sha1", $Options.Thumbprint, "/s", "My", "/fd", "SHA256",
        "/tr", $Options.TimestampUrl, "/td", "SHA256", "/d", "Video HOK")
    if ($Options.Store -eq "LocalMachine") { $arguments += "/sm" }
    $arguments += $resolvedFile
    & $Options.SignToolPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "SignTool failed for $resolvedFile (exit $LASTEXITCODE)." }
    Assert-ReleaseSignature -Path $resolvedFile -ExpectedThumbprint $Options.Thumbprint
}
