///==========================================================
/// (v1a)
///		- 
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_AccumulateImage_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 7) mexErrMsgTxt("Should have 7 inputs");
mwSize *GpuNum,*HComplexMatrixGrid,*HComplexMatrixRcvrProf,*HComplexMatrixBase,*MatSzGrid,*MatSzBase,*Inset;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrixGrid = mxGetUint64s(prhs[1]);
HComplexMatrixRcvrProf = mxGetUint64s(prhs[2]);
HComplexMatrixBase = mxGetUint64s(prhs[3]);
MatSzGrid = mxGetUint64s(prhs[4]);
MatSzBase = mxGetUint64s(prhs[5]);
Inset = mxGetUint64s(prhs[6]);

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
AccumulateImage(GpuNum,HComplexMatrixGrid,HComplexMatrixRcvrProf,HComplexMatrixBase,MatSzGrid[0],MatSzBase[0],Inset[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

