program basic
    use, intrinsic :: iso_c_binding, only: c_int, c_int32_t
    use fortran_polycall
    implicit none

    integer(c_int32_t) :: alpha, beta
    integer(c_int) :: status
    character(len=:), allocatable :: ep, sender, id, payload
    type(polycall_error) :: err

    if (polycall_check_abi(err) /= POLYCALL_OK) error stop "libpolycall binding ABI mismatch"
    print '(2A)', "fortran-polycall: libpolycall ", polycall_version()
    call polycall_run_config_or_stop("fortran-polycallrc")
    print '(A)', "fortran-polycall: fortran-polycallrc is valid for this build"

    status = polycall_peer_open("alpha", alpha)
    status = polycall_peer_open("beta", beta)
    status = polycall_peer_endpoint(beta, ep)
    status = polycall_peer_register(alpha, "beta", ep)
    status = polycall_peer_send(alpha, "beta", "hello from Fortran", "example-1", err=err)
    if (status /= POLYCALL_OK) then
        print '(4A)', "send failed: ", err%name, " -- ", err%detail
        error stop 1
    end if
    status = polycall_peer_recv(beta, 5000_c_int32_t, sender, id, payload)
    print '(4A)', "beta received: ", payload, " from ", sender
    status = polycall_peer_close(alpha)
    status = polycall_peer_close(beta)
end program basic
