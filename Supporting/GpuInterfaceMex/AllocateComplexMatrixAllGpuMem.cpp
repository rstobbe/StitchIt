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
mwSize *Gpus,*ImageMatrixMemDims;
Gpus = mxGetUint64s(prhs[0]);
ImageMatrixMemDims = mxGetUint64s(prhs[1]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 2) mexErrMsgTxt("Should have 2 outputs");
mwSize ArrDim[2];

mwSize *HImageMatrix;
ArrDim[0] = 1; 
ArrDim[1] = Gpus[0]; 
plhs[0] = mxCreateNumericArray(2,ArrDim,mxUINT64_CLASS,mxREAL);
HImageMatrix = mxGetUint64s(plhs[0]);

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Allocate Memory                
//-------------------------------------
mwSize *ArrLen;
ArrLen = (mwSize*)mxCalloc(1,sizeof(mwSize));
ArrLen[0] = ImageMatrixMemDims[0]*ImageMatrixMemDims[1]*ImageMatrixMemDims[2];
ArrAllocSglAllC(Gpus,HImageMatrix,ArrLen,Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[1] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);

}

