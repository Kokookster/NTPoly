  IMPLICIT NONE
  PRIVATE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> A datatype for storing a dense matrix.
  TYPE, PUBLIC :: DMTYPE
     DATATYPE, DIMENSION(:,:), ALLOCATABLE :: DATA !< values of the matrix
     INTEGER :: rows !< Matrix dimension: rows
     INTEGER :: columns !< Matrix dimension: columns
  END TYPE DMTYPE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  PUBLIC :: ConstructEmptyDenseMatrix
  PUBLIC :: ConstructDenseFromSparse
  PUBLIC :: ConstructSparseFromDense
  PUBLIC :: CopyDenseMatrix
  PUBLIC :: DestructDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  PUBLIC :: SplitDenseMatrix
  PUBLIC :: ComposeDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  PUBLIC :: DenseEigenDecomposition
  PUBLIC :: DenseMatrixNorm
  PUBLIC :: IncrementDenseMatrix
  PUBLIC :: MultiplyDense
  PUBLIC :: TransposeDenseMatrix
CONTAINS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Construct an empty dense matrix with a set number of rows and columns
  PURE SUBROUTINE ConstructEmptyDenseMatrix(this, columns, rows)
    !! Parameters
    TYPE(DMTYPE), INTENT(INOUT) :: this
    INTEGER, INTENT(IN) :: rows
    INTEGER, INTENT(IN) :: columns

    this%rows = rows
    this%columns = columns

    !! Check if the memory is already useful
    IF (ALLOCATED(this%data)) THEN
       IF (SIZE(this%data,1) .NE. rows .OR. SIZE(this%data,2) .NE. columns) THEN
          CALL DestructDenseMatrix(this)
          ALLOCATE(this%data(rows,columns))
       END IF
    ELSE
       ALLOCATE(this%data(rows,columns))
    END IF

  END SUBROUTINE ConstructEmptyDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> A function that converts a sparse matrix to a dense matrix.
  !! @param[in] sparse_matrix a sparse matrix to convert.
  !! @param[inout] dense_matrix output. Must be preallocated.
  PURE SUBROUTINE ConstructDenseFromSparse(sparse_matrix, dense_matrix)
    !! Parameters
    TYPE(SMTYPE), INTENT(IN) :: sparse_matrix
    TYPE(DMTYPE), INTENT(INOUT) :: dense_matrix
    !! Helper Variables
    INTEGER :: inner_counter, outer_counter
    INTEGER :: elements_per_inner
    INTEGER :: total_counter
    TYPE(TTYPE) :: temporary

    CALL ConstructEmptyDenseMatrix(dense_matrix,sparse_matrix%columns, &
         & sparse_matrix%rows)

    !! Loop over elements.
    dense_matrix%data = 0
    total_counter = 1
    DO outer_counter = 1, sparse_matrix%columns
       elements_per_inner = sparse_matrix%outer_index(outer_counter+1) - &
            & sparse_matrix%outer_index(outer_counter)
       temporary%index_column = outer_counter
       DO inner_counter = 1, elements_per_inner
          temporary%index_row = sparse_matrix%inner_index(total_counter)
          temporary%point_value = sparse_matrix%values(total_counter)
          dense_matrix%data(temporary%index_row, temporary%index_column) = &
               & temporary%point_value
          total_counter = total_counter + 1
       END DO
    END DO
  END SUBROUTINE ConstructDenseFromSparse
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> A function that converts a dense matrix to a sparse matrix.
  !! @param[in] dense_matrix to convert.
  !! @param[out] sparse_matrix output matrix.
  !! @param[in] threshold_in value for pruning values to zero.
  PURE SUBROUTINE ConstructSparseFromDense(dense_matrix, sparse_matrix, &
       & threshold_in)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: dense_matrix
    TYPE(SMTYPE), INTENT(INOUT) :: sparse_matrix
    REAL(NTREAL), INTENT(IN), OPTIONAL :: threshold_in
    !! Local Variables
    INTEGER :: inner_counter, outer_counter
    TYPE(TTYPE) :: temporary
    TYPE(TLISTTYPE) :: temporary_list
    INTEGER :: columns, rows

    columns = dense_matrix%columns
    rows = dense_matrix%rows

    IF (PRESENT(threshold_in)) THEN
       CALL ConstructTripletList(temporary_list)
       DO outer_counter = 1, columns
          temporary%index_column = outer_counter
          DO inner_counter = 1, rows
             temporary%point_value = &
                  & dense_matrix%data(inner_counter,outer_counter)
             IF (ABS(temporary%point_value) .GT. threshold_in) THEN
                temporary%index_row = inner_counter
                CALL AppendToTripletList(temporary_list,temporary)
             END IF
          END DO
       END DO
    ELSE
       CALL ConstructTripletList(temporary_list, rows*columns)
       DO outer_counter = 1, columns
          temporary%index_column = outer_counter
          DO inner_counter = 1, rows
             temporary%point_value = &
                  & dense_matrix%data(inner_counter,outer_counter)
             temporary%index_row = inner_counter
             temporary_list%data(inner_counter+rows*(outer_counter-1)) = &
                  & temporary
          END DO
       END DO
    END IF

    CALL ConstructFromTripletList(sparse_matrix, temporary_list, rows, columns)
  END SUBROUTINE ConstructSparseFromDense
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Copy the matrix A into the B.
  !! @param[in] matA the matrix to copy.
  !! @param[inout] matB = matA
  PURE SUBROUTINE CopyDenseMatrix(matA, matB)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: matA
    TYPE(DMTYPE), INTENT(INOUT) :: matB

    CALL ConstructEmptyDenseMatrix(matB,matA%columns,matA%rows)
    matB%data = matA%data
  END SUBROUTINE CopyDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Deallocate the memory associated with this matrix.
  !! @param[inout] this the matrix to delete.
  PURE SUBROUTINE DestructDenseMatrix(this)
    !! Parameters
    TYPE(DMTYPE), INTENT(INOUT) :: this

    IF (ALLOCATED(this%data)) THEN
       DEALLOCATE(this%data)
    END IF
  END SUBROUTINE DestructDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> A wrapper for multiplying two dense matrices.
  !! @param[in] MatA the first matrix.
  !! @param[in] MatB the second matrix.
  !! @param[inout] MatC = MatA*MatB.
  SUBROUTINE MultiplyDense(MatA,MatB,MatC)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: MatA
    TYPE(DMTYPE), INTENT(IN) :: MatB
    TYPE(DMTYPE), INTENT(INOUT) :: MatC
    !! Local variables
    CHARACTER, PARAMETER :: TRANSA = 'N'
    CHARACTER, PARAMETER :: TRANSB = 'N'
    INTEGER :: M
    INTEGER :: N
    INTEGER :: K
    DOUBLE PRECISION, PARAMETER :: ALPHA = 1.0
    INTEGER :: LDA
    INTEGER :: LDB
    DOUBLE PRECISION, PARAMETER :: BETA = 0.0
    INTEGER :: LDC

    CALL ConstructEmptyDenseMatrix(MatC,MatB%columns,MatA%rows)

    !! Setup Lapack
    M = MatA%rows
    N = MatB%columns
    K = MatA%columns
    LDA = M
    LDB = K
    LDC = M

    CALL DGEMM(TRANSA, TRANSB, M, N, K, ALPHA, MatA%data, LDA, MatB%data, &
         & LDB, BETA, MatC%data, LDC)

  END SUBROUTINE MultiplyDense
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> AXPY for dense matrices. B = B + alpha*A
  !! @param[in] MatA is added
  !! @param[inout] MatB is incremented.
  !! @param[in] alpha_in a scaling parameter (optional).
  PURE SUBROUTINE IncrementDenseMatrix(MatA,MatB,alpha_in)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: MatA
    TYPE(DMTYPE), INTENT(INOUT) :: MatB
    REAL(NTREAL), OPTIONAL, INTENT(IN) :: alpha_in
    !! Temporary
    REAL(NTREAL) :: alpha

    !! Process Optional Parameters
    IF (.NOT. PRESENT(alpha_in)) THEN
       alpha = 1.0d+0
    ELSE
       alpha = alpha_in
    END IF

    MatB%data = MatB%data + alpha*MatA%data
  END SUBROUTINE IncrementDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Compute the eigenvectors of a dense matrix.
  !! Wraps a standard dense linear algebra routine.
  !! @param[in] MatA the matrix to decompose.
  !! @param[out] MatV the eigenvectors.
  !! @param[out] MatV the eigenvalues.
  SUBROUTINE DenseEigenDecomposition(MatA, MatV, MatW)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: MatA
    TYPE(DMTYPE), INTENT(INOUT) :: MatV
    TYPE(DMTYPE), INTENT(INOUT), OPTIONAL :: MatW
    !! Local variables
    CHARACTER, PARAMETER :: job = 'V', uplo = 'U'
    INTEGER :: N, LDA
    DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: W
    DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: WORK
    DOUBLE PRECISION :: WORKTEMP
    INTEGER :: LWORK
    INTEGER, DIMENSION(:), ALLOCATABLE :: IWORK
    INTEGER :: IWORKTEMP
    INTEGER :: LIWORK
    INTEGER :: INFO
    INTEGER :: II

    CALL ConstructEmptyDenseMatrix(MatV,MatA%columns,MatA%rows)
    MatV%data = MatA%data

    N = SIZE(MatA%data,DIM=1)
    LDA = N

    !! Allocations
    ALLOCATE(W(N))

    !! Determine the scratch space size
    LWORK = -1
    CALL DSYEVD(JOB, UPLO, N, MatA%data, LDA, W, WORKTEMP, LWORK, IWORKTEMP, &
         & LIWORK, INFO)
    N = LDA
    LWORK = INT(WORKTEMP)
    ALLOCATE(WORK(LWORK))
    LIWORK = INT(IWORKTEMP)
    ALLOCATE(IWORK(LIWORK))

    !! Run Lapack For Real
    CALL DSYEVD(JOB, UPLO, N, MatV%data, LDA, W, WORK, LWORK, IWORK, LIWORK, &
         & INFO)

    !! Extract Eigenvalues
    IF (PRESENT(MatW)) THEN
      CALL ConstructEmptyDenseMatrix(MatW,1,MatA%rows)
      DO II = 1, N
        MatW%data(II,1) = W(II)
      END DO
    END IF

    !! Cleanup
    DEALLOCATE(W)
    DEALLOCATE(Work)

  END SUBROUTINE DenseEigenDecomposition
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Compute the norm of a dense matrix.
  !! Computes the Frobenius norm.
  !! @param[in] this the matrix to compute the norm of.
  !! @result the norm of the matrix.
  FUNCTION DenseMatrixNorm(this) RESULT(norm)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: this
    REAL(NTREAL) :: norm
    !! Local Variables
    CHARACTER, PARAMETER :: NORMC = 'F'
    DOUBLE PRECISION, DIMENSION(this%rows) :: WORK
    INTEGER :: M, N, LDA
    !! Externel
    DOUBLE PRECISION, EXTERNAL :: dlange

    M = this%rows
    N = this%columns
    LDA = this%rows
    norm = DLANGE(NORMC, M, N, this%data, LDA, WORK)
  END FUNCTION DenseMatrixNorm
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Transpose a dense matrix.
  !! @param[in] matA the matrix to transpose.
  !! @param[inout] matAT = matA^T.
  PURE SUBROUTINE TransposeDenseMatrix(matA, matAT)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: matA
    TYPE(DMTYPE), INTENT(INOUT) :: matAT

    CALL ConstructEmptyDenseMatrix(matAT,matA%rows,matA%columns)
    matAT%data = TRANSPOSE(matA%data)
  END SUBROUTINE TransposeDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Create a big matrix from an array of matrices by putting them one next
  !! to another.
  !! @param[in] mat_array 2d array of matrices to compose.
  !! @param[in] block_rows the number of rows of the array of blocks.
  !! @param[in] block_columns the number of columns of the array of blocks.
  !! @param[out] out_matrix the composed matrix.
  PURE SUBROUTINE ComposeDenseMatrix(mat_array, block_rows, block_columns, &
       & out_matrix)
    !! Parameters
    TYPE(DMTYPE), DIMENSION(block_rows, block_columns), INTENT(IN) :: &
         & mat_array
    INTEGER, INTENT(IN) :: block_rows, block_columns
    TYPE(DMTYPE), INTENT(INOUT) :: out_matrix
    !! Local Data
    INTEGER, DIMENSION(block_rows+1) :: row_offsets
    INTEGER, DIMENSION(block_columns+1) :: column_offsets
    INTEGER :: out_rows, out_columns
    INTEGER :: II, JJ

    !! Determine the size of the big matrix
    out_columns = 0
    column_offsets(1) = 1
    out_columns = 0
    DO JJ = 1, block_columns
       column_offsets(JJ+1) = column_offsets(JJ) + mat_array(1,JJ)%columns
       out_columns = out_columns + mat_array(1,JJ)%columns
    END DO
    row_offsets(1) = 1
    out_rows = 0
    DO II = 1, block_rows
       row_offsets(II+1) = row_offsets(II) + mat_array(II,1)%rows
       out_rows = out_rows + mat_array(II,1)%rows
    END DO

    !! Allocate Memory
    CALL ConstructEmptyDenseMatrix(out_matrix, out_columns, out_rows)

    DO JJ = 1, block_columns
       DO II = 1, block_rows
          out_matrix%data(row_offsets(II):row_offsets(II+1)-1, &
               & column_offsets(JJ):column_offsets(JJ+1)-1) = &
               & mat_array(II,JJ)%data
       END DO
    END DO
  END SUBROUTINE ComposeDenseMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Split a sparse matrix into an array of sparse matrices.
  !! @param[in] this the matrix to split.
  !! @param[in] block_rows number of rows to split the matrix into.
  !! @param[in] block_columns number of columns to split the matrix into.
  !! @param[out] split_array a COLUMNxROW array for the output to go into.
  !! @param[in] block_size_row_in specifies the size of the  rows.
  !! @param[in] block_size_column_in specifies the size of the columns.
  PURE SUBROUTINE SplitDenseMatrix(this, block_rows, block_columns, &
       & split_array, block_size_row_in, block_size_column_in)
    !! Parameters
    TYPE(DMTYPE), INTENT(IN) :: this
    INTEGER, INTENT(IN) :: block_rows, block_columns
    TYPE(DMTYPE), DIMENSION(:,:), INTENT(INOUT) :: split_array
    INTEGER, DIMENSION(:), INTENT(IN), OPTIONAL :: block_size_row_in
    INTEGER, DIMENSION(:), INTENT(IN), OPTIONAL :: block_size_column_in
    !! Local Data
    INTEGER, DIMENSION(block_rows) :: block_size_row
    INTEGER, DIMENSION(block_columns) :: block_size_column
    INTEGER, DIMENSION(block_rows+1) :: row_offsets
    INTEGER, DIMENSION(block_columns+1) :: column_offsets
    !! Temporary Variables
    INTEGER :: divisor_row, divisor_column
    INTEGER :: II, JJ

    !! Calculate the split sizes
    IF (PRESENT(block_size_row_in)) THEN
       block_size_row = block_size_row_in
    ELSE
       divisor_row = this%rows/block_rows
       block_size_row = divisor_row
       block_size_row(block_rows) = this%rows - divisor_row*(block_rows-1)
    END IF
    IF (PRESENT(block_size_column_in)) THEN
       block_size_column = block_size_column_in
    ELSE
       divisor_column = this%columns/block_columns
       block_size_column = divisor_column
       block_size_column(block_columns) = this%columns - &
            & divisor_column*(block_columns-1)
    END IF

    !! Copy the block offsets
    row_offsets(1) = 1
    DO II = 1, block_rows
       row_offsets(II+1) = row_offsets(II) + block_size_row(II)
    END DO
    column_offsets(1) = 1
    DO JJ = 1, block_columns
       column_offsets(JJ+1) = column_offsets(JJ) + block_size_column(JJ)
    END DO

    !! Copy
    DO JJ = 1, block_columns
       DO II = 1, block_rows
          CALL ConstructEmptyDenseMatrix(split_array(II,JJ), &
               & block_size_column(JJ), block_size_row(II))
          split_array(II,JJ)%data = &
               & this%data(row_offsets(II):row_offsets(II+1)-1, &
               & column_offsets(JJ):column_offsets(JJ+1)-1)
       END DO
    END DO

  END SUBROUTINE SplitDenseMatrix