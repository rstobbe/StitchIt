///==========================================================
/// (v1a)
///		- 
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_AccumBaseImagesWithConjPhase_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 7) mexErrMsgTxt("Should have 7 inputs");
mwSize *GpuNum,*HComplexMatrixBaseFinal,*HOffResMap,*HComplexMatrixBase,*HSampTim,*SampNum,*MatSzBase;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrixBaseFinal = mxGetUint64s(prhs[1]);
HOffResMap = mxGetUint64s(prhs[2]);
HComplexMatrixBase = mxGetUint64s(prhs[3]);
HSampTim = mxGetUint64s(prhs[4]);
SampNum = mxGetUint64s(prhs[5]);
MatSzBase = mxGetUint64s(prhs[6]);

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
AccumBaseImagesWithConjPhase(GpuNum,HComplexMatrixBaseFinal,HOffResMap,HComplexMatrixBase,HSampTim,SampNum,MatSzBase[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

