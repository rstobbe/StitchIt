///==========================================================
/// (v1a)
///		- assume isotropic matrix
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_ConjugateComplexMatrix_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 3) mexErrMsgTxt("Should have 3 inputs");
mwSize *GpuNum,*HComplexMatrix,*MatrixMemDims;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrix = mxGetUint64s(prhs[1]);
MatrixMemDims = mxGetUint64s(prhs[2]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Get Complex Conjugate           
//-------------------------------------
ConjugateComplexMatrix(GpuNum,HComplexMatrix,MatrixMemDims[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

