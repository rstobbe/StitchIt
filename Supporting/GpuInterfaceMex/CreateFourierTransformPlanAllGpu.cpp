///==========================================================
/// (v1a)
///		
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_FourierTransform_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 2) mexErrMsgTxt("Should have 2 inputs");
mwSize *GpuTot,*ImageMatrixMemDims;
GpuTot = mxGetUint64s(prhs[0]);
ImageMatrixMemDims = mxGetUint64s(prhs[1]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 2) mexErrMsgTxt("Should have 2 outputs");
mwSize ArrDim[2];

mwSize *HFourierTransformPlan;
ArrDim[0] = 1; 
ArrDim[1] = GpuTot[0]; 
plhs[0] = mxCreateNumericArray(2,ArrDim,mxUINT64_CLASS,mxREAL);
HFourierTransformPlan = mxGetUint64s(plhs[0]);

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Fourier Transform Setup                
//-------------------------------------
unsigned int *HTemp;
HTemp = (unsigned int*)mxCalloc(GpuTot[0],sizeof(unsigned int));
FFT3DSetupAllGpu(GpuTot,HTemp,ImageMatrixMemDims,Error);

for(int n=0;n<GpuTot[0];n++){
    HFourierTransformPlan[n] = (mwSize)HTemp[n];
}

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[1] = mxCreateString(Error);
mxFree(Error);

}

