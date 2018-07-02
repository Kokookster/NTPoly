  !! Local Data
  INTEGER, DIMENSION(:), ALLOCATABLE :: row_start_list
  INTEGER, DIMENSION(:), ALLOCATABLE :: column_start_list
  INTEGER, DIMENSION(:), ALLOCATABLE :: row_end_list
  INTEGER, DIMENSION(:), ALLOCATABLE :: column_end_list
  !! Send Buffer
  INTEGER, DIMENSION(:), ALLOCATABLE :: send_per_proc
  INTEGER, DIMENSION(:), ALLOCATABLE :: send_buffer_offsets
  INTEGER, DIMENSION(:), ALLOCATABLE :: send_buffer_row
  INTEGER, DIMENSION(:), ALLOCATABLE :: send_buffer_col
  !! Receive Buffer
  INTEGER, DIMENSION(:), ALLOCATABLE :: recv_buffer_offsets
  INTEGER, DIMENSION(:), ALLOCATABLE :: recv_per_proc
  INTEGER, DIMENSION(:), ALLOCATABLE :: recv_buffer_row
  INTEGER, DIMENSION(:), ALLOCATABLE :: recv_buffer_col
  !! Temporary
  INTEGER :: counter, p_counter
  INTEGER :: ierr

  !! Merge all the local data
  CALL MergeMatrixLocalBlocks(this, merged_local_data)
  CALL MatrixToTripletList(merged_local_data, local_triplet_list)

  !! Share the start row/column information across processes
  ALLOCATE(row_start_list(this%process_grid%slice_size))
  ALLOCATE(column_start_list(this%process_grid%slice_size))
  ALLOCATE(row_end_list(this%process_grid%slice_size))
  ALLOCATE(column_end_list(this%process_grid%slice_size))
  CALL MPI_Allgather(start_row, 1, MPI_INT, row_start_list, 1, MPI_INT, &
       & this%process_grid%within_slice_comm, ierr)
  CALL MPI_Allgather(start_column, 1, MPI_INT, column_start_list, 1, MPI_INT,&
       & this%process_grid%within_slice_comm, ierr)
  CALL MPI_Allgather(end_row, 1, MPI_INT, row_end_list, 1, MPI_INT, &
       & this%process_grid%within_slice_comm, ierr)
  CALL MPI_Allgather(end_column, 1, MPI_INT, column_end_list, 1, MPI_INT,&
       & this%process_grid%within_slice_comm, ierr)

  !! Count The Number of Elements To Send To Each Process
  ALLOCATE(send_per_proc(this%process_grid%slice_size))
  send_per_proc = 0
  DO counter = 1, local_triplet_list%CurrentSize
     CALL GetTripletAt(local_triplet_list, counter, temp_triplet)
     temp_triplet%index_row = temp_triplet%index_row + this%start_row - 1
     temp_triplet%index_column = temp_triplet%index_column + &
          & this%start_column - 1
     DO p_counter = 1, this%process_grid%slice_size
        IF (temp_triplet%index_row .GE. row_start_list(p_counter) .AND. &
             & temp_triplet%index_row .LT. row_end_list(p_counter) .AND. &
             & temp_triplet%index_column .GE. column_start_list(p_counter) .AND. &
             & temp_triplet%index_column .LT. column_end_list(p_counter)) THEN
           send_per_proc(p_counter) = send_per_proc(p_counter) + 1
           EXIT
        END IF
     END DO
  END DO
  !! Compute send buffer offsets
  ALLOCATE(send_buffer_offsets(this%process_grid%slice_size))
  send_buffer_offsets(1) = 1
  DO counter = 2, this%process_grid%slice_size
     send_buffer_offsets(counter) = send_buffer_offsets(counter-1) + &
          & send_per_proc(counter-1)
  END DO

  !! Build a send buffer
  ALLOCATE(send_buffer_row(local_triplet_list%CurrentSize))
  ALLOCATE(send_buffer_col(local_triplet_list%CurrentSize))
  ALLOCATE(send_buffer_val(local_triplet_list%CurrentSize))
  DO counter = 1, local_triplet_list%CurrentSize
     CALL GetTripletAt(local_triplet_list, counter, temp_triplet)
     temp_triplet%index_row = temp_triplet%index_row + this%start_row - 1
     temp_triplet%index_column = temp_triplet%index_column + &
          & this%start_column - 1
     DO p_counter = 1, this%process_grid%slice_size
        IF (temp_triplet%index_row .GE. row_start_list(p_counter) .AND. &
             & temp_triplet%index_row .LT. row_end_list(p_counter) .AND. &
             & temp_triplet%index_column .GE. column_start_list(p_counter) .AND. &
             & temp_triplet%index_column .LT. column_end_list(p_counter)) THEN
           send_buffer_row(send_buffer_offsets(p_counter)) = &
                & temp_triplet%index_row
           send_buffer_col(send_buffer_offsets(p_counter)) = &
                & temp_triplet%index_column
           send_buffer_val(send_buffer_offsets(p_counter)) = &
                & temp_triplet%point_value
           send_buffer_offsets(p_counter) = send_buffer_offsets(p_counter) + 1
           EXIT
        END IF
     END DO
  END DO
  !! Reset send buffer offsets. But since we're using MPI now, use zero
  !! based indexing.
  send_buffer_offsets(1) = 0
  DO counter = 2, this%process_grid%slice_size
     send_buffer_offsets(counter) = send_buffer_offsets(counter-1) + &
          & send_per_proc(counter-1)
  END DO

  !! Build a receive buffer
  ALLOCATE(recv_per_proc(this%process_grid%slice_size))
  CALL MPI_Alltoall(send_per_proc, 1, MPI_INT, recv_per_proc, 1, MPI_INT, &
       & this%process_grid%within_slice_comm, ierr)
  ALLOCATE(recv_buffer_offsets(this%process_grid%slice_size))
  recv_buffer_offsets(1) = 0
  DO counter = 2, this%process_grid%slice_size
     recv_buffer_offsets(counter) = recv_buffer_offsets(counter-1) + &
          & recv_per_proc(counter-1)
  END DO
  ALLOCATE(recv_buffer_row(SUM(recv_per_proc)))
  ALLOCATE(recv_buffer_col(SUM(recv_per_proc)))
  ALLOCATE(recv_buffer_val(SUM(recv_per_proc)))

  !! Send
  CALL MPI_Alltoallv(send_buffer_row, send_per_proc, send_buffer_offsets, &
       & MPI_INT, recv_buffer_row, recv_per_proc, recv_buffer_offsets, &
       & MPI_INT, this%process_grid%within_slice_comm, ierr)
  CALL MPI_Alltoallv(send_buffer_col, send_per_proc, send_buffer_offsets, &
       & MPI_INT, recv_buffer_col, recv_per_proc, recv_buffer_offsets, &
       & MPI_INT, this%process_grid%within_slice_comm, ierr)
  CALL MPI_Alltoallv(send_buffer_val, send_per_proc, send_buffer_offsets, &
       & MPIDATATYPE, recv_buffer_val, recv_per_proc, recv_buffer_offsets, &
       & MPIDATATYPE, this%process_grid%within_slice_comm, ierr)

  !! Convert receive buffer to triplet list
  CALL ConstructTripletList(triplet_list, SUM(recv_per_proc))
  DO counter=1, SUM(recv_per_proc)
     triplet_list%data(counter)%index_row = recv_buffer_row(counter)
     triplet_list%data(counter)%index_column = recv_buffer_col(counter)
     triplet_list%data(counter)%point_value = recv_buffer_val(counter)
  END DO

  !! Cleanup
  IF (ALLOCATED(row_start_list)) DEALLOCATE(row_start_list)
  IF (ALLOCATED(column_start_list)) DEALLOCATE(column_start_list)
  IF (ALLOCATED(row_end_list)) DEALLOCATE(row_end_list)
  IF (ALLOCATED(column_end_list)) DEALLOCATE(column_end_list)
  IF (ALLOCATED(recv_buffer_offsets)) DEALLOCATE(recv_buffer_offsets)
  IF (ALLOCATED(recv_buffer_val)) DEALLOCATE(recv_buffer_val)
  IF (ALLOCATED(recv_buffer_col)) DEALLOCATE(recv_buffer_col)
  IF (ALLOCATED(recv_buffer_row)) DEALLOCATE(recv_buffer_row)
  IF (ALLOCATED(recv_per_proc)) DEALLOCATE(recv_per_proc)
  IF (ALLOCATED(send_buffer_val)) DEALLOCATE(send_buffer_val)
  IF (ALLOCATED(send_buffer_col)) DEALLOCATE(send_buffer_col)
  IF (ALLOCATED(send_buffer_row)) DEALLOCATE(send_buffer_row)
  IF (ALLOCATED(send_buffer_offsets)) DEALLOCATE(send_buffer_offsets)
  IF (ALLOCATED(send_per_proc)) DEALLOCATE(send_per_proc)
