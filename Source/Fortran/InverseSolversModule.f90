!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!> A Module For Computing The Inverse of a Matrix.
MODULE InverseSolversModule
  USE DataTypesModule
  USE MatrixMemoryPoolDModule
  USE MatrixDSAlgebraModule
  USE MatrixDSModule
  USE IterativeSolversModule
  USE LoadBalancerModule
  USE LoggingModule
  USE TimerModule
  USE MPI
  IMPLICIT NONE
  PRIVATE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !! Solvers
  PUBLIC :: Invert
  PUBLIC :: PseudoInverse
CONTAINS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Compute the inverse of a matrix.
  !! An implementation of Hotelling's method \cite palser1998canonical.
  !! @param[in] Mat1 Matrix 1.
  !! @param[out] InverseMat = Mat1^-1.
  !! @param[in] solver_parameters_in parameters for the solver
  SUBROUTINE Invert(Mat1, InverseMat, solver_parameters_in)
    !! Parameters
    TYPE(Matrix_ds), INTENT(in)  :: Mat1
    TYPE(Matrix_ds), INTENT(inout) :: InverseMat
    TYPE(IterativeSolverParameters_t), INTENT(in), OPTIONAL :: &
         & solver_parameters_in
    REAL(NTREAL), PARAMETER :: TWO = 2.0
    REAL(NTREAL), PARAMETER :: NEGATIVE_ONE = -1.0
    !! Handling Optional Parameters
    TYPE(IterativeSolverParameters_t) :: solver_parameters
    !! Local Variables
    REAL(NTREAL) :: sigma
    TYPE(Matrix_ds) :: Temp1,Temp2,Identity
    TYPE(Matrix_ds) :: BalancedMat1
    !! Temporary Variables
    INTEGER :: outer_counter
    REAL(NTREAL) :: norm_value
    TYPE(MatrixMemoryPool_d) :: pool1

    !! Optional Parameters
    IF (PRESENT(solver_parameters_in)) THEN
       solver_parameters = solver_parameters_in
    ELSE
       solver_parameters = IterativeSolverParameters_t()
    END IF

    IF (solver_parameters%be_verbose) THEN
       CALL WriteHeader("Inverse Solver")
       CALL EnterSubLog
       CALL WriteCitation("palser1998canonical")
       CALL PrintIterativeSolverParameters(solver_parameters)
    END IF

    !! Construct All The Necessary Matrice
    CALL ConstructEmptyMatrixDS(InverseMat, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(Temp1, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(Temp2, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(Identity, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(BalancedMat1, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL FillDistributedIdentity(Identity)

    !! Load Balancing Step
    CALL StartTimer("Load Balance")
    IF (solver_parameters%do_load_balancing) THEN
       CALL PermuteMatrix(Identity, Identity, &
            & solver_parameters%BalancePermutation, memorypool_in=pool1)
       CALL PermuteMatrix(Mat1, BalancedMat1, &
            & solver_parameters%BalancePermutation, memorypool_in=pool1)
    ELSE
       CALL CopyMatrixDS(Mat1,BalancedMat1)
    END IF
    CALL StopTimer("Load Balance")

    !! Compute Sigma
    CALL ComputeSigma(BalancedMat1,sigma)

    !! Create Inverse Guess
    CALL CopyMatrixDS(BalancedMat1,InverseMat)
    CALL ScaleDistributedSparseMatrix(InverseMat,sigma)

    !! Iterate
    IF (solver_parameters%be_verbose) THEN
       CALL WriteHeader("Iterations")
       CALL EnterSubLog
    END IF
    CALL StartTimer("I-Invert")
    outer_counter = 1
    norm_value = solver_parameters%converge_diff + 1.0d+0
    DO outer_counter = 1,solver_parameters%max_iterations
       IF (solver_parameters%be_verbose .AND. outer_counter .GT. 1) THEN
          CALL WriteListElement(key="Round", int_value_in=outer_counter-1)
          CALL EnterSubLog
          CALL WriteListElement(key="Convergence", float_value_in=norm_value)
          CALL ExitSubLog
       END IF

       CALL DistributedGemm(InverseMat,BalancedMat1,Temp1, &
            & threshold_in=solver_parameters%threshold, memory_pool_in=pool1)

       !! Check if Converged
       CALL CopyMatrixDS(Identity,Temp2)
       CALL IncrementDistributedSparseMatrix(Temp1,Temp2,REAL(-1.0,NTREAL))
       norm_value = DistributedSparseNorm(Temp2)

       CALL DestructDistributedSparseMatrix(Temp2)
       CALL DistributedGemm(Temp1,InverseMat,Temp2,alpha_in=REAL(-1.0,NTREAL), &
            & threshold_in=solver_parameters%threshold,memory_pool_in=pool1)

       !! Save a copy of the last inverse matrix
       CALL CopyMatrixDS(InverseMat,Temp1)

       CALL ScaleDistributedSparseMatrix(InverseMat,TWO)

       CALL IncrementDistributedSparseMatrix(Temp2,InverseMat, &
            & threshold_in=solver_parameters%threshold)

       IF (norm_value .LE. solver_parameters%converge_diff) THEN
          EXIT
       END IF
    END DO
    IF (solver_parameters%be_verbose) THEN
       CALL ExitSubLog
       CALL WriteElement(key="Total_Iterations",int_value_in=outer_counter-1)
       CALL PrintMatrixInformation(InverseMat)
    END IF
    CALL StopTimer("I-Invert")

    !! Undo Load Balancing Step
    CALL StartTimer("Load Balance")
    IF (solver_parameters%do_load_balancing) THEN
       CALL UndoPermuteMatrix(InverseMat,InverseMat, &
            & solver_parameters%BalancePermutation, memorypool_in=pool1)
    END IF
    CALL StopTimer("Load Balance")

    IF (solver_parameters%be_verbose) THEN
       CALL ExitSubLog
    END IF

    !! Cleanup
    CALL DestructDistributedSparseMatrix(Temp1)
    CALL DestructDistributedSparseMatrix(Temp2)
    CALL DestructDistributedSparseMatrix(BalancedMat1)
    CALL DestructMatrixMemoryPoolD(pool1)
  END SUBROUTINE Invert
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Compute the pseudoinverse of a matrix.
  !! An implementation of Hotelling's method \cite palser1998canonical.
  !! We just change the convergence criteria.
  !! @param[in] Mat1 Matrix 1.
  !! @param[out] InverseMat = Mat1^-1.
  !! @param[in] solver_parameters_in parameters for the solver
  SUBROUTINE PseudoInverse(Mat1, InverseMat, solver_parameters_in)
    !! Parameters
    TYPE(Matrix_ds), INTENT(in)  :: Mat1
    TYPE(Matrix_ds), INTENT(inout) :: InverseMat
    TYPE(IterativeSolverParameters_t), INTENT(in), OPTIONAL :: &
         & solver_parameters_in
    REAL(NTREAL), PARAMETER :: TWO = 2.0
    REAL(NTREAL), PARAMETER :: NEGATIVE_ONE = -1.0
    !! Handling Optional Parameters
    TYPE(IterativeSolverParameters_t) :: solver_parameters
    !! Local Variables
    REAL(NTREAL) :: sigma
    TYPE(Matrix_ds) :: Temp1,Temp2,Identity
    TYPE(Matrix_ds) :: BalancedMat1
    !! Temporary Variables
    INTEGER :: outer_counter
    REAL(NTREAL) :: norm_value
    TYPE(MatrixMemoryPool_d) :: pool1

    !! Optional Parameters
    IF (PRESENT(solver_parameters_in)) THEN
       solver_parameters = solver_parameters_in
    ELSE
       solver_parameters = IterativeSolverParameters_t()
    END IF

    IF (solver_parameters%be_verbose) THEN
       CALL WriteHeader("Inverse Solver")
       CALL EnterSubLog
       CALL WriteCitation("palser1998canonical")
       CALL PrintIterativeSolverParameters(solver_parameters)
    END IF

    !! Construct All The Necessary Matrices
    CALL ConstructEmptyMatrixDS(InverseMat, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(Temp1, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(Temp2, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(Identity, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL ConstructEmptyMatrixDS(BalancedMat1, &
         & Mat1%actual_matrix_dimension, Mat1%process_grid)
    CALL FillDistributedIdentity(Identity)

    !! Load Balancing Step
    IF (solver_parameters%do_load_balancing) THEN
       CALL PermuteMatrix(Identity, Identity, &
            & solver_parameters%BalancePermutation, memorypool_in=pool1)
       CALL PermuteMatrix(Mat1, BalancedMat1, &
            & solver_parameters%BalancePermutation, memorypool_in=pool1)
    ELSE
       CALL CopyMatrixDS(Mat1,BalancedMat1)
    END IF

    !! Compute Sigma
    CALL ComputeSigma(BalancedMat1,sigma)

    !! Create Inverse Guess
    CALL CopyMatrixDS(BalancedMat1,InverseMat)
    CALL ScaleDistributedSparseMatrix(InverseMat,sigma)

    !! Iterate
    IF (solver_parameters%be_verbose) THEN
       CALL WriteHeader("Iterations")
       CALL EnterSubLog
    END IF
    outer_counter = 1
    norm_value = solver_parameters%converge_diff + 1.0d+0
    DO outer_counter = 1,solver_parameters%max_iterations
       IF (solver_parameters%be_verbose .AND. outer_counter .GT. 1) THEN
          CALL WriteListElement(key="Round", int_value_in=outer_counter-1)
          CALL EnterSubLog
          CALL WriteListElement(key="Convergence", float_value_in=norm_value)
          CALL ExitSubLog
       END IF

       CALL DistributedGemm(InverseMat,BalancedMat1,Temp1, &
            & threshold_in=solver_parameters%threshold, memory_pool_in=pool1)
       CALL DistributedGemm(Temp1,InverseMat,Temp2,alpha_in=REAL(-1.0,NTREAL), &
            & threshold_in=solver_parameters%threshold,memory_pool_in=pool1)

       !! Save a copy of the last inverse matrix
       CALL CopyMatrixDS(InverseMat,Temp1)

       CALL ScaleDistributedSparseMatrix(InverseMat,TWO)
       CALL IncrementDistributedSparseMatrix(Temp2,InverseMat, &
            & threshold_in=solver_parameters%threshold)

       !! Check if Converged
       CALL IncrementDistributedSparseMatrix(InverseMat,Temp1,REAL(-1.0,NTREAL))
       norm_value = DistributedSparseNorm(Temp1)

       !! Sometimes the first few values don't change so much, so that's why
       !! I added the outer counter check
       IF (norm_value .LE. solver_parameters%converge_diff .AND. &
            & outer_counter .GT. 3) THEN
          EXIT
       END IF
    END DO
    IF (solver_parameters%be_verbose) THEN
       CALL ExitSubLog
       CALL WriteElement(key="Total_Iterations",int_value_in=outer_counter-1)
       CALL PrintMatrixInformation(InverseMat)
    END IF

    !! Undo Load Balancing Step
    IF (solver_parameters%do_load_balancing) THEN
       CALL UndoPermuteMatrix(InverseMat,InverseMat, &
            & solver_parameters%BalancePermutation, memorypool_in=pool1)
    END IF

    IF (solver_parameters%be_verbose) THEN
       CALL ExitSubLog
    END IF

    !! Cleanup
    CALL DestructDistributedSparseMatrix(Temp1)
    CALL DestructDistributedSparseMatrix(Temp2)
    CALL DestructDistributedSparseMatrix(BalancedMat1)
    CALL DestructMatrixMemoryPoolD(pool1)
  END SUBROUTINE PseudoInverse
END MODULE InverseSolversModule
