!> fortran-polycall tests against the REAL installed libpolycall (no mock).
!>
!>   fortran_polycall_test <repo-root>
!>
!> Covers the checklist of the core's docs/BINDING_ABI.md through the
!> Fortran module (OpenMP threads for cancel/close/concurrent senders).
!> Checks that need the C CLI read POLYCALL_CLI, POLYCALL_CLI_PEER,
!> POLYCALL_RPC_ENDPOINT and POLYCALL_DEV_TOKEN (tests/run-real.sh); without
!> them they print SKIP, never PASS. ERROR STOP on any FAIL.
module test_support
    use, intrinsic :: iso_c_binding, only: c_int
    implicit none
    integer :: n_pass = 0, n_fail = 0, n_skip = 0

    interface
        function c_usleep(usec) bind(C, name="usleep") result(r)
            import :: c_int
            integer(c_int), value :: usec
            integer(c_int) :: r
        end function c_usleep
    end interface

contains

    subroutine check(ok, name, detail)
        logical, intent(in) :: ok
        character(len=*), intent(in) :: name
        character(len=*), intent(in), optional :: detail
        if (ok) then
            n_pass = n_pass + 1
            print '(2A)', "PASS ", name
        else
            n_fail = n_fail + 1
            if (present(detail)) then
                print '(4A)', "FAIL ", name, " -- ", detail
            else
                print '(2A)', "FAIL ", name
            end if
        end if
        flush (6)
    end subroutine check

    subroutine expect(want, got, name)
        integer(c_int), intent(in) :: want, got
        character(len=*), intent(in) :: name
        character(len=48) :: d
        write (d, '(A,I0,A,I0)') "expected ", want, " got ", got
        call check(want == got, name, trim(d))
    end subroutine expect

    subroutine skip(name, reason)
        character(len=*), intent(in) :: name, reason
        n_skip = n_skip + 1
        print '(4A)', "SKIP ", name, " -- ", reason
        flush (6)
    end subroutine skip

    subroutine sleep_ms(ms)
        integer, intent(in) :: ms
        integer(c_int) :: r
        r = c_usleep(int(ms * 1000, c_int))
    end subroutine sleep_ms

    function env(name) result(v)
        character(len=*), intent(in) :: name
        character(len=:), allocatable :: v
        integer :: n, st
        call get_environment_variable(name, length=n, status=st)
        if (st /= 0 .or. n == 0) then
            v = ""
            return
        end if
        allocate (character(len=n) :: v)
        call get_environment_variable(name, v)
    end function env

    function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=:), allocatable :: s
        character(len=16) :: t
        write (t, '(I0)') i
        s = trim(t)
    end function itoa

    function slurp(path) result(s)
        character(len=*), intent(in) :: path
        character(len=:), allocatable :: s
        integer :: u, n, ios
        open (newunit=u, file=path, access='stream', form='unformatted', status='old', &
              action='read', iostat=ios)
        if (ios /= 0) then
            s = ""
            return
        end if
        inquire (unit=u, size=n)
        allocate (character(len=n) :: s)
        if (n > 0) read (u, iostat=ios) s
        close (u)
    end function slurp

    subroutine write_bytes(path, data)
        character(len=*), intent(in) :: path, data
        integer :: u
        open (newunit=u, file=path, access='stream', form='unformatted', status='replace', &
              action='write')
        write (u) data
        close (u)
    end subroutine write_bytes

    function base64(b) result(s)
        character(len=*), intent(in) :: b
        character(len=:), allocatable :: s
        character(len=64), parameter :: t = &
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        integer :: i, v, n
        s = ""
        n = len(b)
        i = 1
        do while (i + 2 <= n)
            v = iachar(b(i:i)) * 65536 + iachar(b(i + 1:i + 1)) * 256 + iachar(b(i + 2:i + 2))
            s = s // t(v / 262144 + 1:v / 262144 + 1) // t(mod(v / 4096, 64) + 1:mod(v / 4096, 64) + 1) &
                // t(mod(v / 64, 64) + 1:mod(v / 64, 64) + 1) // t(mod(v, 64) + 1:mod(v, 64) + 1)
            i = i + 3
        end do
        if (n - i + 1 == 1) then
            v = iachar(b(i:i)) * 65536
            s = s // t(v / 262144 + 1:v / 262144 + 1) // t(mod(v / 4096, 64) + 1:mod(v / 4096, 64) + 1) &
                // "=="
        else if (n - i + 1 == 2) then
            v = iachar(b(i:i)) * 65536 + iachar(b(i + 1:i + 1)) * 256
            s = s // t(v / 262144 + 1:v / 262144 + 1) // t(mod(v / 4096, 64) + 1:mod(v / 4096, 64) + 1) &
                // t(mod(v / 64, 64) + 1:mod(v / 64, 64) + 1) // "="
        end if
    end function base64

