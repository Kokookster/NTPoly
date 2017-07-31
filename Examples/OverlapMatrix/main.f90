!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!> An example that shows how to compute the overlap matrix.
PROGRAM OverlapExample
  USE DataTypesModule, ONLY : ntreal
  USE DistributedSparseMatrixModule
  USE IterativeSolversModule
  USE PermutationModule
  USE ProcessGridModule, ONLY : ConstructProcessGrid, my_row, my_column
  USE SquareRootSolversModule, ONLY : InverseSquareRoot
  USE TimerModule
  USE TripletListModule
  USE mpi
  IMPLICIT NONE
  !! Parameters
  INTEGER :: process_rows, process_columns, process_slices
  REAL(ntreal) :: threshold, convergence_threshold
  TYPE(IterativeSolverParameters) :: solver_parameters
  INTEGER :: basis_functions
  !! Matrices
  TYPE(DistributedSparseMatrix) :: Overlap, ISQOverlap
  TYPE(Permutation_t) :: permutation
  !! Triplet List
  TYPE(TripletList_t) :: triplet_list
  TYPE(Triplet_t) :: temporary_triplet
  !! For Parallelism
  INTEGER :: start_row, start_column
  INTEGER :: end_row, end_column
  INTEGER :: local_rows, local_columns
  !! MPI Variables
  INTEGER :: ierr
  INTEGER :: provided
  INTEGER :: rank
  !! Temporary Variables
  CHARACTER(len=80) :: argument
  CHARACTER(len=80) :: argument_value
  INTEGER :: column_counter, row_counter
  INTEGER :: counter
  REAL(ntreal) :: integral_value

  !! Setup MPI
  CALL MPI_Init_thread(MPI_THREAD_SERIALIZED, provided, ierr)
  CALL MPI_Comm_rank(MPI_COMM_WORLD,rank, ierr)

  !! Process the input parameters.
  DO counter=1,command_argument_count(),2
     CALL get_command_argument(counter,argument)
     CALL get_command_argument(counter+1,argument_value)
     SELECT CASE(argument)
     CASE('--basis_functions')
        READ(argument_value,*) basis_functions
     CASE('--convergence_threshold')
        READ(argument_value,*) convergence_threshold
     CASE('--process_rows')
        READ(argument_value,*) process_rows
     CASE('--process_columns')
        READ(argument_value,*) process_columns
     CASE('--process_slices')
        READ(argument_value,*) process_slices
     CASE('--threshold')
        READ(argument_value,*) threshold
     END SELECT
  END DO

  !! Setup the process grid.
  CALL ConstructProcessGrid(MPI_COMM_WORLD, process_rows, process_columns, &
       & process_slices)

  !! Timers
  CALL RegisterTimer("Construct Triplet List")
  CALL RegisterTimer("Fill")
  CALL RegisterTimer("Solve")

  !! Figure out which part of the local matrix we will store
  local_rows = basis_functions/process_rows
  local_columns = basis_functions/process_columns
  start_row = (local_rows)*my_row + 1
  start_column = (local_columns)*my_column + 1
  end_row = start_row + local_rows - 1
  end_column = start_column + local_columns - 1

  !! Build The Empty Matrices
  CALL ConstructEmpty(Overlap, basis_functions)
  CALL ConstructEmpty(ISQOverlap, basis_functions)

  !! Compute The Overlap Matrix
  CALL StartTimer("Construct Triplet List")
  CALL ConstructTripletList(triplet_list)
  DO row_counter=start_row,end_row
     DO column_counter=start_column,end_column
        integral_value = ComputeIntegral(row_counter,column_counter)
        IF (integral_value .GT. threshold) THEN
           temporary_triplet%point_value = integral_value
           temporary_triplet%index_column = column_counter
           temporary_triplet%index_row = row_counter
           CALL AppendToTripletList(triplet_list,temporary_triplet)
        END IF
     END DO
  END DO
  CALL StopTimer("Construct Triplet List")

  CALL StartTimer("Fill")
  CALL FillFromTripletList(Overlap, triplet_list)
  CALL StopTimer("Fill")

  !! Set Up The Solver Parameters.
  CALL ConstructRandomPermutation(permutation, &
       & Overlap%logical_matrix_dimension)
  solver_parameters = IterativeSolverParameters(&
       & converge_diff_in=convergence_threshold, threshold_in=threshold, &
       & BalancePermutation_in=permutation, be_verbose_in=.TRUE.)

  !! Call the solver routine.
  CALL StartTimer("Solve")
  CALL InverseSquareRoot(Overlap, ISQOverlap, solver_parameters)
  CALL StopTimer("Solve")

  !! Write the output to file
  CALL WriteToMatrixMarket(Overlap,"input.mtx")
  CALL WriteToMatrixMarket(ISQOverlap,"output.mtx")

  !! Cleanup
  CALL PrintAllTimers()
  CALL DestructDistributedSparseMatrix(Overlap)
  CALL DestructDistributedSparseMatrix(ISQOverlap)
  CALL MPI_Finalize(ierr)
CONTAINS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  FUNCTION ComputeIntegral(row,column) RESULT(integral_value)
    !! Parameters
    INTEGER :: row
    INTEGER :: column
    REAL(ntreal) :: integral_value

    IF (row .EQ. column) THEN
       integral_value = 1.0
    ELSE
       integral_value = 1.0/(ABS(row - column)+1)
    END IF
  END FUNCTION ComputeIntegral
END PROGRAM OverlapExample