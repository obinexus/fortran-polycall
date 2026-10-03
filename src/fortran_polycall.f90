!> fortran-polycall: ISO_C_BINDING interface to the Polycall binding ABI v1
!> (<polycall.h>, polycall >= 1.1.0; docs/BINDING_ABI.md in
!> https://github.com/obinexus/polycall).
!>
!> The C functions are bound directly (BIND(C) interfaces, no C shim).
!> Strings cross as NUL-terminated character(kind=c_char) arrays, byte
!> buffers as character(kind=c_char) arrays plus a c_size_t length, peer
!> handles as integer(c_int32_t). Every function returns the core status
!> (POLYCALL_OK = 0 or a negative POLYCALL_E_* code) and, when the optional
!> ERR argument is present, fills a type(polycall_error) with the status, its
!> name (polycall_strerror) and the detail (polycall_last_error).
module fortran_polycall
    use, intrinsic :: iso_c_binding, only: c_char, c_int, c_int32_t, c_size_t, &
        c_ptr, c_null_ptr, c_null_char, c_loc, c_f_pointer, c_associated
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    private

    character(len=*), parameter, public :: polycall_default_config = &
        "fortran-polycallrc"

    integer(c_int), parameter, public :: polycall_expected_abi = 1_c_int

    ! status codes (POLYCALL_OK / POLYCALL_E_*)
    integer(c_int), parameter, public :: POLYCALL_OK = 0
    integer(c_int), parameter, public :: POLYCALL_E_INVALID_ARGUMENT = -1
    integer(c_int), parameter, public :: POLYCALL_E_NO_MEMORY = -2
    integer(c_int), parameter, public :: POLYCALL_E_INVALID_HANDLE = -3
    integer(c_int), parameter, public :: POLYCALL_E_TIMEOUT = -4
    integer(c_int), parameter, public :: POLYCALL_E_TRANSPORT = -5
    integer(c_int), parameter, public :: POLYCALL_E_PROTOCOL = -6
    integer(c_int), parameter, public :: POLYCALL_E_NOT_FOUND = -7
    integer(c_int), parameter, public :: POLYCALL_E_AUTH = -8
    integer(c_int), parameter, public :: POLYCALL_E_REMOTE = -9
    integer(c_int), parameter, public :: POLYCALL_E_TOO_LARGE = -10
    integer(c_int), parameter, public :: POLYCALL_E_BUSY = -11
    integer(c_int), parameter, public :: POLYCALL_E_CANCELLED = -12
    integer(c_int), parameter, public :: POLYCALL_E_CONFIG = -13
    integer(c_int), parameter, public :: POLYCALL_E_ADDRESS_IN_USE = -14
    integer(c_int), parameter, public :: POLYCALL_E_UNSUPPORTED = -15
    integer(c_int), parameter, public :: POLYCALL_E_PERMISSION = -16
    integer(c_int), parameter, public :: POLYCALL_E_CLOSED = -17
    integer(c_int), parameter, public :: POLYCALL_E_INTERNAL = -18

    ! limits
    integer(c_size_t), parameter, public :: polycall_max_payload = 1048576_c_size_t
    integer(c_size_t), parameter, public :: polycall_max_call_output = 1048576_c_size_t
    !> recv timeout meaning "wait until a message, cancel or close"
    !> (UINT32_MAX: the same 32 bits as -1).
    integer(c_int32_t), parameter, public :: polycall_wait_forever = -1_c_int32_t

    !> Fortran-native error value: status code, polycall_strerror name and
    !> polycall_last_error detail of the failing call.
    type, public :: polycall_error
        integer(c_int) :: status = POLYCALL_OK
        character(len=:), allocatable :: name
        character(len=:), allocatable :: detail
    end type polycall_error

    public :: polycall_abi_version, polycall_check_abi, polycall_version
    public :: polycall_strerror, polycall_last_error
    public :: polycall_run_config, polycall_run_config_or_stop, polycall_describe
    public :: polycall_call
    public :: polycall_peer_open, polycall_peer_open_send_only, polycall_peer_close
    public :: polycall_peer_endpoint, polycall_peer_node_id
    public :: polycall_peer_register, polycall_peer_unregister, polycall_peer_list
    public :: polycall_peer_ping, polycall_peer_send, polycall_peer_recv
    public :: polycall_peer_cancel, polycall_peer_health

    interface
        function c_abi_version() bind(C, name="polycall_ffi_abi_version") result(r)
            import :: c_int
            integer(c_int) :: r
        end function c_abi_version

        function c_version(buf, len) bind(C, name="polycall_ffi_version") result(r)
            import :: c_char, c_int
            character(kind=c_char), intent(out) :: buf(*)
            integer(c_int), value :: len
            integer(c_int) :: r
        end function c_version

        function c_strerror(status) bind(C, name="polycall_strerror") result(p)
            import :: c_int, c_ptr
            integer(c_int), value :: status
            type(c_ptr) :: p
        end function c_strerror

        function c_last_error(buf, cap) bind(C, name="polycall_last_error") result(r)
            import :: c_char, c_int, c_size_t
            character(kind=c_char), intent(out) :: buf(*)
            integer(c_size_t), value :: cap
            integer(c_int) :: r
        end function c_last_error

        function c_run_config(path, run) bind(C, name="polycall_ffi_run_config") result(r)
            import :: c_char, c_int
            character(kind=c_char), intent(in) :: path(*)
            integer(c_int), value :: run
            integer(c_int) :: r
        end function c_run_config

        function c_describe(path, buf, len) bind(C, name="polycall_ffi_describe") result(r)
            import :: c_char, c_int
            character(kind=c_char), intent(in) :: path(*)
            character(kind=c_char), intent(out) :: buf(*)
            integer(c_int), value :: len
            integer(c_int) :: r
        end function c_describe

        function c_call(endpoint, service, operation, input, timeout_ms, out, out_cap, &
                        out_len) bind(C, name="polycall_call") result(r)
            import :: c_char, c_int, c_int32_t, c_size_t, c_ptr
            character(kind=c_char), intent(in) :: endpoint(*), service(*), operation(*)
            type(c_ptr), value :: input
            integer(c_int32_t), value :: timeout_ms
            character(kind=c_char), intent(inout) :: out(*)
            integer(c_size_t), value :: out_cap
            integer(c_size_t), intent(out) :: out_len
            integer(c_int) :: r
        end function c_call

        function c_peer_open(node_id, bind_ep, token, handle) &
                bind(C, name="polycall_peer_open") result(r)
            import :: c_char, c_int, c_int32_t, c_ptr
            character(kind=c_char), intent(in) :: node_id(*)
            type(c_ptr), value :: bind_ep, token
            integer(c_int32_t), intent(out) :: handle
            integer(c_int) :: r
        end function c_peer_open

        function c_peer_close(h) bind(C, name="polycall_peer_close") result(r)
            import :: c_int, c_int32_t
            integer(c_int32_t), value :: h
            integer(c_int) :: r
        end function c_peer_close

        function c_peer_endpoint(h, buf, cap) bind(C, name="polycall_peer_endpoint") result(r)
            import :: c_char, c_int, c_int32_t, c_size_t
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(out) :: buf(*)
            integer(c_size_t), value :: cap
            integer(c_int) :: r
        end function c_peer_endpoint

        function c_peer_node_id(h, buf, cap) bind(C, name="polycall_peer_node_id") result(r)
            import :: c_char, c_int, c_int32_t, c_size_t
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(out) :: buf(*)
            integer(c_size_t), value :: cap
            integer(c_int) :: r
        end function c_peer_node_id

        function c_peer_register(h, peer_id, endpoint) &
                bind(C, name="polycall_peer_register") result(r)
            import :: c_char, c_int, c_int32_t
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(in) :: peer_id(*), endpoint(*)
            integer(c_int) :: r
        end function c_peer_register

        function c_peer_unregister(h, peer_id) bind(C, name="polycall_peer_unregister") result(r)
            import :: c_char, c_int, c_int32_t
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(in) :: peer_id(*)
            integer(c_int) :: r
        end function c_peer_unregister

        function c_peer_list(h, buf, cap, out_len) bind(C, name="polycall_peer_list") result(r)
            import :: c_char, c_int, c_int32_t, c_size_t
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(out) :: buf(*)
            integer(c_size_t), value :: cap
            integer(c_size_t), intent(out) :: out_len
            integer(c_int) :: r
        end function c_peer_list

        function c_peer_ping(h, peer, timeout_ms) bind(C, name="polycall_peer_ping") result(r)
            import :: c_char, c_int, c_int32_t
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(in) :: peer(*)
            integer(c_int32_t), value :: timeout_ms
            integer(c_int) :: r
        end function c_peer_ping

        function c_peer_send(h, peer, payload, len, message_id, timeout_ms) &
                bind(C, name="polycall_peer_send") result(r)
            import :: c_char, c_int, c_int32_t, c_size_t, c_ptr
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(in) :: peer(*)
            character(kind=c_char), intent(in) :: payload(*)
            integer(c_size_t), value :: len
            type(c_ptr), value :: message_id
            integer(c_int32_t), value :: timeout_ms
            integer(c_int) :: r
        end function c_peer_send

        function c_peer_recv(h, timeout_ms, sender, sender_cap, message_id, message_id_cap, &
                             payload, payload_cap, payload_len) &
                bind(C, name="polycall_peer_recv") result(r)
            import :: c_char, c_int, c_int32_t, c_size_t
            integer(c_int32_t), value :: h
            integer(c_int32_t), value :: timeout_ms
            character(kind=c_char), intent(out) :: sender(*)
            integer(c_size_t), value :: sender_cap
            character(kind=c_char), intent(out) :: message_id(*)
            integer(c_size_t), value :: message_id_cap
            character(kind=c_char), intent(inout) :: payload(*)
            integer(c_size_t), value :: payload_cap
            integer(c_size_t), intent(out) :: payload_len
            integer(c_int) :: r
        end function c_peer_recv

        function c_peer_cancel(h) bind(C, name="polycall_peer_cancel") result(r)
            import :: c_int, c_int32_t
            integer(c_int32_t), value :: h
            integer(c_int) :: r
        end function c_peer_cancel

        function c_peer_health(h, buf, cap, out_len) bind(C, name="polycall_peer_health") result(r)
            import :: c_char, c_int, c_int32_t, c_size_t
            integer(c_int32_t), value :: h
            character(kind=c_char), intent(out) :: buf(*)
            integer(c_size_t), value :: cap
            integer(c_size_t), intent(out) :: out_len
            integer(c_int) :: r
        end function c_peer_health

        function c_strlen(s) bind(C, name="strlen") result(n)
            import :: c_ptr, c_size_t
            type(c_ptr), value :: s
            integer(c_size_t) :: n
        end function c_strlen
    end interface

contains

    ! ---- helpers ---------------------------------------------------------------

    !> NUL-terminated c_char array of a Fortran string (trailing blanks kept:
    !> callers pass exact values).
    pure function to_c(s) result(a)
        character(len=*), intent(in) :: s
        character(kind=c_char) :: a(len(s) + 1)
        integer :: i
        do i = 1, len(s)
            a(i) = s(i:i)
        end do
        a(len(s) + 1) = c_null_char
    end function to_c

    !> S = text of a NUL-terminated c_char buffer.
    !>
    !> A subroutine, not a function, on purpose: gfortran (12 and 14 checked)
    !> keeps the hidden length of a deferred-length character FUNCTION result
    !> in a static variable at each call site, so such a call is not
    !> re-entrant and races when two threads run it. Every procedure of this
    !> module therefore fills deferred-length strings through intent(out)
    !> arguments and never calls a deferred-length function internally.
    pure subroutine from_c(a, s)
        character(kind=c_char), intent(in) :: a(:)
        character(len=:), allocatable, intent(out) :: s
        integer :: i, n
        n = size(a)
        do i = 1, size(a)
            if (a(i) == c_null_char) then
                n = i - 1
                exit
            end if
        end do
        allocate (character(len=n) :: s)
        do i = 1, n
            s(i:i) = a(i)
        end do
    end subroutine from_c

    !> NAME = polycall_strerror(STATUS) (static string of the library).
    subroutine strerror_into(status, name)
        integer(c_int), intent(in) :: status
        character(len=:), allocatable, intent(out) :: name
        type(c_ptr) :: p
        character(kind=c_char), pointer :: chars(:)
        integer(c_size_t) :: n
        p = c_strerror(status)
        n = c_strlen(p)
        call c_f_pointer(p, chars, [n])
        call from_c(chars, name)
    end subroutine strerror_into

    !> DETAIL = polycall_last_error() of the calling thread.
    subroutine last_error_into(detail)
        character(len=:), allocatable, intent(out) :: detail
        character(kind=c_char) :: buf(2048)
        integer(c_int) :: n
        buf(1) = c_null_char
        n = c_last_error(buf, int(size(buf), c_size_t))
        if (n < 0) then
            detail = ""
        else
            call from_c(buf, detail)
        end if
    end subroutine last_error_into

    subroutine set_err(err, status)
        type(polycall_error), intent(out), optional :: err
        integer(c_int), intent(in) :: status
        if (.not. present(err)) return
        err%status = status
        if (status == POLYCALL_OK) then
            err%name = ""
            err%detail = ""
        else
            ! polycall_last_error is per thread: read it before anything else
            call last_error_into(err%detail)
            call strerror_into(status, err%name)
        end if
    end subroutine set_err

    ! ---- library -----------------------------------------------------------

    function polycall_abi_version() result(v)
        integer(c_int) :: v
        v = c_abi_version()
    end function polycall_abi_version

    !> POLYCALL_OK when the loaded library speaks binding ABI 1, else
    !> POLYCALL_E_UNSUPPORTED (ERR explains which ABI it reported).
    function polycall_check_abi(err) result(status)
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        integer(c_int) :: got
        character(len=16) :: txt
        got = c_abi_version()
        status = POLYCALL_OK
        if (got /= polycall_expected_abi) status = POLYCALL_E_UNSUPPORTED
        if (present(err)) then
            err%status = status
            call strerror_into(status, err%name)
            write (txt, '(I0)') got
            err%detail = "libpolycall reports binding ABI " // trim(txt) // &
                ", fortran-polycall requires ABI 1"
            if (status == POLYCALL_OK) err%detail = ""
        end if
    end function polycall_check_abi

    !> polycall_version, polycall_strerror and polycall_last_error return
    !> character(len=:), allocatable. With gfortran the CALLER keeps the
    !> length of such a result in a static variable (see from_c), so do not
    !> run one call site of them from several threads at once; threaded code
    !> gets the same name and detail race-free from the optional ERR
    !> argument (type(polycall_error)) of every other function.
    function polycall_version() result(v)
        character(len=:), allocatable :: v
        character(kind=c_char) :: buf(64)
        integer(c_int) :: n
        n = c_version(buf, int(size(buf), c_int))
        if (n < 0) then
            v = ""
        else
            call from_c(buf, v)
        end if
    end function polycall_version

    function polycall_strerror(status) result(name)
        integer(c_int), intent(in) :: status
        character(len=:), allocatable :: name
        call strerror_into(status, name)
    end function polycall_strerror

    function polycall_last_error() result(detail)
        character(len=:), allocatable :: detail
        call last_error_into(detail)
    end function polycall_last_error

    ! ---- configuration -------------------------------------------------------

    !> polycall_ffi_run_config(config_path, run): run=1 (strict, the default
    !> and historical behaviour) or run=0 when STRICT is .false..
    !> CONFIG_PATH defaults to "fortran-polycallrc". Status returned unchanged.
    function polycall_run_config(config_path, strict, err) result(status)
        character(len=*), intent(in), optional :: config_path
        logical, intent(in), optional :: strict
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        integer(c_int) :: run
        run = 1_c_int
        if (present(strict)) then
            if (.not. strict) run = 0_c_int
        end if
        status = polycall_check_abi(err)   ! names the ABI the library reported
        if (status /= POLYCALL_OK) return
        if (present(config_path)) then
            status = c_run_config(to_c(trim(config_path)), run)
        else
            status = c_run_config(to_c(polycall_default_config), run)
        end if
        call set_err(err, status)
    end function polycall_run_config

    subroutine polycall_run_config_or_stop(config_path)
        character(len=*), intent(in), optional :: config_path
        type(polycall_error) :: err
        integer(c_int) :: status

        if (present(config_path)) then
            status = polycall_run_config(config_path, err=err)
        else
            status = polycall_run_config(err=err)
        end if

        if (status /= POLYCALL_OK) then
            write (error_unit, '(A,I0,4A)') "libpolycall failed with status ", status, &
                ": ", err%name, " -- ", err%detail
            error stop "libpolycall failure"
        end if
    end subroutine polycall_run_config_or_stop

    !> polycall_ffi_describe: JSON description of the configuration file.
    function polycall_describe(config_path, json, err) result(status)
        character(len=*), intent(in) :: config_path
        character(len=:), allocatable, intent(out) :: json
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char), allocatable :: buf(:)
        integer :: cap, attempt
        cap = 16384
        json = ""
        status = polycall_check_abi(err)
        if (status /= POLYCALL_OK) return
        do attempt = 1, 4
            allocate (buf(cap))
            status = c_describe(to_c(trim(config_path)), buf, int(cap, c_int))
            if (status < 0) then
                call set_err(err, status)
                return
            end if
            if (status < cap) then
                call from_c(buf, json)
                status = POLYCALL_OK
                call set_err(err, status)
                return
            end if
            cap = status + 1
            deallocate (buf)
        end do
        status = POLYCALL_E_TOO_LARGE
        call set_err(err, status)
    end function polycall_describe

    ! ---- RPC -----------------------------------------------------------------

    !> One polycall_rpc v1 round trip (never retried). INPUT_JSON "" = null.
    !> OUTPUT: the operation's output JSON, or the remote error object when
    !> the status is E_REMOTE / E_NOT_FOUND / E_TIMEOUT / E_BUSY.
    function polycall_call(endpoint, service, operation, input_json, timeout_ms, output, &
                           err) result(status)
        character(len=*), intent(in) :: endpoint, service, operation, input_json
        integer, intent(in) :: timeout_ms
        character(len=:), allocatable, intent(out) :: output
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char), allocatable :: buf(:)
        character(kind=c_char), allocatable, target :: input(:)
        integer(c_size_t) :: out_len
        type(c_ptr) :: pinput
        integer :: i

        output = ""
        status = polycall_check_abi(err)
        if (status /= POLYCALL_OK) return
        allocate (buf(polycall_max_call_output + 1))
        buf(1) = c_null_char
        pinput = c_null_ptr
        if (len(input_json) > 0) then
            allocate (input(len(input_json) + 1))
            do i = 1, len(input_json)
                input(i) = input_json(i:i)
            end do
            input(len(input_json) + 1) = c_null_char
            pinput = c_loc(input)
        end if
        out_len = 0
        status = c_call(to_c(endpoint), to_c(service), to_c(operation), pinput, &
                        int(timeout_ms, c_int32_t), buf, size(buf, kind=c_size_t), out_len)
        call set_err(err, status)
        call from_c(buf, output)
    end function polycall_call

    ! ---- peer nodes ------------------------------------------------------------

    !> Open a listening node (BIND_ENDPOINT defaults to "127.0.0.1:0", an
    !> ephemeral loopback port; AUTH_TOKEN "" or absent = none).
    function polycall_peer_open(node_id, handle, bind_endpoint, auth_token, err) result(status)
        character(len=*), intent(in) :: node_id
        integer(c_int32_t), intent(out) :: handle
        character(len=*), intent(in), optional :: bind_endpoint, auth_token
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char), allocatable, target :: cbind(:), ctoken(:)
        type(c_ptr) :: ptoken

        if (present(bind_endpoint)) then
            allocate (cbind(len(bind_endpoint) + 1))
            cbind = to_c(bind_endpoint)
        else
            allocate (cbind(12))
            cbind = to_c("127.0.0.1:0")
        end if
        ptoken = c_null_ptr
        if (present(auth_token)) then
            if (len(auth_token) > 0) then
                allocate (ctoken(len(auth_token) + 1))
                ctoken = to_c(auth_token)
                ptoken = c_loc(ctoken)
            end if
        end if
        handle = 0
        status = polycall_check_abi(err)   ! names the ABI the library reported
        if (status /= POLYCALL_OK) return
        status = c_peer_open(to_c(node_id), c_loc(cbind), ptoken, handle)
        call set_err(err, status)
    end function polycall_peer_open

    !> Open a node without a listener (send, ping, own registry).
    function polycall_peer_open_send_only(node_id, handle, auth_token, err) result(status)
        character(len=*), intent(in) :: node_id
        integer(c_int32_t), intent(out) :: handle
        character(len=*), intent(in), optional :: auth_token
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char), allocatable, target :: ctoken(:)
        type(c_ptr) :: ptoken

        ptoken = c_null_ptr
        if (present(auth_token)) then
            if (len(auth_token) > 0) then
                allocate (ctoken(len(auth_token) + 1))
                ctoken = to_c(auth_token)
                ptoken = c_loc(ctoken)
            end if
        end if
        handle = 0
        status = polycall_check_abi(err)   ! names the ABI the library reported
        if (status /= POLYCALL_OK) return
        status = c_peer_open(to_c(node_id), c_null_ptr, ptoken, handle)
        call set_err(err, status)
    end function polycall_peer_open_send_only

    function polycall_peer_close(handle, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        status = c_peer_close(handle)
        call set_err(err, status)
    end function polycall_peer_close

    function polycall_peer_endpoint(handle, endpoint, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=:), allocatable, intent(out) :: endpoint
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char) :: buf(256)
        buf(1) = c_null_char
        status = c_peer_endpoint(handle, buf, size(buf, kind=c_size_t))
        call set_err(err, status)
        call from_c(buf, endpoint)
    end function polycall_peer_endpoint

    function polycall_peer_node_id(handle, node_id, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=:), allocatable, intent(out) :: node_id
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char) :: buf(64)
        buf(1) = c_null_char
        status = c_peer_node_id(handle, buf, size(buf, kind=c_size_t))
        call set_err(err, status)
        call from_c(buf, node_id)
    end function polycall_peer_node_id

    function polycall_peer_register(handle, peer_id, endpoint, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=*), intent(in) :: peer_id, endpoint
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        status = c_peer_register(handle, to_c(peer_id), to_c(endpoint))
        call set_err(err, status)
    end function polycall_peer_register

    function polycall_peer_unregister(handle, peer_id, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=*), intent(in) :: peer_id
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        status = c_peer_unregister(handle, to_c(peer_id))
        call set_err(err, status)
    end function polycall_peer_unregister

    !> This node's registry as JSON {"id":"host:port",...}.
    function polycall_peer_list(handle, json, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=:), allocatable, intent(out) :: json
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char), allocatable :: buf(:)
        integer(c_size_t) :: cap, needed
        integer :: attempt
        cap = 4096
        json = ""
        do attempt = 1, 4
            allocate (buf(cap))
            buf(1) = c_null_char
            status = c_peer_list(handle, buf, cap, needed)
            if (status == POLYCALL_E_TOO_LARGE .and. needed >= cap) then
                cap = needed + 1
                deallocate (buf)
                cycle
            end if
            call set_err(err, status)
            if (status == POLYCALL_OK) call from_c(buf, json)
            return
        end do
        call set_err(err, status)   ! still too small after 4 attempts
    end function polycall_peer_list

    function polycall_peer_ping(handle, peer, timeout_ms, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=*), intent(in) :: peer
        integer, intent(in) :: timeout_ms
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        status = c_peer_ping(handle, to_c(peer), int(timeout_ms, c_int32_t))
        call set_err(err, status)
    end function polycall_peer_ping

    !> Deliver PAYLOAD (binary-safe: any bytes, including achar(0)) to PEER
    !> (registered id or host:port). Exactly one delivery attempt.
    !> MESSAGE_ID "" or absent = generated by the core.
    function polycall_peer_send(handle, peer, payload, message_id, timeout_ms, err) &
            result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=*), intent(in) :: peer
        character(len=*), intent(in) :: payload
        character(len=*), intent(in), optional :: message_id
        integer, intent(in), optional :: timeout_ms
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char), allocatable, target :: cid(:)
        character(kind=c_char), allocatable :: bytes(:)
        type(c_ptr) :: pid
        integer(c_int32_t) :: timeout
        integer :: i

        timeout = 5000
        if (present(timeout_ms)) timeout = int(timeout_ms, c_int32_t)
        pid = c_null_ptr
        if (present(message_id)) then
            if (len(message_id) > 0) then
                allocate (cid(len(message_id) + 1))
                cid = to_c(message_id)
                pid = c_loc(cid)
            end if
        end if
        allocate (bytes(max(len(payload), 1)))
        bytes(1) = c_null_char
        do i = 1, len(payload)
            bytes(i) = payload(i:i)
        end do
        status = c_peer_send(handle, to_c(peer), bytes, int(len(payload), c_size_t), pid, &
                             timeout)
        call set_err(err, status)
    end function polycall_peer_send

    !> Take the oldest message: SENDER node id, MESSAGE_ID and PAYLOAD bytes.
    !> TIMEOUT_MS 0 = poll, polycall_wait_forever = block until a message,
    !> cancel or close. A buffer smaller than the message is grown and the
    !> call retried (the core keeps it queued on POLYCALL_E_TOO_LARGE);
    !> INITIAL_CAPACITY (default 65536) is the first buffer size.
    function polycall_peer_recv(handle, timeout_ms, sender, message_id, payload, &
                                initial_capacity, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        integer(c_int32_t), intent(in) :: timeout_ms
        character(len=:), allocatable, intent(out) :: sender, message_id, payload
        integer, intent(in), optional :: initial_capacity
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char) :: csender(64), cid(64)
        character(kind=c_char), allocatable :: buf(:)
        integer(c_size_t) :: cap, n
        integer :: i

        cap = 65536
        if (present(initial_capacity)) cap = max(1, initial_capacity)
        do
            allocate (buf(cap))
            csender(1) = c_null_char
            cid(1) = c_null_char
            n = 0
            status = c_peer_recv(handle, timeout_ms, csender, size(csender, kind=c_size_t), &
                                 cid, size(cid, kind=c_size_t), buf, cap, n)
            if (status /= POLYCALL_E_TOO_LARGE .or. n <= cap) exit
            cap = n          ! the message stays queued: retry with room for it
            deallocate (buf)
        end do
        call set_err(err, status)
        if (status == POLYCALL_OK) then
            call from_c(csender, sender)
            call from_c(cid, message_id)
            allocate (character(len=n) :: payload)
            do i = 1, int(n)
                payload(i:i) = buf(i)
            end do
        else
            sender = ""
            message_id = ""
            payload = ""
        end if
    end function polycall_peer_recv

    !> Wake every polycall_peer_recv blocked on HANDLE (POLYCALL_E_CANCELLED).
    function polycall_peer_cancel(handle, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        status = c_peer_cancel(handle)
        call set_err(err, status)
    end function polycall_peer_cancel

    function polycall_peer_health(handle, json, err) result(status)
        integer(c_int32_t), intent(in) :: handle
        character(len=:), allocatable, intent(out) :: json
        type(polycall_error), intent(out), optional :: err
        integer(c_int) :: status
        character(kind=c_char), allocatable :: buf(:)
        integer(c_size_t) :: cap, needed
        integer :: attempt
        cap = 4096
        json = ""
        do attempt = 1, 4
            allocate (buf(cap))
            buf(1) = c_null_char
            status = c_peer_health(handle, buf, cap, needed)
            if (status == POLYCALL_E_TOO_LARGE .and. needed >= cap) then
                cap = needed + 1
                deallocate (buf)
                cycle
            end if
            call set_err(err, status)
            if (status == POLYCALL_OK) call from_c(buf, json)
            return
        end do
        call set_err(err, status)   ! still too small after 4 attempts
    end function polycall_peer_health

end module fortran_polycall
