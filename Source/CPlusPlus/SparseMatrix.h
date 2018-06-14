#ifndef SparseMatrix_h
#define SparseMatrix_h

#include "Wrapper.h"
#include <string>

////////////////////////////////////////////////////////////////////////////////
namespace NTPoly {
template<class T> class MatrixMemoryPool;
template<class T> class TripletList;
////////////////////////////////////////////////////////////////////////////////
//! A datatype for storing a CSR matrix.
template <class T> class SparseMatrix {
public:
  //! Basic constructor.
  //!\param columns number of columns for the matrix.
  //!\param rows number of rows for the matrix.
  SparseMatrix(int columns, int rows);
  //! Construct from a matrix market file.
  //!\param file_name matrix market file name.
  SparseMatrix(std::string file_name);
  //! Construct from a triplet list.
  //!\param list a list of triplet values to set in the matrix.
  //!\param columns number of columns for the matrix.
  //!\param rows number of rows for the matrix.
  SparseMatrix(const NTPoly::TripletList<T> &list, int rows, int columns);
  //! Copy constructor.
  //!\param matB the matrix to copy from.
  SparseMatrix(const NTPoly::SparseMatrix<T> &matB);

public:
  //! Get the number of rows in a matrix.
  int GetRows() const;
  //! Get the number of columns in a matrix.
  int GetColumns() const;
  //! Extract a row from the matrix into the compressed vector representation.
  //!\param row_number the row to extract
  //!\param row_out the matrix representing that row
  void ExtractRow(int row_number, SparseMatrix<T> &row_out) const;
  //! Extract a column from the matrix into the compressed vector representation
  //!\param column_number the column to extract
  //!\param column_out the matrix representing that column
  void ExtractColumn(int column_number, SparseMatrix<T> &column_out) const;

public:
  //! Scale the matrix by a constant.
  //!\param constant value to scale by.
  void Scale(double constant);
  //! This = alpha*MatrixB + This(AXPY).
  //!\param matB matrix to add.
  //!\param alpha scale for the matrix.
  //!\param threshold for flushing small values.
  void Increment(const NTPoly::SparseMatrix<T> &matB, double alpha,
                 double threshold);
  //! Matrix dot product.
  //!\param matB matrix to dot with.
  //!\result the dot product of this and matB.
  double Dot(const NTPoly::SparseMatrix<T> &matB) const;
  //! Pairwise multiply two sparse matrices.
  //!\param matA
  //!\param matB
  void PairwiseMultiply(const NTPoly::SparseMatrix<T> &matA,
                        const NTPoly::SparseMatrix<T> &matB);
  //! This := alpha*matA*op( matB ) + beta*this
  //!\param matA
  //!\param matB
  //!\param isATransposed true if A is already transposed.
  //!\param isBTransposed true if B is already transposed.
  //!\param alpha scaling value.
  //!\param beta scaling value.
  //!\param threshold for flushing small values.
  //!\param memory_pool a memory pool to use for storing intermediates.
  void Gemm(const NTPoly::SparseMatrix<T> &matA,
            const NTPoly::SparseMatrix<T> &matB, bool isATransposed,
            bool isBTransposed, double alpha, double beta, double threshold,
            NTPoly::MatrixMemoryPool<T> &memory_pool);

public:
  //! Compute the eigen vectors of a matrix.
  //!\param MatV the eigenvectors.
  //!\param threshold for pruning small values.
  void EigenDecomposition(NTPoly::SparseMatrix<T> &MatV, double threshold);

public:
  //! Transpose a sparse matrix.
  //\param matA matrix to compute the transpose of.
  void Transpose(const NTPoly::SparseMatrix<T> &matA);

public:
  //! Print the sparse matrix to the console.
  void Print();
  //! Write the sparse matrix to file.
  //!\param file_name file to print to.
  void WriteToMatrixMarket(std::string file_name);

public:
  //! Compute a triplet list from the entries in a matrix.
  //!\param triplet_list output.
  void MatrixToTripletList(NTPoly::TripletList<T> &triplet_list);

public:
  //! Standard destructor.
  ~SparseMatrix();

private:
  //! Pointer to the underlying data.
  int ih_this[SIZE_wrp];

private:
  //! Assignment operator, locked.
  SparseMatrix &operator=(const SparseMatrix &);
};
} // namespace NTPoly
#endif
