!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!> Module for load balancing the matrix multiplication calculation.
MODULE LoadBalancerModule
  USE DistributedMatrixMemoryPoolModule
  USE DistributedSparseMatrixModule
  USE PermutationModule
  IMPLICIT NONE
  PRIVATE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  PUBLIC :: PermuteMatrix
  PUBLIC :: UndoPermuteMatrix
CONTAINS
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Apply a permutation to a matrix.
  !! @param[in] mat_in matrix to permute.
  !! @param[out] mat_out permuted matrix.
  !! @param[in] permutation to apply.
  !! @param[inout] memorypool_in memory pool to use. Optional.
  SUBROUTINE PermuteMatrix(mat_in, mat_out, permutation, memorypool_in)
    !! Parameters
    TYPE(DistributedSparseMatrix_t), INTENT(in) :: mat_in
    TYPE(DistributedSparseMatrix_t), INTENT(inout) :: mat_out
    TYPE(Permutation_t), INTENT(in) :: permutation
    TYPE(DistributedMatrixMemoryPool_t), INTENT(inout),OPTIONAL :: memorypool_in
    !! Local Variables
    TYPE(DistributedSparseMatrix_t) :: PermuteRows, PermuteColumns
    TYPE(DistributedSparseMatrix_t) :: Temp

    CALL ConstructEmptyDistributedSparseMatrix(PermuteRows, &
         & mat_in%actual_matrix_dimension)
    CALL ConstructEmptyDistributedSparseMatrix(PermuteColumns, &
         & mat_in%actual_matrix_dimension)
    CALL FillDistributedPermutation(PermuteRows, permutation%index_lookup, &
         & permuterows=.TRUE.)
    CALL FillDistributedPermutation(PermuteColumns, permutation%index_lookup, &
         & permuterows=.FALSE.)
    CALL ConstructEmptyDistributedSparseMatrix(Temp, &
         mat_in%actual_matrix_dimension)

    !! Permute Matrices.
    IF (PRESENT(memorypool_in)) THEN
       CALL DistributedGemm(PermuteRows, mat_in, Temp, &
            & memory_pool_in=memorypool_in)
       CALL DistributedGemm(Temp, PermuteColumns, mat_out, &
            & memory_pool_in=memorypool_in)
    ELSE
       CALL DistributedGemm(PermuteRows, mat_in, Temp)
       CALL DistributedGemm(Temp, PermuteColumns, mat_out)
    END IF

    CALL DestructDistributedSparseMatrix(PermuteRows)
    CALL DestructDistributedSparseMatrix(PermuteColumns)
    CALL DestructDistributedSparseMatrix(Temp)
  END SUBROUTINE PermuteMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Undo a permutation applied to a matrix.
  !! @param[in] mat_in matrix to undo permutation of.
  !! @param[out] mat_out unpermuted matrix.
  !! @param[in] permutation to remove.
  !! @param[inout] memorypool_in memory pool to use. Optional.
  SUBROUTINE UndoPermuteMatrix(mat_in, mat_out, permutation, memorypool_in)
    !! Parameters
    TYPE(DistributedSparseMatrix_t), INTENT(in) :: mat_in
    TYPE(DistributedSparseMatrix_t), INTENT(inout) :: mat_out
    TYPE(Permutation_t), INTENT(in) :: permutation
    TYPE(DistributedMatrixMemoryPool_t), INTENT(inout),OPTIONAL :: memorypool_in
    !! Local Variables
    TYPE(DistributedSparseMatrix_t) :: PermuteRows, PermuteColumns
    TYPE(DistributedSparseMatrix_t) :: Temp

    !! Build Permutation Matrices
    CALL ConstructEmptyDistributedSparseMatrix(PermuteRows, &
         & mat_in%actual_matrix_dimension)
    CALL ConstructEmptyDistributedSparseMatrix(PermuteColumns, &
         mat_in%actual_matrix_dimension)
    CALL FillDistributedPermutation(PermuteRows, permutation%index_lookup, &
         & permuterows=.TRUE.)
    CALL FillDistributedPermutation(PermuteColumns, permutation%index_lookup, &
         & permuterows=.FALSE.)
    CALL ConstructEmptyDistributedSparseMatrix(Temp, &
         & mat_in%actual_matrix_dimension)

    !! Permute Matrices.
    IF (PRESENT(memorypool_in)) THEN
       CALL DistributedGemm(PermuteColumns, mat_in, Temp, &
            & memory_pool_in=memorypool_in)
       CALL DistributedGemm(Temp, PermuteRows, mat_out, &
            & memory_pool_in=memorypool_in)
    ELSE
       CALL DistributedGemm(PermuteColumns, mat_in, Temp)
       CALL DistributedGemm(Temp, PermuteRows, mat_out)
    END IF

    !! Cleanup
    CALL DestructDistributedSparseMatrix(PermuteRows)
    CALL DestructDistributedSparseMatrix(PermuteColumns)
    CALL DestructDistributedSparseMatrix(Temp)
  END SUBROUTINE UndoPermuteMatrix
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
END MODULE LoadBalancerModule