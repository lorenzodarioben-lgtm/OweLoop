param(
    [ValidateRange(1024, 65520)][int]$PortBase = 60420,
    [switch]$SkipInstall,
    [switch]$Benchmark,
    [switch]$DartIntegration
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$windowsHost = $env:OS -eq 'Windows_NT'
$npmCommand = if ($windowsHost) { 'npm.cmd' } else { 'npm' }
$npxCommand = if ($windowsHost) { 'npx.cmd' } else { 'npx' }
$flutterCommand = if ($windowsHost) { 'flutter.bat' } else { 'flutter' }
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
function Invoke-NativeCapture {
    param([string]$Command, [string[]]$Arguments, [switch]$DiscardErrorOutput)
    $resolvedCommand = (Get-Command -Name $Command -ErrorAction Stop).Source
    $capturePreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 promotes captured native stderr to ErrorRecords,
        # including successful CLI progress. Judge the process by its exit code.
        $ErrorActionPreference = 'Continue'
        if ($DiscardErrorOutput) { $captured = & $resolvedCommand @Arguments 2>$null }
        else { $captured = & $resolvedCommand @Arguments 2>&1 }
        $nativeExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $capturePreference }
    [pscustomobject]@{ Output = @($captured); ExitCode = $nativeExitCode }
}
Push-Location $repositoryRoot
try {
    if (-not $SkipInstall) { Invoke-Checked $npmCommand @('ci') }
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
    $start = Invoke-NativeCapture $npxCommand @('supabase','start','--workdir',$validationRoot)
    $start.Output | Where-Object { $_.ToString() -notmatch '(?i)ANON_KEY|SERVICE_ROLE_KEY|SECRET_KEY|JWT_SECRET|PUBLISHABLE_KEY|DB_URL|postgresql://' } | ForEach-Object { Write-Host $_ }
    if ($start.ExitCode -ne 0) { throw 'Disposable Supabase startup failed; check port availability.' }
    Invoke-Checked $npxCommand @('supabase','db','reset','--local','--workdir',$validationRoot)
    Invoke-Checked $npxCommand @('supabase','test','db','--workdir',$validationRoot)
    Invoke-Checked $npxCommand @('supabase','db','lint','--local','--level','warning','--fail-on','error','--workdir',$validationRoot)
    $statusResult = Invoke-NativeCapture $npxCommand @('supabase','status','-o','json','--workdir',$validationRoot) -DiscardErrorOutput
    if ($statusResult.ExitCode -ne 0) { throw 'Cannot inspect disposable local stack.' }
    $status = ($statusResult.Output -join "`n") | ConvertFrom-Json
    $env:SUPABASE_URL = $status.API_URL
    $env:SUPABASE_ANON_KEY = $status.ANON_KEY
    $env:SUPABASE_SERVICE_ROLE_KEY = $status.SERVICE_ROLE_KEY
    $env:OWELOOP_DB_CONTAINER = "supabase_db_$projectId"
    Invoke-Checked 'node' @('--test','scripts/delete-account.test.mjs')
    Invoke-Checked 'node' @('scripts/test-migration-upgrade.mjs')
    Invoke-Checked 'node' @('scripts/test-migration-upgrade.mjs','--sprint-ii')
    Invoke-Checked 'node' @('scripts/test-local-integration.mjs')
    if ($DartIntegration) {
        Push-Location (Join-Path $repositoryRoot 'mobile')
        try {
            if ($env:FLUTTER_ROOT) {
                $dartBinary = if ($windowsHost) { 'bin/cache/dart-sdk/bin/dart.exe' } else { 'bin/cache/dart-sdk/bin/dart' }
                Invoke-Checked (Join-Path $env:FLUTTER_ROOT $dartBinary) @((Join-Path $env:FLUTTER_ROOT 'bin/cache/flutter_tools.snapshot'),'--suppress-analytics','test','test/live/financial_transport_test.dart')
            } else { Invoke-Checked $flutterCommand @('test','test/live/financial_transport_test.dart') }
        } finally { Pop-Location }
    }
    if ($Benchmark) { Invoke-Checked 'node' @('scripts/benchmark-local.mjs') }
    Write-Host 'PASS: isolated database, security, upgrade, and real-service checks.'
}
finally {
    if (Test-Path -LiteralPath (Join-Path $validationSupabase 'config.toml')) {
        # This config belongs to a newly generated project only. Never target the
        # developer's regular stack or a linked hosted project for cleanup.
        & $npxCommand supabase stop --no-backup --workdir $validationRoot
    }
    foreach ($entry in $previousEnvironment.GetEnumerator()) { [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process') }
    Pop-Location
}
