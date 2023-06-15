///==========================================================
/// (v1a)
///		
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_GeneralSgl_v11f.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 4) mexErrMsgTxt("Should have 4 inputs");
mwSize *GpuNum,*HMatrixTo,*HMatrixFrom,*ImageMatrixMemDims;
GpuNum = mxGetUint64s(prhs[0]);
HMatrixTo = mxGetUint64s(prhs[1]);
HMatrixFrom = mxGetUint64s(prhs[2]);
ImageMatrixMemDims = mxGetUint64s(prhs[3]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");

//-------------------------------------
// Error Initialize                    
//-------------------------------------
char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Load Matrix         
//-------------------------------------
mwSize *ArrLen;
ArrLen = (mwSize*)mxCalloc(1,sizeof(mwSize));
ArrLen[0] = ImageMatrixMemDims[0]*ImageMatrixMemDims[1]*ImageMatrixMemDims[2];
ArrDeviceCopySglOneAsyncC(GpuNum,HMatrixTo,HMatrixFrom,ArrLen,Error);

//-------------------------------------
// Return Error                    
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);

}

