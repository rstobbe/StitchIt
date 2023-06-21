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
mwSize *GpuNum,*HSampDat,*ChanNum;
float *SampDat;
GpuNum = mxGetUint64s(prhs[0]);
HSampDat = mxGetUint64s(prhs[1]);
SampDat = (float*)mxGetComplexSingles(prhs[2]);
ChanNum = mxGetUint64s(prhs[3]);

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
// Get Dimensions           
//-------------------------------------
const mwSize *temp;
temp = mxGetDimensions(prhs[2]);
mwSize *ArrLen;
ArrLen = (mwSize*)mxCalloc(1,sizeof(mwSize));
ArrLen[0] = temp[0]*temp[1];

//-------------------------------------
// Index Channel           
//-------------------------------------
float *SampDatChanIdx;
SampDatChanIdx = SampDat + (ChanNum[0]-1)*ArrLen[0]*2;

//-------------------------------------
// Load SampDat         
//-------------------------------------
ArrLoadSglOneAsyncC(GpuNum,SampDatChanIdx,HSampDat,ArrLen,Error);

//-------------------------------------
// Return Error                    
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);

}