end module test_support

program fortran_polycall_test
    use, intrinsic :: iso_c_binding, only: c_int, c_int32_t
    use, intrinsic :: iso_fortran_env, only: int64
    use fortran_polycall
    use test_support
    implicit none

    character(len=:), allocatable :: root
    integer :: n

    call get_command_argument(1, length=n)
    if (n > 0) then
        allocate (character(len=n) :: root)
        call get_command_argument(1, root)
    else
        root = "."
    end if

    print '(4A)', "fortran-polycall real-core tests: libpolycall ", polycall_version(), &
        ", ABI ", itoa(int(polycall_abi_version()))
    call test_version()
    call test_run_config()
    call test_call()
    call test_peers()
    call test_auth_transport()
    call test_threads()
    call test_interop()
    print '(6A)', "SUMMARY pass=", itoa(n_pass), " fail=", itoa(n_fail), " skip=", itoa(n_skip)
    deallocate (root)
    if (n_fail > 0) error stop 1

contains

    subroutine test_version()
        type(polycall_error) :: err
        character(len=:), allocatable :: v
        call check(polycall_abi_version() == 1, "abi: polycall_abi_version() == 1")
        call expect(POLYCALL_OK, polycall_check_abi(err), "abi: polycall_check_abi accepts the library")
        v = polycall_version()
        call check(len(v) >= 5 .and. v(1:2) == "1." .and. lge(v, "1.1.0"), "version: library >= 1.1.0", v)
        call check(index(polycall_strerror(POLYCALL_E_TIMEOUT), "POLYCALL_E_TIMEOUT") == 1, &
                   "strerror names E_TIMEOUT")
        call check(index(polycall_strerror(-999_c_int), "POLYCALL_E_UNKNOWN") == 1, &
                   "strerror of an unknown code")
    end subroutine test_version

    subroutine test_run_config()
        type(polycall_error) :: err
        character(len=:), allocatable :: fx, json
        fx = root // "/tests/fixtures/"
        call expect(POLYCALL_OK, polycall_run_config(root // "/fortran-polycallrc"), &
                    "run_config: shipped fortran-polycallrc (run=1)")
        call expect(POLYCALL_OK, polycall_run_config(root // "/fortran-polycallrc", strict=.false.), &
                    "run_config: valid, validate-only")
        call expect(POLYCALL_OK, polycall_run_config(root // "/examples/fortran-polycallrc"), &
                    "run_config: examples/fortran-polycallrc")
        call expect(POLYCALL_E_NOT_FOUND, polycall_run_config(fx // "does-not-exist", err=err), &
                    "run_config: missing -> E_NOT_FOUND")
        call check(err%status == POLYCALL_E_NOT_FOUND .and. index(err%name, "POLYCALL_E_NOT_FOUND") == 1 &
                   .and. index(err%detail, "does-not-exist") > 0, &
                   "polycall_error carries status, name and last_error detail", err%detail)
        call expect(POLYCALL_E_CONFIG, polycall_run_config(fx // "invalid-polycallrc", strict=.false.), &
                    "run_config: malformed -> E_CONFIG (validate)")
        call expect(POLYCALL_E_CONFIG, polycall_run_config(fx // "invalid-polycallrc"), &
                    "run_config: malformed -> E_CONFIG (strict)")
        call expect(POLYCALL_OK, polycall_run_config(fx // "unknown-key-polycallrc", strict=.false.), &
                    "run_config: unknown key warns when validating")
        call expect(POLYCALL_E_CONFIG, polycall_run_config(fx // "unknown-key-polycallrc", strict=.true.), &
                    "run_config: unknown key fails when strict")
        call expect(POLYCALL_OK, polycall_run_config(fx // "tls-polycallrc", strict=.false.), &
                    "run_config: tls_enabled=true validates")
        call expect(POLYCALL_E_UNSUPPORTED, polycall_run_config(fx // "tls-polycallrc"), &
                    "run_config: tls strict -> E_UNSUPPORTED")
        call expect(POLYCALL_E_INVALID_ARGUMENT, polycall_run_config(""), "run_config: empty path")
        call expect(POLYCALL_OK, polycall_describe(root // "/fortran-polycallrc", json), "describe: OK")
        call check(json(1:1) == "{" .and. index(json, "log_level") > 0, "describe: JSON", json)
    end subroutine test_run_config

    subroutine test_call()
        character(len=:), allocatable :: ep, out
        type(polycall_error) :: err
        call expect(POLYCALL_E_TRANSPORT, &
                    polycall_call("127.0.0.1:1", "debug", "echo", "{}", 1500, out), &
                    "call: no runtime -> E_TRANSPORT")
        call expect(POLYCALL_E_INVALID_ARGUMENT, &
                    polycall_call("127.0.0.1:1", "debug", "echo", "{}", 0, out), &
                    "call: timeout 0 -> E_INVALID_ARGUMENT")
        ep = env("POLYCALL_RPC_ENDPOINT")
        if (len(ep) == 0) then
            call skip("call: success / unknown op / deadline / invalid input", &
                      "POLYCALL_RPC_ENDPOINT not set (run via tests/run-real.sh)")
            return
        end if
        call expect(POLYCALL_OK, polycall_call(ep, "inventory", "get", '{"item_id":"widget-a"}', 3000, out), &
                    "call: inventory.get")
        call check(out == '{"item_id":"widget-a","quantity":42,"in_stock":true}', &
                   "call: inventory.get exact output", out)
        call expect(POLYCALL_OK, polycall_call(ep, "debug", "echo", '{"v":[1,2]}', 3000, out), "call: debug.echo")
        call check(out == '{"echo":{"v":[1,2]}}', "call: debug.echo exact output", out)
        call expect(POLYCALL_OK, polycall_call(ep, "debug", "echo", "", 3000, out), "call: empty input")
        call check(out == '{"echo":null}', "call: empty input is sent as null", out)
        call expect(POLYCALL_E_NOT_FOUND, polycall_call(ep, "inventory", "teleport", "{}", 3000, out, err), &
                    "call: unknown operation -> E_NOT_FOUND")
        call check(index(out, "operation.unknown") > 0, "call: unknown operation error object", out)
        call expect(POLYCALL_E_REMOTE, polycall_call(ep, "inventory", "get", '{"item_id":"nope"}', 3000, out), &
                    "call: unknown item -> E_REMOTE")
        call check(index(out, "item.unknown") > 0, "call: E_REMOTE error object", out)
        call expect(POLYCALL_E_TIMEOUT, polycall_call(ep, "debug", "sleep", '{"ms":3000}', 200, out), &
                    "call: deadline -> E_TIMEOUT")
        call expect(POLYCALL_E_INVALID_ARGUMENT, polycall_call(ep, "debug", "echo", "{not json", 1000, out), &
                    "call: invalid input JSON -> E_INVALID_ARGUMENT")
    end subroutine test_call

    subroutine exchange(from, from_id, to, payload, mid, label)
        integer(c_int32_t), intent(in) :: from, to
        character(len=*), intent(in) :: from_id, payload, mid, label
        character(len=:), allocatable :: ep, sender, id, got
        integer(c_int) :: s, r
        s = polycall_peer_endpoint(to, ep)
        s = polycall_peer_send(from, ep, payload, mid)
        r = -99
        if (s == POLYCALL_OK) r = polycall_peer_recv(to, 5000_c_int32_t, sender, id, got)
        call check(s == POLYCALL_OK .and. r == POLYCALL_OK .and. sender == from_id .and. id == mid &
                   .and. len(got) == len(payload) .and. got == payload, label, &
                   "send=" // itoa(int(s)) // " recv=" // itoa(int(r)))
    end subroutine exchange

    subroutine test_peers()
        integer(c_int32_t) :: a, b, so
        character(len=:), allocatable :: ea, eb, s, sender, id, payload, mib, json
        character(len=*), parameter :: utf8 = "h" // char(195) // char(169) // "llo " // &
            char(226) // char(156) // char(147)
        character(len=7) :: bin
        type(polycall_error) :: err
        integer :: i
        integer(c_int) :: st
        integer(int64) :: t0, t1, rate

        bin = achar(0) // achar(1) // achar(0) // char(255) // char(127) // achar(0) // char(128)
        call expect(POLYCALL_OK, polycall_peer_open("f90-a", a), "peer: open a")
        call expect(POLYCALL_OK, polycall_peer_open("f90-b", b, "127.0.0.1:0"), "peer: open b")
        st = polycall_peer_endpoint(a, ea)
        st = polycall_peer_endpoint(b, eb)
        call check(index(ea, "127.0.0.1:") == 1 .and. ea /= "127.0.0.1:0", "peer: ephemeral endpoint", ea)
        st = polycall_peer_node_id(a, s)
        call check(s == "f90-a", "peer: node_id", s)
        st = polycall_peer_health(a, json)
        call check(index(json, '"node_id":"f90-a"') > 0, "peer: health JSON", json)

        allocate (character(len=1048577) :: mib)
        do i = 1, len(mib)
            mib(i:i) = char(mod((i - 1) * 31 + 7, 256))
        end do
        call exchange(a, "f90-a", b, "", "m-empty-ab", "peer a->b: empty payload")
        call exchange(b, "f90-b", a, "", "m-empty-ba", "peer b->a: empty payload")
        call exchange(a, "f90-a", b, utf8, "m-utf8-ab", "peer a->b: UTF-8")
        call exchange(b, "f90-b", a, utf8, "m-utf8-ba", "peer b->a: UTF-8")
        call exchange(a, "f90-a", b, bin, "m-bin-ab", "peer a->b: binary with NUL")
        call exchange(b, "f90-b", a, bin, "m-bin-ba", "peer b->a: binary with NUL")
        call exchange(a, "f90-a", b, mib(1:1048576), "m-mib-ab", "peer a->b: exactly 1 MiB")
        call exchange(b, "f90-b", a, mib(1:1048576), "m-mib-ba", "peer b->a: exactly 1 MiB")
        call expect(POLYCALL_E_TOO_LARGE, polycall_peer_send(a, eb, mib, "m-over"), &
                    "peer: 1 MiB + 1 -> E_TOO_LARGE")
        call expect(POLYCALL_E_TIMEOUT, polycall_peer_recv(b, 200_c_int32_t, sender, id, payload), &
                    "peer: oversize payload never delivered")

        ! registry ownership
        call expect(POLYCALL_OK, polycall_peer_register(a, "f90-b", eb), "registry: register on a")
        st = polycall_peer_list(a, json)
        call check(index(json, '"f90-b":"' // eb // '"') > 0, "registry: a lists f90-b", json)
        st = polycall_peer_list(b, json)
        call check(json == "{}", "registry: b's registry is its own (empty)", json)
        call expect(POLYCALL_OK, polycall_peer_send(a, "f90-b", "by-id", "m-by-id"), &
                    "registry: send by registered id")
        st = polycall_peer_recv(b, 5000_c_int32_t, sender, id, payload)
        call check(st == POLYCALL_OK .and. payload == "by-id" .and. sender == "f90-a", &
                   "registry: received by id")
        st = polycall_peer_list(b, json)
        call check(json == "{}", "registry: receiving does not register the sender", json)
        call expect(POLYCALL_OK, polycall_peer_ping(a, "f90-b", 3000), "ping: registered id")
        call expect(POLYCALL_OK, polycall_peer_ping(a, eb, 3000), "ping: host:port")
        st = polycall_peer_register(a, "impostor", eb)
        call expect(POLYCALL_E_PROTOCOL, polycall_peer_ping(a, "impostor", 3000), &
                    "ping: id answered by another node -> E_PROTOCOL")
        call expect(POLYCALL_OK, polycall_peer_unregister(a, "impostor"), "registry: unregister")
        call expect(POLYCALL_E_NOT_FOUND, polycall_peer_unregister(a, "impostor"), &
                    "registry: unregister unknown -> E_NOT_FOUND")
        call expect(POLYCALL_E_INVALID_ARGUMENT, polycall_peer_register(a, "bad id!", eb, err), &
                    "registry: invalid id -> E_INVALID_ARGUMENT")

        ! duplicate message id
        st = polycall_peer_send(a, eb, "dup", "m-dup")
        call expect(POLYCALL_OK, polycall_peer_send(a, eb, "dup", "m-dup"), "duplicate: resend acknowledged")
        st = polycall_peer_recv(b, 5000_c_int32_t, sender, id, payload)
        call check(st == POLYCALL_OK .and. id == "m-dup", "duplicate: first copy delivered")
        call expect(POLYCALL_E_TIMEOUT, polycall_peer_recv(b, 300_c_int32_t, sender, id, payload), &
                    "duplicate: second copy dropped")

        ! generated id, timeout, too-small buffer
        st = polycall_peer_send(a, eb, "gen")
        st = polycall_peer_recv(b, 5000_c_int32_t, sender, id, payload)
        call check(st == POLYCALL_OK .and. len(id) > 0 .and. payload == "gen", "send: message id generated", id)
        call system_clock(t0, rate)
        call expect(POLYCALL_E_TIMEOUT, polycall_peer_recv(b, 150_c_int32_t, sender, id, payload), &
                    "recv: timeout -> E_TIMEOUT")
        call system_clock(t1)
        call check(real(t1 - t0) / real(rate) >= 0.1, "recv: waited for the timeout")
        st = polycall_peer_send(a, eb, "0123456789", "m-small")
        st = polycall_peer_recv(b, 1000_c_int32_t, sender, id, payload, initial_capacity=4)
        call check(st == POLYCALL_OK .and. payload == "0123456789" .and. id == "m-small", &
                   "recv: 4-byte buffer -> E_TOO_LARGE kept the message queued (regrown)")

        ! send-only node
        call expect(POLYCALL_OK, polycall_peer_open_send_only("f90-sendonly", so), "send-only: open")
        st = polycall_peer_endpoint(so, s)
        call check(st == POLYCALL_OK .and. len(s) == 0, "send-only: empty endpoint")
        call expect(POLYCALL_OK, polycall_peer_send(so, eb, "so", "m-so"), "send-only: can send")
        st = polycall_peer_recv(b, 5000_c_int32_t, sender, id, payload)
        call check(sender == "f90-sendonly", "send-only: delivered")
        st = polycall_peer_close(so)
        st = polycall_peer_close(a)
        st = polycall_peer_close(b)
    end subroutine test_peers

    subroutine test_auth_transport()
        integer(c_int32_t) :: sec, anon, wrong, member, gone, h
        character(len=:), allocatable :: es, dead, sender, id, payload
        integer(c_int) :: st
        st = polycall_peer_open("f90-secured", sec, "127.0.0.1:0", "qa-secret-1")
        st = polycall_peer_open_send_only("f90-anon", anon)
        st = polycall_peer_open_send_only("f90-wrong", wrong, "nope")
        st = polycall_peer_open_send_only("f90-member", member, "qa-secret-1")
        st = polycall_peer_endpoint(sec, es)
        call expect(POLYCALL_E_AUTH, polycall_peer_send(anon, es, "x", "m-a1"), "auth: no token -> E_AUTH")
        call expect(POLYCALL_E_AUTH, polycall_peer_send(wrong, es, "x", "m-a2"), "auth: wrong token -> E_AUTH")
        call expect(POLYCALL_OK, polycall_peer_send(member, es, "x", "m-a3"), "auth: right token delivers")
        st = polycall_peer_recv(sec, 5000_c_int32_t, sender, id, payload)
        call check(sender == "f90-member", "auth: received from the member")
        call expect(POLYCALL_E_CONFIG, polycall_peer_open("f90-open", h, "0.0.0.0:0"), &
                    "open: non-loopback without token -> E_CONFIG")
        call expect(POLYCALL_E_INVALID_ARGUMENT, polycall_peer_open("bad id", h), "open: invalid node id")
        st = polycall_peer_open("f90-gone", gone)
        st = polycall_peer_endpoint(gone, dead)
        st = polycall_peer_close(gone)
        call expect(POLYCALL_E_TRANSPORT, polycall_peer_send(member, dead, "x", "m-dead", 3000), &
                    "send to a dead peer -> E_TRANSPORT")
        st = polycall_peer_close(sec)
        st = polycall_peer_close(anon)
        st = polycall_peer_close(wrong)
        st = polycall_peer_close(member)
    end subroutine test_auth_transport

    subroutine test_threads()
        integer(c_int32_t) :: r, rx, tx
        integer(c_int) :: blocked, st, fails
        character(len=:), allocatable :: sender, id, payload, ep
        character(len=64) :: seen(100)
        integer :: t, i, j, unique
        logical :: dup

        st = polycall_peer_open("f90-blocked", r)
        blocked = 1
        !$omp parallel sections num_threads(2) private(sender, id, payload, st)
        !$omp section
        blocked = polycall_peer_recv(r, polycall_wait_forever, sender, id, payload)
        !$omp section
        call sleep_ms(300)
        st = polycall_peer_cancel(r)
        !$omp end parallel sections
        call expect(POLYCALL_E_CANCELLED, blocked, "cancel wakes a blocked recv -> E_CANCELLED")
        blocked = 1
        !$omp parallel sections num_threads(2) private(sender, id, payload, st)
        !$omp section
        blocked = polycall_peer_recv(r, polycall_wait_forever, sender, id, payload)
        !$omp section
        call sleep_ms(300)
        st = polycall_peer_close(r)
        !$omp end parallel sections
        call expect(POLYCALL_E_CLOSED, blocked, "close wakes a blocked recv -> E_CLOSED")
        call expect(POLYCALL_E_INVALID_HANDLE, polycall_peer_close(r), "double close -> E_INVALID_HANDLE")
        call expect(POLYCALL_E_INVALID_HANDLE, polycall_peer_endpoint(r, ep), "endpoint after close")
        call expect(POLYCALL_E_INVALID_HANDLE, polycall_peer_send(r, "127.0.0.1:1", "x"), "send after close")
        call expect(POLYCALL_E_INVALID_HANDLE, polycall_peer_recv(r, 0_c_int32_t, sender, id, payload), &
                    "recv after close")
        call expect(POLYCALL_E_INVALID_HANDLE, polycall_peer_close(0_c_int32_t), "close(0)")
        call expect(POLYCALL_E_INVALID_HANDLE, polycall_peer_cancel(987654_c_int32_t), "cancel(unknown handle)")

        st = polycall_peer_open("f90-rx", rx)
        st = polycall_peer_endpoint(rx, ep)
        fails = 0
        !$omp parallel do num_threads(4) private(tx, i, st) reduction(+:fails)
        do t = 0, 3
            st = polycall_peer_open_send_only("f90-tx" // itoa(t), tx)
            if (st /= POLYCALL_OK) then
                fails = fails + 25
            else
                do i = 0, 24
                    st = polycall_peer_send(tx, ep, "t" // itoa(t) // "-" // itoa(i), &
                                            "m-" // itoa(t) // "-" // itoa(i), 10000)
                    if (st /= POLYCALL_OK) fails = fails + 1
                end do
                st = polycall_peer_close(tx)
            end if
        end do
        !$omp end parallel do
        unique = 0
        do i = 1, 100
            st = polycall_peer_recv(rx, 10000_c_int32_t, sender, id, payload)
            if (st /= POLYCALL_OK) exit
            dup = .false.
            do j = 1, unique
                if (seen(j) == sender // "/" // id) dup = .true.
            end do
            if (.not. dup) then
                unique = unique + 1
                seen(unique) = sender // "/" // id
            end if
        end do
        call check(unique == 100 .and. fails == 0, &
                   "concurrent senders: 4 OpenMP threads x 25, all delivered once", &
                   itoa(unique) // " unique, " // itoa(int(fails)) // " failures")
        st = polycall_peer_close(rx)
    end subroutine test_threads

    subroutine test_interop()
        character(len=:), allocatable :: cli, cli_peer, ep, sender, id, got, payload
        integer(c_int32_t) :: node
        integer(c_int) :: st
        integer :: rc, cst

        rc = 0
        cst = 0
        cli = env("POLYCALL_CLI")
        cli_peer = env("POLYCALL_CLI_PEER")
        if (len(cli) == 0 .or. len(cli_peer) == 0) then
            call skip("interop: polycall CLI peer -> Fortran", "POLYCALL_CLI/POLYCALL_CLI_PEER not set")
            call skip("interop: Fortran -> polycall CLI peer", "POLYCALL_CLI/POLYCALL_CLI_PEER not set")
            return
        end if
        payload = "f90" // achar(0) // "bin" // achar(1) // char(255) // " " // char(195) // char(169) // " end"
        st = polycall_peer_open("f90-node", node, "127.0.0.1:0", env("POLYCALL_DEV_TOKEN"))
        st = polycall_peer_endpoint(node, ep)
        call write_bytes("f90_cli_payload.bin", payload)
        call execute_command_line('"' // cli // '" peer send --to ' // ep // &
            ' --payload-file f90_cli_payload.bin --from cli-node --id cli-to-f90-1 -t 5000' // &
            ' > f90_cli_send.log 2>&1', exitstat=rc, cmdstat=cst)
        st = -99
        if (rc == 0) st = polycall_peer_recv(node, 5000_c_int32_t, sender, id, got)
        call check(rc == 0 .and. st == POLYCALL_OK .and. sender == "cli-node" .and. id == "cli-to-f90-1" &
                   .and. got == payload .and. len(got) == len(payload), &
                   "interop: polycall CLI peer send -> Fortran peer (bytes, sender, id)", slurp("f90_cli_send.log"))

        st = polycall_peer_register(node, "cli-node", cli_peer)
        call expect(POLYCALL_OK, polycall_peer_ping(node, "cli-node", 3000), "interop: ping the CLI node by id")
        st = polycall_peer_send(node, "cli-node", payload, "f90-to-cli-1")
        call execute_command_line('"' // cli // '" --format json peer recv --to ' // cli_peer // &
            ' -t 5000 > f90_cli_recv.json 2>&1', exitstat=rc, cmdstat=cst)
        got = slurp("f90_cli_recv.json")
        call check(st == POLYCALL_OK .and. rc == 0 .and. index(got, '"from":"f90-node"') > 0 &
                   .and. index(got, '"id":"f90-to-cli-1"') > 0 &
                   .and. index(got, '"payload_b64":"' // base64(payload) // '"') > 0, &
                   "interop: Fortran peer -> polycall peer serve, read by polycall peer recv", got)
        call execute_command_line("rm -f f90_cli_payload.bin f90_cli_send.log f90_cli_recv.json", exitstat=rc, cmdstat=cst)
        st = polycall_peer_close(node)
    end subroutine test_interop

end program fortran_polycall_test
