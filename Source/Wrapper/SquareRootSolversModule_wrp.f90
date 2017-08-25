!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!> Wraps the overlap solvers module for calling from other languages.
MODULE SquareRootSolversModule_wrp
  USE DistributedSparseMatrixModule_wrp, ONLY : &
       & DistributedSparseMatrix_wrp
  USE IterativeSolversModule_wrp, ONLY : IterativeSolverParameters_wrp
  USE SquareRootSolversModule, ONLY : SquareRoot, InverseSquareRoot
  USE WrapperModule, ONLY : SIZE_wrp
  USE ISO_C_BINDING, ONLY : c_int, c_bool
  IMPLICIT NONE
  PRIVATE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  PUBLIC :: SquareRoot_wrp
  PUBLIC :: InverseSquareRoot_wrp
CONTAINS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Compute the inverse square root of a matrix.
  !! @param[in]  ih_Mat1 Matrix 1.
  !! @param[out] ih_InverseSquareRootMat = Mat1^-1/2.
  !! @param[in]  ih_solver_parameters parameters for the solver
  SUBROUTINE InverseSquareRoot_wrp(ih_Mat1, ih_InverseSquareRootMat, &
       & ih_solver_parameters) bind(c,name="InverseSquareRoot_wrp")
    INTEGER(kind=c_int), INTENT(in) :: ih_Mat1(SIZE_wrp)
    INTEGER(kind=c_int), INTENT(inout) :: ih_InverseSquareRootMat(SIZE_wrp)
    INTEGER(kind=c_int), INTENT(in) :: ih_solver_parameters(SIZE_wrp)
    TYPE(DistributedSparseMatrix_wrp) :: h_Mat1
    TYPE(DistributedSparseMatrix_wrp) :: h_InverseSquareRootMat
    TYPE(IterativeSolverParameters_wrp) :: h_solver_parameters

    h_Mat1 = TRANSFER(ih_Mat1,h_Mat1)
    h_InverseSquareRootMat = TRANSFER(ih_InverseSquareRootMat, &
         & h_InverseSquareRootMat)
    h_solver_parameters = TRANSFER(ih_solver_parameters, h_solver_parameters)

    CALL InverseSquareRoot(h_Mat1%data, h_InverseSquareRootMat%data, &
         & h_solver_parameters%data)
  END SUBROUTINE InverseSquareRoot_wrp
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Compute the square root of a matrix.
  !! @param[in]  ih_Mat1 Matrix 1.
  !! @param[out] ih_SquareRootMat = Mat1^-1/2.
  !! @param[in]  ih_solver_parameters parameters for the solver
  SUBROUTINE SquareRoot_wrp(ih_Mat1, ih_SquareRootMat, ih_solver_parameters) &
       & bind(c,name="SquareRoot_wrp")
    INTEGER(kind=c_int), INTENT(in) :: ih_Mat1(SIZE_wrp)
    INTEGER(kind=c_int), INTENT(inout) :: ih_SquareRootMat(SIZE_wrp)
    INTEGER(kind=c_int), INTENT(in) :: ih_solver_parameters(SIZE_wrp)
    TYPE(DistributedSparseMatrix_wrp) :: h_Mat1
    TYPE(DistributedSparseMatrix_wrp) :: h_SquareRootMat
    TYPE(IterativeSolverParameters_wrp) :: h_solver_parameters

    h_Mat1 = TRANSFER(ih_Mat1,h_Mat1)
    h_SquareRootMat = TRANSFER(ih_SquareRootMat, h_SquareRootMat)
    h_solver_parameters = TRANSFER(ih_solver_parameters, h_solver_parameters)

    CALL SquareRoot(h_Mat1%data, h_SquareRootMat%data, &
         & h_solver_parameters%data)
  END SUBROUTINE SquareRoot_wrp
END MODULE SquareRootSolversModule_wrp