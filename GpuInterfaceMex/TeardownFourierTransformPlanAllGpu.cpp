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
mwSize *GpuTot,*HFourierTransformPlan;
GpuTot = mxGetUint64s(prhs[0]);
HFourierTransformPlan = mxGetUint64s(prhs[1]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Fourier Transform              
//-------------------------------------
unsigned int *HTemp;
HTemp = (unsigned int*)mxCalloc(GpuTot[0],sizeof(unsigned int));
for(int n=0;n<GpuTot[0];n++){
    HTemp[n] = (unsigned int)HFourierTransformPlan[n];
}

FFT3DTeardownAllGpu(GpuTot,HTemp,Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

