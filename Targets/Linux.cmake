################################################################################
# Build file for a gcc, linux system.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_C_COMPILER mpicc)
set(CMAKE_Fortran_COMPILER mpif90)
set(CMAKE_CXX_COMPILER mpicxx)

set(PYTHON_INCLUDE_PATH "/usr/include/python2.7/")
set(CXX_TOOLCHAINFLAGS "-O3 -openmp -lgomp -fPIC -llapack")
set(F_TOOLCHAINFLAGS "-O3 -cpp -openmp -fPIC -llapack")