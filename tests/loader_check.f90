!> Loader check for tests/loader-errors.sh: what a Fortran program sees from
!> the library it was started with. Prints one line per step:
!>
!>   loader-check: abi=<n>
!>   loader-check: check_abi=<status> <name> (<detail>)
!>   loader-check: run_config=<status>
!>   loader-check: call=<status>   (127.0.0.1:1: E_TRANSPORT with the real core)
!>   loader-check: peer_open=<status> <name> (<detail>)
!>
!> Run from the repository root (it validates ./fortran-polycallrc).
program loader_check
    use, intrinsic :: iso_c_binding, only: c_int, c_int32_t
    use fortran_polycall
    implicit none
    type(polycall_error) :: err
    integer(c_int) :: st
    integer(c_int32_t) :: h
    character(len=:), allocatable :: out

    print '(A,I0)', "loader-check: abi=", polycall_abi_version()
    st = polycall_check_abi(err)
    if (st == POLYCALL_OK) then
        print '(A)', "loader-check: check_abi=0 OK"
    else
        print '(A,I0,5A)', "loader-check: check_abi=", st, " ", err%name, " (", err%detail, ")"
    end if
    print '(A,I0)', "loader-check: run_config=", polycall_run_config("fortran-polycallrc")
    st = polycall_call("127.0.0.1:1", "debug", "echo", "{}", 1000, out)
    print '(A,I0)', "loader-check: call=", st
    st = polycall_peer_open("loader-check", h, err=err)
    if (st == POLYCALL_OK) then
        st = polycall_peer_close(h)
        print '(A)', "loader-check: peer_open=0 OK"
    else
        print '(A,I0,5A)', "loader-check: peer_open=", st, " ", err%name, " (", err%detail, ")"
    end if
end program loader_check
