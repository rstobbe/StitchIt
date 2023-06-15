///==========================================================
/// (v1a)
///		- assume isotropic matrix
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_MultiplyAccumMatrixComplexComplex_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 5) mexErrMsgTxt("Should have 5 inputs");
mwSize *GpuNum,*HComplexMatrix0,*HComplexMatrix1,*HComplexMatrix2,*MatrixMemDims;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrix0 = mxGetUint64s(prhs[1]);
HComplexMatrix1 = mxGetUint64s(prhs[2]);
HComplexMatrix2 = mxGetUint64s(prhs[3]);
MatrixMemDims = mxGetUint64s(prhs[4]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Fourier Transform Shift             
//-------------------------------------
MultiplyAccumMatrixComplexComplex(GpuNum,HComplexMatrix0,HComplexMatrix1,HComplexMatrix2,MatrixMemDims[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

