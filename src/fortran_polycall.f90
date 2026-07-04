module fortran_polycall
    use, intrinsic :: iso_c_binding, only: c_char, c_int, c_null_char
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    private

    character(len=*), parameter, public :: polycall_default_config = &
        "fortran-polycallrc"

    public :: polycall_run_config
    public :: polycall_run_config_or_stop

    interface
        function c_polycall_run_config(config_path) &
            bind(C, name="fortran_polycall_run_config") result(status)
            import :: c_char, c_int
            character(kind=c_char), intent(in) :: config_path(*)
            integer(c_int) :: status
        end function c_polycall_run_config
    end interface

contains

    function polycall_run_config(config_path) result(status)
        character(len=*), intent(in), optional :: config_path
        integer(c_int) :: status
        character(kind=c_char), allocatable :: c_path(:)

        if (present(config_path)) then
            call to_c_string(config_path, c_path)
        else
            call to_c_string(polycall_default_config, c_path)
        end if

        status = c_polycall_run_config(c_path)
    end function polycall_run_config

    subroutine polycall_run_config_or_stop(config_path)
        character(len=*), intent(in), optional :: config_path
        integer(c_int) :: status

        if (present(config_path)) then
            status = polycall_run_config(config_path)
        else
            status = polycall_run_config()
        end if

        if (status /= 0_c_int) then
            write(error_unit, '(A,I0)') &
                "libpolycall failed with status ", status
            error stop "libpolycall failure"
        end if
    end subroutine polycall_run_config_or_stop

    subroutine to_c_string(source, target)
        character(len=*), intent(in) :: source
        character(kind=c_char), allocatable, intent(out) :: target(:)
        integer :: i
        integer :: length

        length = len_trim(source)
        allocate(target(length + 1))

        do i = 1, length
            target(i) = achar(iachar(source(i:i)), kind=c_char)
        end do
        target(length + 1) = c_null_char
    end subroutine to_c_string

end module fortran_polycall
