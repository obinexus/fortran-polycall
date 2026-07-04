program fortran_polycall_smoke
    use, intrinsic :: iso_c_binding, only: c_char, c_int, c_null_char
    use fortran_polycall, only: polycall_run_config
    implicit none

    interface
        subroutine mock_reset() bind(C, name="polycall_ffi_mock_reset")
        end subroutine mock_reset

        subroutine mock_return_status(status) &
            bind(C, name="polycall_ffi_mock_return_status")
            import :: c_int
            integer(c_int), value :: status
        end subroutine mock_return_status

        subroutine mock_expect_config(path) &
            bind(C, name="polycall_ffi_mock_expect_config")
            import :: c_char
            character(kind=c_char), intent(in) :: path(*)
        end subroutine mock_expect_config
    end interface

    integer(c_int) :: status

    call mock_reset()
    call mock_expect_config(c_char_"../fortran-polycallrc" // c_null_char)
    status = polycall_run_config("../fortran-polycallrc")
    if (status /= 0_c_int) error stop "expected status zero"

    call mock_return_status(37_c_int)
    status = polycall_run_config("../fortran-polycallrc")
    if (status /= 37_c_int) error stop "expected status 37"

    call mock_return_status(0_c_int)
    call mock_expect_config(c_char_"fortran-polycallrc" // c_null_char)
    status = polycall_run_config()
    if (status /= 0_c_int) error stop "default path failed"

    print '(A)', "fortran-polycall Fortran smoke test: PASS"
end program fortran_polycall_smoke
