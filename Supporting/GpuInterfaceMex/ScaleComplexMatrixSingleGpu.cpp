///==========================================================
/// (v1a)
///		- assume isotropic matrix
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_ScaleComplexMatrix_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 4) mexErrMsgTxt("Should have 4 inputs");
mwSize *GpuNum,*HComplexMatrix,*MatrixMemDims;
float *ScaleVal;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrix = mxGetUint64s(prhs[1]);
ScaleVal = mxGetSingles(prhs[2]);
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
ScaleComplexMatrix(GpuNum,HComplexMatrix,ScaleVal,MatrixMemDims[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

