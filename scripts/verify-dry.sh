#!/usr/bin/env sh
# Thin-adapter audit: fortran-polycall binds the real binding ABI of
# <polycall.h> with BIND(C) interfaces and must not parse configuration or
# open sockets itself.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
src="$root/src/fortran_polycall.f90"

if grep -E -n -i '\bopen *\(|socket|connect|\bread *\(' "$src"; then
    echo "fortran-polycall must not parse configuration or implement runtime logic" >&2
    exit 1
fi
if grep -R -n 'polycall_ffi\.h' "$root/src" "$root/Makefile"; then
    echo "fortran-polycall must bind the real ABI, not a generated stub" >&2
    exit 1
fi
for sym in polycall_ffi_abi_version polycall_ffi_version polycall_strerror \
           polycall_last_error polycall_ffi_run_config polycall_ffi_describe polycall_call \
           polycall_peer_open polycall_peer_close polycall_peer_endpoint polycall_peer_node_id \
           polycall_peer_register polycall_peer_unregister polycall_peer_list polycall_peer_ping \
           polycall_peer_send polycall_peer_recv polycall_peer_cancel polycall_peer_health; do
    grep -F -q "bind(C, name=\"$sym\")" "$src"
done
grep -F -q 'c_null_char' "$src"

echo "fortran-polycall thin-adapter check: PASS"
