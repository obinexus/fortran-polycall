$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$sources = @(
    (Join-Path $root 'src/fortran_polycall.c'),
    (Join-Path $root 'src/fortran_polycall.f90')
)
$forbidden = 'fopen|open\(|CreateFile|sscanf|strtok|socket\(|connect\('
$matches = Select-String -Path $sources -Pattern $forbidden

if ($matches) {
    $matches | ForEach-Object { Write-Error $_.Line }
    throw 'fortran-polycall must not parse configuration or implement runtime logic'
}

$adapter = Get-Content -Raw (Join-Path $root 'src/fortran_polycall.c')
$fortran = Get-Content -Raw (Join-Path $root 'src/fortran_polycall.f90')
if (-not $adapter.Contains('polycall_ffi_run_config(config_path, 1)')) {
    throw 'fortran-polycall does not forward through polycall_ffi_run_config'
}
if (-not $fortran.Contains('bind(C, name="fortran_polycall_run_config")')) {
    throw 'fortran-polycall does not declare the C-interoperable interface'
}
if (-not $fortran.Contains('c_null_char')) {
    throw 'fortran-polycall does not NUL-terminate C strings'
}

Write-Output 'fortran-polycall thin-adapter check: PASS'
