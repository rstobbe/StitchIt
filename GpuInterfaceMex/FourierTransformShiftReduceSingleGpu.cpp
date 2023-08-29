///==========================================================
/// (v1a)
///		- 
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_FourierTransformShiftReduce_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 6) mexErrMsgTxt("Should have 6 inputs");
mwSize *GpuNum,*HComplexMatrixGrid,*HComplexMatrixBase,*MatSzGrid,*MatSzBase,*Inset;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrixGrid = mxGetUint64s(prhs[1]);
HComplexMatrixBase = mxGetUint64s(prhs[2]);
MatSzGrid = mxGetUint64s(prhs[3]);
MatSzBase = mxGetUint64s(prhs[4]);
Inset = mxGetUint64s(prhs[5]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Cuda           
//-------------------------------------
FFTShiftReduce(GpuNum,HComplexMatrixGrid,HComplexMatrixBase,MatSzGrid[0],MatSzBase[0],Inset[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

