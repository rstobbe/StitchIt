///==========================================================
/// (v1a)
///		- 
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_ReturnFov_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 6) mexErrMsgTxt("Should have 6 inputs");
mwSize *GpuNum,*HComplexMatrixBig,*HComplexMatrixSmall,*MatSzBig,*MatSzSmall,*Inset;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrixBig = mxGetUint64s(prhs[1]);
HComplexMatrixSmall = mxGetUint64s(prhs[2]);
MatSzBig = mxGetUint64s(prhs[3]);
MatSzSmall = mxGetUint64s(prhs[4]);
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
ReturnFov(GpuNum,HComplexMatrixBig,HComplexMatrixSmall,MatSzBig[0],MatSzSmall[0],Inset[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

