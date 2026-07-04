#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if grep -E -n 'fopen|open\(|CreateFile|sscanf|strtok|socket\(|connect\(' \
    "$root/src/fortran_polycall.c" "$root/src/fortran_polycall.f90"; then
    echo "fortran-polycall must not parse configuration or implement runtime logic" >&2
    exit 1
fi

grep -F -q 'polycall_ffi_run_config(config_path, 1)' \
    "$root/src/fortran_polycall.c"
grep -F -q 'bind(C, name="fortran_polycall_run_config")' \
    "$root/src/fortran_polycall.f90"
grep -F -q 'c_null_char' "$root/src/fortran_polycall.f90"

echo "fortran-polycall thin-adapter check: PASS"
