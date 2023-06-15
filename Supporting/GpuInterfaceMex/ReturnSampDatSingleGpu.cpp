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
if (nrhs != 3) mexErrMsgTxt("Should have 3 inputs");
mwSize *GpuNum,*HSampDat,*SampDatMemDims;

GpuNum = mxGetUint64s(prhs[0]);
HSampDat = mxGetUint64s(prhs[1]);
SampDatMemDims = mxGetUint64s(prhs[2]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 2) mexErrMsgTxt("Should have 2 outputs");

mwSize ArrDim[2];
ArrDim[0] = SampDatMemDims[0]; 
ArrDim[1] = SampDatMemDims[1]; 
plhs[0] = mxCreateNumericArray(2,ArrDim,mxSINGLE_CLASS,mxCOMPLEX);
float *SampDat;
SampDat = (float*)mxGetComplexSingles(plhs[0]);

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Return Memory                
//-------------------------------------
mwSize *ArrLen;
ArrLen = (mwSize*)mxCalloc(1,sizeof(mwSize));
ArrLen[0] = SampDatMemDims[0]*SampDatMemDims[1];
ArrLen[1] = 0;
ArrReturnSglOneAsyncC(GpuNum,SampDat,HSampDat,ArrLen,Error);

//-------------------------------------
// Return Error                    
//------------------------------------- 
plhs[1] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);

}

