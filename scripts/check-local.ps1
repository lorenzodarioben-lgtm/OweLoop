param(
    [ValidateRange(1024, 65520)][int]$PortBase = 60420,
    [switch]$SkipInstall,
    [switch]$Benchmark,
    [switch]$DartIntegration
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$projectId = 'oweloop-check-' + [guid]::NewGuid().ToString('N').Substring(0, 10)
$validationRoot = Join-Path ([IO.Path]::GetTempPath()) $projectId
$validationSupabase = Join-Path $validationRoot 'supabase'
$previousEnvironment = @{}
foreach ($name in @('SUPABASE_URL','SUPABASE_ANON_KEY','SUPABASE_SERVICE_ROLE_KEY','OWELOOP_DB_CONTAINER')) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Validation failed: $Command $($Arguments -join ' ')" }
}
Push-Location $repositoryRoot
try {
    if (-not $SkipInstall) { Invoke-Checked 'npm.cmd' @('ci') }
    New-Item -ItemType Directory -Path $validationSupabase | Out-Null
    foreach ($directory in @('migrations','tests','functions')) {
        Copy-Item -LiteralPath (Join-Path $repositoryRoot "supabase/$directory") -Destination $validationSupabase -Recurse
    }
    $config = Get-Content -LiteralPath (Join-Path $repositoryRoot 'supabase/config.toml') -Raw
    $config = $config.Replace('project_id = "oweloop-local"', "project_id = `"$projectId`"")
    for ($index = 0; $index -le 9; $index++) { $config = $config.Replace((55420 + $index).ToString(), ($PortBase + $index).ToString()) }
    $config = $config.Replace('sql_paths = ["./seed.sql"]', 'sql_paths = []')
    Set-Content -LiteralPath (Join-Path $validationSupabase 'config.toml') -Value $config
    Write-Host "Disposable validation project: $projectId (API $($PortBase + 1), DB $($PortBase + 2))"
    $startOutput = & npx.cmd supabase start --workdir $validationRoot 2>&1
    $startResult = $LASTEXITCODE
    $startOutput | Where-Object { $_.ToString() -notmatch '(?i)ANON_KEY|SERVICE_ROLE_KEY|SECRET_KEY|JWT_SECRET|PUBLISHABLE_KEY|DB_URL|postgresql://' } | ForEach-Object { Write-Host $_ }
    if ($startResult -ne 0) { throw 'Disposable Supabase startup failed; check port availability.' }
    Invoke-Checked 'npx.cmd' @('supabase','db','reset','--local','--workdir',$validationRoot)
    Invoke-Checked 'npx.cmd' @('supabase','test','db','--workdir',$validationRoot)
    Invoke-Checked 'npx.cmd' @('supabase','db','lint','--local','--level','warning','--fail-on','error','--workdir',$validationRoot)
    $statusJson = & npx.cmd supabase status -o json --workdir $validationRoot 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect disposable local stack.' }
    $status = ($statusJson -join "`n") | ConvertFrom-Json
    $env:SUPABASE_URL = $status.API_URL
    $env:SUPABASE_ANON_KEY = $status.ANON_KEY
    $env:SUPABASE_SERVICE_ROLE_KEY = $status.SERVICE_ROLE_KEY
    $env:OWELOOP_DB_CONTAINER = "supabase_db_$projectId"
    Invoke-Checked 'node' @('--test','scripts/delete-account.test.mjs')
    Invoke-Checked 'node' @('scripts/test-migration-upgrade.mjs')
    Invoke-Checked 'node' @('scripts/test-local-integration.mjs')
    if ($DartIntegration) {
        Push-Location (Join-Path $repositoryRoot 'mobile')
        try {
            if ($env:FLUTTER_ROOT) {
                Invoke-Checked (Join-Path $env:FLUTTER_ROOT 'bin/cache/dart-sdk/bin/dart.exe') @((Join-Path $env:FLUTTER_ROOT 'bin/cache/flutter_tools.snapshot'),'--suppress-analytics','test','test/live/financial_transport_test.dart')
            } else { Invoke-Checked 'flutter.bat' @('test','test/live/financial_transport_test.dart') }
        } finally { Pop-Location }
    }
    if ($Benchmark) { Invoke-Checked 'node' @('scripts/benchmark-local.mjs') }
    Write-Host 'PASS: isolated database, security, upgrade, and real-service checks.'
}
finally {
    if (Test-Path -LiteralPath (Join-Path $validationSupabase 'config.toml')) {
        # This config belongs to a newly generated project only. Never target the
        # developer's regular stack or a linked hosted project for cleanup.
        & npx.cmd supabase stop --no-backup --workdir $validationRoot
    }
    foreach ($entry in $previousEnvironment.GetEnumerator()) { [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process') }
    Pop-Location
}
