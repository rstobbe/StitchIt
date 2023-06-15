///==========================================================
/// (v1a)
///		- assume isotropic matrix
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_MultiplyMatrixComplexReal_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 4) mexErrMsgTxt("Should have 4 inputs");
mwSize *GpuNum,*HComplexMatrix,*HRealMatrix,*MatrixMemDims;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrix = mxGetUint64s(prhs[1]);
HRealMatrix = mxGetUint64s(prhs[2]);
MatrixMemDims = mxGetUint64s(prhs[3]);

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
MultiplyMatrixComplexReal(GpuNum,HComplexMatrix,HRealMatrix,MatrixMemDims[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

