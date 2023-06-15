///==========================================================
/// (v2a)
///		
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_ConvSamp2GridComplex_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 10) mexErrMsgTxt("Should have 10 inputs");
mwSize *GpuNum,*HSampDat,*HReconInfo,*HKernel,*HImageMatrix;
mwSize *SampDatMemDims,*KernelMemDims,*ImageMatrixMemDims;        
mwSize *iKern,*KernHw;
GpuNum = mxGetUint64s(prhs[0]);
HSampDat = mxGetUint64s(prhs[1]);
HReconInfo = mxGetUint64s(prhs[2]);
HKernel = mxGetUint64s(prhs[3]);
HImageMatrix = mxGetUint64s(prhs[4]);
SampDatMemDims = mxGetUint64s(prhs[5]);
KernelMemDims = mxGetUint64s(prhs[6]);
ImageMatrixMemDims = mxGetUint64s(prhs[7]);
iKern = mxGetUint64s(prhs[8]);
KernHw = mxGetUint64s(prhs[9]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Grid Data           
//-------------------------------------
ConvSamp2GridComplex(GpuNum,HSampDat,HReconInfo,HKernel,HImageMatrix,SampDatMemDims,KernelMemDims,ImageMatrixMemDims,iKern,KernHw,Error);

//-------------------------------------
// Return Error                    
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

