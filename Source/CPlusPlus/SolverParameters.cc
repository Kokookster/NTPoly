#include "Permutation.h"
#include "SolverParameters.h"

////////////////////////////////////////////////////////////////////////////////
extern "C" {
#include "SolverParameters_c.h"
}

////////////////////////////////////////////////////////////////////////////////
namespace NTPoly {
////////////////////////////////////////////////////////////////////////////////
SolverParameters::SolverParameters() { ConstructSolverParameters_wrp(ih_this); }

////////////////////////////////////////////////////////////////////////////////
SolverParameters::~SolverParameters() { DestructSolverParameters_wrp(ih_this); }

////////////////////////////////////////////////////////////////////////////////
void SolverParameters::SetConvergeDiff(double new_value) {
  SetParametersConvergeDiff_wrp(ih_this, &new_value);
}

////////////////////////////////////////////////////////////////////////////////
void SolverParameters::SetMaxIterations(int new_value) {
  SetParametersMaxIterations_wrp(ih_this, &new_value);
}

////////////////////////////////////////////////////////////////////////////////
void SolverParameters::SetVerbosity(bool new_value) {
  SetParametersBeVerbose_wrp(ih_this, &new_value);
}

////////////////////////////////////////////////////////////////////////////////
void SolverParameters::SetThreshold(double new_value) {
  SetParametersThreshold_wrp(ih_this, &new_value);
}

////////////////////////////////////////////////////////////////////////////////
void SolverParameters::SetDACBaseSize(int new_value) {
  SetParametersDACBaseSize_wrp(ih_this, &new_value);
}

////////////////////////////////////////////////////////////////////////////////
void SolverParameters::SetDACBaseSparsity(double new_value) {
  SetParametersDACBaseSparsity_wrp(ih_this, &new_value);
}

////////////////////////////////////////////////////////////////////////////////
void SolverParameters::SetLoadBalance(const Permutation &new_value) {
  SetParametersLoadBalance_wrp(ih_this, new_value.ih_this);
}
} // namespace NTPoly