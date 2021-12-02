#ifndef EIGENSOLVERS_h
#define EIGENSOLVERS_h

#include "SolverBase.h"
////////////////////////////////////////////////////////////////////////////////
namespace NTPoly {
class SolverParameters;
class Matrix_ps;
////////////////////////////////////////////////////////////////////////////////
//! A class for computing eigen decompositions matrices.
class EigenSolvers : public SolverBase {
public:
  //! Compute the eigendecomposition of a matrix.
  //! Uses a dense routine.
  //!\param matrix the matrix to decompose.
  //!\param eigenvectors the eigenvectors of a matrix.
  //!\param eigenvalues the eigenvalues of a matrix.
  //!\param solver_parameters parameters for computing.
  static void EigenDecomposition(const Matrix_ps &matrix,
                                 Matrix_ps &eigenvectors,
                                 Matrix_ps &eigenvalues,
                                 const SolverParameters &solver_parameters);
  //! Compute the singular value decomposition of a matrix.
  //! Uses a dense routine.
  //!\param matrix the matrix to decompose.
  //!\param leftvectors the left singular vectors.
  //!\param rightvectors the right singular vectors
  //!\param singularvalues a diagonal matrix containing the singular values.
  //!\param solver_parameters parameters for computing.
  static void
  SingularValueDecomposition(const Matrix_ps &matrix, Matrix_ps &leftvectors,
                             Matrix_ps &rightvectors, Matrix_ps &singularvalues,
                             const SolverParameters &solver_parameters);
};
} // namespace NTPoly
#endif
