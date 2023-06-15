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
if (nrhs != 2) mexErrMsgTxt("Should have 2 inputs");
mwSize *GpuNum,*SampDatMemDims;
GpuNum = mxGetUint64s(prhs[0]);
SampDatMemDims = mxGetUint64s(prhs[1]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 2) mexErrMsgTxt("Should have 2 outputs");
mwSize ArrDim[2];

mwSize *HSampDat;
ArrDim[0] = 1; 
ArrDim[1] = GpuNum[0]; 
plhs[0] = mxCreateNumericArray(2,ArrDim,mxUINT64_CLASS,mxREAL);
HSampDat = mxGetUint64s(plhs[0]);

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Allocate Memory                
//-------------------------------------
mwSize *ArrLen;
ArrLen = (mwSize*)mxCalloc(1,sizeof(mwSize));
ArrLen[0] = SampDatMemDims[0]*SampDatMemDims[1];
ArrAllocSglAllC(GpuNum,HSampDat,ArrLen,Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[1] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);

}

