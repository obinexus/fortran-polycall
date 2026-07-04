#ifndef FORTRAN_POLYCALL_H
#define FORTRAN_POLYCALL_H

#ifdef __cplusplus
extern "C" {
#endif

/* Forward the configuration path to libpolycall with run enabled. */
int fortran_polycall_run_config(const char *config_path);

#ifdef __cplusplus
}
#endif

#endif /* FORTRAN_POLYCALL_H */
