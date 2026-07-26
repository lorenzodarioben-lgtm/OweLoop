$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-CheckCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [string[]]$Arguments
    )

    Write-Host "> $Command $($Arguments -join ' ')"
    & $Command @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$mobileDirectory = Join-Path $repositoryRoot 'mobile'

Push-Location $mobileDirectory
try {
    Invoke-CheckCommand -Command 'flutter' -Arguments @('pub', 'get')
    Invoke-CheckCommand -Command 'dart' -Arguments @('format', '--set-exit-if-changed', '.')
    Invoke-CheckCommand -Command 'flutter' -Arguments @('analyze')
    Invoke-CheckCommand -Command 'flutter' -Arguments @('test')
}
finally {
    Pop-Location
}
