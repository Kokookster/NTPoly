!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!> A module for computing eigenvalues
MODULE EigenSolversModule
  USE DataTypesModule
  USE DenseMatrixModule
  USE DistributedSparseMatrixModule
  USE DistributedSparseMatrixAlgebraModule
  USE IterativeSolversModule
  USE LoggingModule
  USE MatrixGatherModule
  USE MatrixSendRecvModule
  USE ProcessGridModule
  USE SparseMatrixModule
  USE SparseMatrixAlgebraModule
  USE TripletListModule
  USE MPI
  IMPLICIT NONE
  PRIVATE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  PUBLIC :: DistributedEigenDecomposition
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! TYPE, PRIVATE :: JacobiHelper_t
  !    INTEGER, DIMENSION(4) :: send_dest_array
  !    INTEGER, DIMENSION(4) :: recv_src_array
  !    INTEGER, DIMENSION(4) :: send_tag_array
  !    INTEGER, DIMENSION(4) :: recv_tag_array
  ! END TYPE JacobiHelper_t
CONTAINS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  SUBROUTINE DistributedEigenDecomposition(this, eigenvectors, &
       & solver_parameters_in)
    !! Parameters
    TYPE(DistributedSparseMatrix_t), INTENT(IN) :: this
    TYPE(DistributedSparseMatrix_t), INTENT(INOUT) :: eigenvectors
    TYPE(IterativeSolverParameters_t), INTENT(IN), OPTIONAL :: &
         & solver_parameters_in
    !! Handling Optional Parameters
    TYPE(IterativeSolverParameters_t) :: solver_parameters
    !! Local Matrices
    TYPE(SparseMatrix_t), DIMENSION(:,:), ALLOCATABLE :: ABlocks
    TYPE(SparseMatrix_t), DIMENSION(:,:), ALLOCATABLE :: VBlocks
    !! Temporary Variables
    INTEGER :: num_blocks
    INTEGER :: row_counter, column_counter

    !! Optional Parameters
    IF (PRESENT(solver_parameters_in)) THEN
       solver_parameters = solver_parameters_in
    ELSE
       solver_parameters = IterativeSolverParameters_t()
    END IF

    !! Extract to local dense blocks
    CALL GetLocalBlocks(this, ABlocks)
    num_blocks = SIZE(ABlocks, DIM=1)

    !! Cleanup
    DO row_counter = 1, num_blocks
       DO column_counter = 1, num_blocks
          CALL DestructSparseMatrix(ABlocks(row_counter, column_counter))
       END DO
    END DO
    DEALLOCATE(ABlocks)

  END SUBROUTINE DistributedEigenDecomposition
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  SUBROUTINE GetLocalBlocks(distributed_matrix, ABlocks)
    !! Parameters
    TYPE(DistributedSparseMatrix_t), INTENT(IN) :: distributed_matrix
    TYPE(SparseMatrix_t), DIMENSION(:,:), ALLOCATABLE, INTENT(INOUT) :: ABlocks
    !! Local Variables
    INTEGER :: total_blocks
    INTEGER :: block_rows, block_columns
    INTEGER :: block_dimension
    !! Dimension of the processor
    INTEGER :: row_ratio, col_ratio
    INTEGER :: start_row, end_row
    INTEGER :: start_column, end_column
    INTEGER :: proc_rows, proc_columns
    !! Temporary Variables
    TYPE(SparseMatrix_t) :: local_matrix
    TYPE(TripletList_t) :: triplet_list
    INTEGER :: II, JJ

    !! We want square blocks, which requires adjusting the number of blocks
    !! stored locally.
    total_blocks = MAX(num_process_rows, num_process_columns)
    DO WHILE(MOD(total_blocks, num_process_rows) .NE. 0 .AND. &
         & MOD(total_blocks, num_process_columns) .NE. 0)
       total_blocks = total_blocks + 1
    ENDDO
    block_rows = total_blocks/num_process_rows
    block_columns = total_blocks/num_process_columns
    block_dimension = distributed_matrix%actual_matrix_dimension/total_blocks

    !! Get Local Data On The Processor
    start_row = my_row*block_rows*block_dimension + 1
    end_row = (my_row+1)*block_rows*block_dimension
    start_column = my_column*block_columns*block_dimension + 1
    end_column = (my_column+1)*block_columns*block_dimension

    CALL GetMatrixBlock(distributed_matrix, triplet_list, start_row, end_row+1,&
         & start_column, end_column+1)
    DO II = 1, triplet_list%CurrentSize
       triplet_list%data(II)%index_row = triplet_list%data(II)%index_row &
            & - start_row + 1
       triplet_list%data(II)%index_column = triplet_list%data(II)%index_column &
            & - start_column + 1
    END DO
    CALL ConstructFromTripletList(local_matrix, triplet_list, &
         & end_row - start_row + 1, end_column - start_column + 1)

    !! Split To Blocks
    ALLOCATE(ABlocks(block_rows, block_columns))

    DO II = 1, block_rows
       DO JJ = 1, block_columns
          ! CALL ConstructABlocks(II,JJ)
       END DO
    END DO

  END SUBROUTINE GetLocalBlocks
  ! !> Compute the eigenvectors of a matrix using Jacobi's method.
  ! !! @param[in] this the matrix to compute the eigenvectors of.
  ! !! @param[out] eigenvectors the eigenvectors of the matrix
  ! !! @param[inout] solver_parameters_in solver parameters (optional).
  ! SUBROUTINE DistributedEigenDecomposition(this, eigenvectors, &
  !      & solver_parameters_in)
  !   !! Parameters
  !   TYPE(DistributedSparseMatrix_t), INTENT(IN) :: this
  !   TYPE(DistributedSparseMatrix_t), INTENT(INOUT) :: eigenvectors
  !   TYPE(IterativeSolverParameters_t), INTENT(IN), OPTIONAL :: &
  !        & solver_parameters_in
  !   !! Handling Optional Parameters
  !   TYPE(IterativeSolverParameters_t) :: solver_parameters
  !   !! Local Variables
  !   TYPE(DistributedSparseMatrix_t) :: last_a, full_a
  !   TYPE(SparseMatrix_t) :: local_a, local_v
  !   TYPE(SparseMatrix_t) :: local_p_l, local_p_m
  !   TYPE(SparseMatrix_t) :: temp, temp2
  !   TYPE(JacobiHelper_t) :: helper
  !   !! Temporary Variables
  !   INTEGER :: iteration
  !   INTEGER :: block_counter
  !   INTEGER :: root_row, root_column
  !   INTEGER :: num_blocks
  !   REAL(NTREAL) :: norm_value
  !   INTEGER :: II
  !
  !   !! Optional Parameters
  !   IF (PRESENT(solver_parameters_in)) THEN
  !      solver_parameters = solver_parameters_in
  !   ELSE
  !      solver_parameters = IterativeSolverParameters_t()
  !   END IF
  !
  !   CALL PrintDistributedSparseMatrix(this)
  !
  !   !! Setup
  !   CALL ConstructEmptyDistributedSparseMatrix(eigenvectors, &
  !        & this%actual_matrix_dimension)
  !   CALL ConstructEmptyDistributedSparseMatrix(last_a, &
  !        & this%actual_matrix_dimension)
  !   CALL ConstructEmptyDistributedSparseMatrix(full_a, &
  !        & this%actual_matrix_dimension)
  !   CALL FillDistributedIdentity(eigenvectors)
  !   CALL GetLocalMatrix(eigenvectors, local_v)
  !   CALL GetLocalMatrix(this, local_a)
  !   root_row = my_row
  !   root_column = my_column
  !
  !   !! Determine exchange partners
  !   num_blocks = num_process_rows*2
  !   CALL ComputeSendPairs(helper, num_blocks)
  !
  !   ! CALL MPI_Barrier(global_comm, grid_error)
  !   ! DO II = 1, slice_size
  !   !    IF (within_slice_rank + 1 .EQ. II) THEN
  !   !       WRITE(*,*) "Rank", II, "Start"
  !   !       CALL PrintSparseMatrix(local_a)
  !   !    END IF
  !   !    CALL MPI_Barrier(global_comm, grid_error)
  !   ! END DO
  !
  !   !! Main Loop
  !   ! DO iteration = 1, solver_parameters%max_iterations
  !   DO iteration = 1, 2
  !      IF (solver_parameters%be_verbose .AND. iteration .GT. 1) THEN
  !         CALL WriteListElement(key="Round", int_value_in=iteration-1)
  !         CALL EnterSubLog
  !         CALL WriteListElement(key="Convergence", float_value_in=norm_value)
  !         CALL ExitSubLog
  !      END IF
  !      ! DO II = 1, slice_size
  !      !   IF (within_slice_rank + 1 .EQ. II) THEN
  !      !     WRITE(*,*) "Rank", II, "In"
  !      !     CALL PrintSparseMatrix(local_a)
  !      !   END IF
  !      !   CALL MPI_Barrier(global_comm, grid_error)
  !      ! END DO
  !      ! DO block_counter = 1, num_blocks
  !      DO block_counter = 1, num_blocks - 1
  !         !! Compute the eigenvectors of a local block
  !         IF (my_row .EQ. my_column) THEN
  !            CALL DenseEigenDecomposition(local_a, local_p_l, &
  !                 & solver_parameters%threshold)
  !            ! CALL CopySparseMatrix(local_p_l, local_p_m)
  !         END IF
  !
  !         !! Broadcast P
  !         ! CALL BroadcastMatrix(local_p_m, row_comm, root_column)
  !         CALL BroadcastMatrix(local_p_l, row_comm, root_row)
  !
  !         !! Multiply Blocks
  !         CALL TransposeSparseMatrix(local_p_l, temp)
  !         CALL Gemm(temp, local_a, temp2, &
  !              & threshold_in=solver_parameters%threshold)
  !         CALL Gemm(temp2, local_p_l, local_a, &
  !              & threshold_in=solver_parameters%threshold)
  !         ! CALL Gemm(local_v, local_p_m, temp, &
  !         !      & threshold_in=solver_parameters%threshold)
  !         ! CALL CopySparseMatrix(temp, local_v)
  !
  !         ! CALL MPI_Barrier(global_comm, grid_error)
  !         ! DO II = 1, slice_size
  !         !   IF (within_slice_rank + 1 .EQ. II) THEN
  !         !     WRITE(*,*) "Rank", II, "Exit"
  !         !     CALL PrintSparseMatrix(local_a)
  !         !   END IF
  !         !   CALL MPI_Barrier(global_comm, grid_error)
  !         ! END DO
  !
  !         CALL FillGlobalMatrix(local_a, full_a)
  !         CALL PrintDistributedSparseMatrix(full_a)
  !
  !         !! Exchange Blocks
  !         CALL SwapBlocks(local_a, helper)
  !
  !         CALL FillGlobalMatrix(local_a, full_a)
  !         CALL PrintDistributedSparseMatrix(full_a)
  !      END DO
  !
  !      !! Compute Norm Value
  !      ! IF (norm_value .LE. solver_parameters%converge_diff) THEN
  !      !    EXIT
  !      ! END IF
  !   END DO
  !
  !   CALL FillGlobalMatrix(local_v, eigenvectors)
  !   ! CALL FillGlobalMatrix(local_a, full_a)
  !   ! CALL PrintDistributedSparseMatrix(full_a)
  !
  !   !! Cleanup
  !   CALL DestructSparseMatrix(temp)
  !   CALL DestructSparseMatrix(temp2)
  !   CALL DestructSparseMatrix(local_v)
  !   CALL DestructSparseMatrix(local_a)
  !   CALL DestructSparseMatrix(local_p_m)
  !   CALL DestructSparseMatrix(local_p_l)
  !   CALL DestructDistributedSparseMatrix(last_a)
  !   CALL DestructDistributedSparseMatrix(full_a)
  !
  ! END SUBROUTINE DistributedEigenDecomposition
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! SUBROUTINE GetLocalMatrix(distributed_matrix, local_matrix)
  !   !! Parameters
  !   TYPE(DistributedSparseMatrix_t), INTENT(IN) :: distributed_matrix
  !   TYPE(SparseMatrix_t), INTENT(INOUT) :: local_matrix
  !   !! Local Variables
  !   TYPE(TripletList_t) :: triplet_list
  !   INTEGER :: start_row, end_row
  !   INTEGER :: start_column, end_column
  !   INTEGER :: rows, columns
  !   INTEGER :: row_ratio, col_ratio
  !   INTEGER :: II
  !
  !   row_ratio = (distributed_matrix%actual_matrix_dimension/num_process_rows)
  !   col_ratio = (distributed_matrix%actual_matrix_dimension/num_process_columns)
  !   start_row = my_row*row_ratio + 1
  !   end_row = (my_row+1)*row_ratio
  !   end_row = MIN(distributed_matrix%actual_matrix_dimension, end_row)
  !   start_column = my_column*col_ratio + 1
  !   end_column = (my_column+1)*col_ratio
  !   end_column = MIN(distributed_matrix%actual_matrix_dimension, end_column)
  !
  !   rows = end_row - start_row + 1
  !   columns = end_column - start_column + 1
  !
  !   CALL GetMatrixBlock(distributed_matrix, triplet_list, start_row, end_row+1, &
  !        & start_column, end_column+1)
  !   DO II = 1, triplet_list%CurrentSize
  !      triplet_list%data(II)%index_row = triplet_list%data(II)%index_row &
  !           & - start_row + 1
  !      triplet_list%data(II)%index_column = triplet_list%data(II)%index_column &
  !           & - start_column + 1
  !   END DO
  !   CALL ConstructFromTripletList(local_matrix, triplet_list, rows, columns)
  ! END SUBROUTINE GetLocalMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! PURE SUBROUTINE SplitFour(matrix, matrix_array)
  !   !! Parameters
  !   TYPE(SparseMatrix_t), INTENT(IN) :: matrix
  !   TYPE(SparseMatrix_t), DIMENSION(4), INTENT(INOUT) :: matrix_array
  !   !! Local
  !   TYPE(SparseMatrix_t) :: temp
  !   TYPE(SparseMatrix_t), DIMENSION(2) :: temp_rows
  !   TYPE(SparseMatrix_t), DIMENSION(2) :: temp_columns
  !
  !   CALL SplitSparseMatrixColumns(matrix, 2, temp_columns)
  !
  !   CALL TransposeSparseMatrix(temp_columns(1), temp)
  !   CALL SplitSparseMatrixColumns(temp, 2, temp_rows)
  !   CALL TransposeSparseMatrix(temp_rows(1), matrix_array(1))
  !   CALL TransposeSparseMatrix(temp_rows(2), matrix_array(3))
  !
  !   CALL TransposeSparseMatrix(temp_columns(2), temp)
  !   CALL SplitSparseMatrixColumns(temp, 2, temp_rows)
  !   CALL TransposeSparseMatrix(temp_rows(1), matrix_array(2))
  !   CALL TransposeSparseMatrix(temp_rows(2), matrix_array(4))
  !
  !   !! Cleanup
  !   CALL DestructSparseMatrix(temp_rows(1))
  !   CALL DestructSparseMatrix(temp_rows(2))
  !   CALL DestructSparseMatrix(temp_columns(1))
  !   CALL DestructSparseMatrix(temp_columns(2))
  ! END SUBROUTINE SplitFour
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! PURE SUBROUTINE MergeFour(matrix_array, matrix)
  !   !! Parameters
  !   TYPE(SparseMatrix_t), DIMENSION(4), INTENT(IN) :: matrix_array
  !   TYPE(SparseMatrix_t), INTENT(INOUT) :: matrix
  !   !! Local
  !   TYPE(SparseMatrix_t) :: temp
  !   TYPE(SparseMatrix_t), DIMENSION(2) :: temp_rows
  !
  !   CALL ComposeSparseMatrixColumns(matrix_array(1:2), temp)
  !   CALL TransposeSparseMatrix(temp, temp_rows(1))
  !
  !   CALL ComposeSparseMatrixColumns(matrix_array(3:4), temp)
  !   CALL TransposeSparseMatrix(temp, temp_rows(2))
  !
  !   CALL ComposeSparseMatrixColumns(temp_rows, temp)
  !   CALL TransposeSparseMatrix(temp, matrix)
  !
  !   !! Cleanup
  !   CALL DestructSparseMatrix(temp)
  !   CALL DestructSparseMatrix(temp_rows(1))
  !   CALL DestructSparseMatrix(temp_rows(2))
  ! END SUBROUTINE MergeFour
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! PURE SUBROUTINE ComputeSendPairs(helper, num_blocks)
  !   !! Parameters
  !   TYPE(JacobiHelper_t), INTENT(OUT) :: helper
  !   INTEGER :: num_blocks
  !   !! Local Data
  !   INTEGER, DIMENSION(num_blocks/2) :: iarray, iarray2
  !   INTEGER, DIMENSION(num_blocks/2) :: jarray, jarray2
  !   INTEGER, DIMENSION(num_blocks) :: full_array
  !   !! Temporary
  !   INTEGER :: counter
  !
  !   helper%send_tag_array = [1, 2, 3, 4]
  !
  !   IF (num_blocks .EQ. 2) THEN
  !      helper%send_dest_array = 0
  !      helper%recv_src_array = 0
  !      helper%recv_tag_array = [1, 2, 3, 4]
  !   ELSE
  !      !! Initialize array
  !      DO counter = 1, num_blocks/2
  !         jarray(counter) = 2 + 2*(counter-1)
  !      END DO
  !      DO counter = 1, num_blocks/2
  !         iarray(counter) = 1 + 2*(counter-1)
  !      END DO
  !
  !      !! Compute the send source array
  !      iarray2(1) = 1
  !      iarray2(num_blocks/2) = jarray(num_blocks/2)
  !      DO counter = 2, num_blocks/2 - 1
  !         iarray2(counter) = iarray(counter+1)
  !      END DO
  !      jarray2(1) = iarray(2)
  !      DO counter = 2, num_blocks/2
  !         jarray2(counter) = jarray(counter-1)
  !      END DO
  !
  !      !! Merge Lists Together
  !      DO counter = 1, num_blocks/2
  !         full_array((counter-1)*2 + 1) = iarray2(counter)
  !         full_array((counter-1)*2 + 2) = jarray2(counter)
  !      END DO
  !
  !      !! Minus 1, divide by 2 to compute the process ID
  !      DO counter = 1, num_blocks
  !         full_array(counter) = (full_array(counter) - 1)/2
  !      END DO
  !
  !      !! Extract within slice rank
  !      helper%send_dest_array(1) = full_array(2*my_column+1) + &
  !           & full_array(2*my_row+1)*num_process_columns
  !      helper%send_dest_array(2) = full_array(2*my_column+2) + &
  !           & full_array(2*my_row+1)*num_process_columns
  !      helper%send_dest_array(3) = full_array(2*my_column+1) + &
  !           & full_array(2*my_row+2)*num_process_columns
  !      helper%send_dest_array(4) = full_array(2*my_column+2) + &
  !           & full_array(2*my_row+2)*num_process_columns
  !
  !      !! Compute the recv source array
  !      !! Rotate values
  !      iarray2(1) = 1
  !      iarray2(2) = jarray(1)
  !      DO counter = 3, num_blocks/2
  !         iarray2(counter) = iarray(counter-1)
  !      END DO
  !      jarray2(num_process_rows) = iarray(num_process_columns)
  !      DO counter = 1, num_blocks/2 - 1
  !         jarray2(counter) = jarray(counter+1)
  !      END DO
  !
  !      !! Merge Lists Together
  !      DO counter = 1, num_blocks/2
  !         full_array((counter-1)*2 + 1) = iarray2(counter)
  !         full_array((counter-1)*2 + 2) = jarray2(counter)
  !      END DO
  !
  !      !! Minus 1, divide by 2 to compute the process ID
  !      DO counter = 1, num_blocks
  !         full_array(counter) = (full_array(counter) - 1)/2
  !      END DO
  !
  !      !! Extract within slice rank
  !      helper%recv_src_array(1) = full_array(2*my_column+1) + &
  !           & full_array(2*my_row+1)*num_process_columns
  !      helper%recv_src_array(2) = full_array(2*my_column+2) + &
  !           & full_array(2*my_row+1)*num_process_columns
  !      helper%recv_src_array(3) = full_array(2*my_column+1) + &
  !           & full_array(2*my_row+2)*num_process_columns
  !      helper%recv_src_array(4) = full_array(2*my_column+2) + &
  !           & full_array(2*my_row+2)*num_process_columns
  !
  !      !! Compute receive tag values. First base case.
  !      helper%recv_tag_array = [1, 2, 3, 4]
  !      !! Next full row edge cases.
  !      IF (my_row .EQ. 1) THEN
  !         helper%recv_tag_array = [3, 4, 3, 4]
  !      ELSE IF (my_column .EQ. 1) THEN
  !         helper%recv_tag_array = [2, 2, 4, 4]
  !      ELSE IF (my_row .EQ. num_process_rows - 1) THEN
  !         helper%recv_tag_array = [1, 2, 1, 2]
  !      ELSE IF (my_column .EQ. num_process_columns - 1) THEN
  !         helper%recv_tag_array = [1, 1, 3, 3]
  !      END IF
  !      !! Finally, individual edge cases.
  !      IF (my_row .EQ. 1 .AND. my_column .EQ. 1) THEN
  !         helper%recv_tag_array = 4
  !      ELSE IF (my_row .EQ. 1 .AND. my_column .EQ. num_process_columns - 1) THEN
  !         helper%recv_tag_array = 3
  !      ELSE IF (my_column .EQ. 1 .AND. my_row .EQ. num_process_rows - 1) THEN
  !         helper%recv_tag_array = 2
  !      ELSE IF (my_column .EQ. num_process_columns - 1 .AND. &
  !           & my_row .EQ. num_process_rows - 1) THEN
  !         helper%recv_tag_array = 1
  !      END IF
  !      !! There's also an extra edge case for just 2x2 process grid
  !      IF (num_blocks .EQ. 4) THEN
  !         IF (my_row .EQ. 1 .AND. my_column .EQ. 0) THEN
  !            helper%recv_tag_array = [3, 4, 1, 2]
  !         ELSE IF (my_row .EQ. 0 .AND. my_column .EQ. 1) THEN
  !            helper%recv_tag_array = [2, 1, 4, 3]
  !         ELSE IF (my_row .EQ. 1 .AND. my_column .EQ. 1) THEN
  !            helper%recv_tag_array = [4, 3, 2, 1]
  !         END IF
  !      END IF
  !
  !   END IF
  !
  ! END SUBROUTINE ComputeSendPairs
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! SUBROUTINE SwapBlocks(matrix, jacobi_helper)
  !   !! Parameters
  !   TYPE(SparseMatrix_t), INTENT(INOUT) :: matrix
  !   TYPE(JacobiHelper_t), INTENT(IN) :: jacobi_helper
  !   !! Local Data
  !   TYPE(SparseMatrix_t), DIMENSION(4) :: send_block, recv_block
  !   TYPE(SendRecvHelper_t), DIMENSION(4) :: send_helper, recv_helper
  !   INTEGER, DIMENSION(4) :: send_stage, recv_stage
  !   INTEGER, DIMENSION(4) :: send_finished, recv_finished
  !   LOGICAL :: completed
  !   INTEGER :: II
  !
  !   ! CALL MPI_Barrier(global_comm, grid_error)
  !   ! DO II = 1, slice_size
  !   !   IF (within_slice_rank + 1 .EQ. II) THEN
  !   !     WRITE(*,*) "Rank", II, "Enter"
  !   !     CALL PrintSparseMatrix(matrix)
  !   !   END IF
  !   !   CALL MPI_Barrier(global_comm, grid_error)
  !   ! END DO
  !
  !   CALL SplitFour(matrix, send_block)
  !
  !   send_finished = 0
  !   recv_finished = 0
  !   send_stage = 0
  !   recv_stage = 0
  !   DO WHILE(SUM(send_finished) + SUM(recv_finished) < 8)
  !      DO II=1,4
  !         !! Send Data
  !         SELECT CASE (send_stage(II))
  !         CASE(0) !! Exchange Sizes
  !            CALL SendMatrixSizes(send_block(II), &
  !                 & jacobi_helper%send_dest_array(II), within_slice_comm, &
  !                 & send_helper(II), jacobi_helper%send_tag_array(II))
  !            send_stage(II) = send_stage(II) + 1
  !         CASE(1) !! Check For Send Size Completition
  !            completed = TestSendRecvSizeRequest(send_helper(II))
  !            IF (completed) send_stage(II) = send_stage(II) + 1
  !         CASE(2) !! Send Data
  !            CALL SendMatrixData(send_block(II), &
  !                 & jacobi_helper%send_dest_array(II), within_slice_comm, &
  !                 & send_helper(II), jacobi_helper%send_tag_array(II))
  !            send_stage(II) = send_stage(II) + 1
  !         CASE(3) !! Check for outer completion
  !            completed = TestSendRecvOuterRequest(send_helper(II))
  !            IF (completed) send_stage(II) = send_stage(II) + 1
  !         CASE(4) !! Check for inner completion
  !            completed = TestSendRecvInnerRequest(send_helper(II))
  !            IF (completed) send_stage(II) = send_stage(II) + 1
  !         CASE(5) !! Check for inner completion
  !            completed = TestSendRecvDataRequest(send_helper(II))
  !            IF (completed) send_stage(II) = send_stage(II) + 1
  !         CASE(6) !! Finished
  !            send_finished(II) = 1
  !         END SELECT
  !         !! Receive Data
  !         SELECT CASE (recv_stage(II))
  !         CASE(0) !! Exchange Sizes
  !            CALL RecvMatrixSizes(recv_block(II), &
  !                 & jacobi_helper%recv_src_array(II), within_slice_comm, &
  !                 & recv_helper(II), jacobi_helper%recv_tag_array(II))
  !            recv_stage(II) = recv_stage(II) + 1
  !         CASE(1) !! Check For Recv Size Completition
  !            completed = TestSendRecvSizeRequest(recv_helper(II))
  !            IF (completed) recv_stage(II) = recv_stage(II) + 1
  !         CASE(2) !! Exchange Data
  !            CALL RecvMatrixData(recv_block(II), &
  !                 & jacobi_helper%recv_src_array(II), within_slice_comm, &
  !                 & recv_helper(II), jacobi_helper%recv_tag_array(II))
  !            recv_stage(II) = recv_stage(II) + 1
  !         CASE(3) !! Check for outer completion
  !            completed = TestSendRecvOuterRequest(recv_helper(II))
  !            IF (completed) recv_stage(II) = recv_stage(II) + 1
  !         CASE(4) !! Check for inner completion
  !            completed = TestSendRecvInnerRequest(recv_helper(II))
  !            IF (completed) recv_stage(II) = recv_stage(II) + 1
  !         CASE(5) !! Check for inner completion
  !            completed = TestSendRecvDataRequest(recv_helper(II))
  !            IF (completed) recv_stage(II) = recv_stage(II) + 1
  !         CASE(6) !! Finished
  !            recv_finished(II) = 1
  !         END SELECT
  !      END DO
  !   END DO
  !   CALL MergeFour(recv_block, matrix)
  !
  !   ! CALL MPI_Barrier(global_comm, grid_error)
  !   ! DO II = 1, slice_size
  !   !   IF (within_slice_rank + 1 .EQ. II) THEN
  !   !     WRITE(*,*) "Rank", II, "Exit"
  !   !     CALL PrintSparseMatrix(matrix)
  !   !   END IF
  !   !   CALL MPI_Barrier(global_comm, grid_error)
  !   ! END DO
  !
  !   !! Cleanup
  !   CALL DestructSparseMatrix(send_block(1))
  !   CALL DestructSparseMatrix(send_block(2))
  !   CALL DestructSparseMatrix(send_block(3))
  !   CALL DestructSparseMatrix(send_block(4))
  !   CALL DestructSparseMatrix(recv_block(1))
  !   CALL DestructSparseMatrix(recv_block(2))
  !   CALL DestructSparseMatrix(recv_block(3))
  !   CALL DestructSparseMatrix(recv_block(4))
  ! END SUBROUTINE SwapBlocks
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! SUBROUTINE FillGlobalMatrix(local, global)
  !   !! Parameters
  !   TYPE(SparseMatrix_t), INTENT(IN) :: local
  !   TYPE(DistributedSparseMatrix_t), INTENT(INOUT) :: global
  !   !! Local Variables
  !   TYPE(TripletList_t) :: triplet_list
  !   INTEGER :: start_row, start_column
  !   INTEGER :: row_ratio, col_ratio
  !   INTEGER :: II
  !
  !   CALL MatrixToTripletList(local, triplet_list)
  !
  !   !! Compute Offsets
  !   row_ratio = (global%actual_matrix_dimension/num_process_rows)
  !   col_ratio = (global%actual_matrix_dimension/num_process_columns)
  !   start_row = my_row*row_ratio + 1
  !   start_column = my_column*col_ratio + 1
  !
  !   !! Adjust Indices
  !   DO II = 1, triplet_list%CurrentSize
  !      triplet_list%data(II)%index_row = triplet_list%data(II)%index_row + &
  !           & start_row - 1
  !      triplet_list%data(II)%index_column = &
  !           & triplet_list%data(II)%index_column + start_column - 1
  !   END DO
  !
  !   CALL FillFromTripletList(global, triplet_list)
  !
  ! END SUBROUTINE FillGlobalMatrix
END MODULE EigenSolversModule
