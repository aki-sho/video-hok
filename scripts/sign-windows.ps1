[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "signing.ps1")
Invoke-WindowsSigning -Path $Path -Options (Get-WindowsSigningOptions)
