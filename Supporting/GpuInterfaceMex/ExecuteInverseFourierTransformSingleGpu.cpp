///==========================================================
/// (v1a)
///		
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_FourierTransform_v11a.h"
#include "CUDA_ScaleComplexMatrix_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 5) mexErrMsgTxt("Should have 5 inputs");
mwSize *GpuNum,*HImageMatrix,*HKspaceMatrix,*HFourierTransformPlan,*MatrixMemDims;
GpuNum = mxGetUint64s(prhs[0]);
HImageMatrix = mxGetUint64s(prhs[1]);
HKspaceMatrix = mxGetUint64s(prhs[2]);
HFourierTransformPlan = mxGetUint64s(prhs[3]);
MatrixMemDims = mxGetUint64s(prhs[4]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Get Dimensions           
//-------------------------------------
const mwSize *temp;
temp = mxGetDimensions(prhs[3]);
mwSize *ArrLen;
ArrLen = (mwSize*)mxCalloc(1,sizeof(mwSize));
ArrLen[0] = temp[0]*temp[1];

//-------------------------------------
// Fourier Transform              
//-------------------------------------
unsigned int *HTemp;
HTemp = (unsigned int*)mxCalloc(ArrLen[0],sizeof(unsigned int));
for(int n=0;n<ArrLen[0];n++){ 
    HTemp[n] = (unsigned int)HFourierTransformPlan[n];
}
IFFT3DSglGpu(GpuNum,HImageMatrix,HKspaceMatrix,HTemp,Error);

//-------------------------------------
// Get ScaleVal         
//------------------------------------
float *ScaleVal;
ScaleVal = (float*)mxCalloc(1,sizeof(float));
float MatDim = (float)MatrixMemDims[0];
ScaleVal[0] = 1/(MatDim*MatDim*MatDim);

//-------------------------------------
// IFFT Scale            
//-------------------------------------
ScaleComplexMatrix(GpuNum,HImageMatrix,ScaleVal,MatrixMemDims[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);
mxFree(HTemp);
mxFree(ScaleVal);

}

