$ErrorActionPreference = 'Stop'

# Thin-adapter audit (see verify-dry.sh).
$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root 'src/fortran_polycall.f90'
$source = Get-Content -Raw $sourcePath
$found = Select-String -Path $sourcePath -Pattern '\bopen *\(|socket|connect|\bread *\('
if ($found) {
    $found | ForEach-Object { Write-Error $_.Line }
    throw 'fortran-polycall must not parse configuration or implement runtime logic'
}
foreach ($sym in @('polycall_ffi_abi_version', 'polycall_ffi_run_config', 'polycall_call',
                   'polycall_peer_open', 'polycall_peer_send', 'polycall_peer_recv')) {
    if (-not $source.Contains("bind(C, name=`"$sym`")")) {
        throw "fortran-polycall does not bind $sym"
    }
}
Write-Output 'fortran-polycall thin-adapter check: PASS'
