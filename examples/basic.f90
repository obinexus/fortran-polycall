program basic
    use fortran_polycall, only: polycall_run_config_or_stop
    implicit none

    call polycall_run_config_or_stop("fortran-polycallrc")
    print '(A)', "fortran-polycall: configuration started successfully"
end program basic
