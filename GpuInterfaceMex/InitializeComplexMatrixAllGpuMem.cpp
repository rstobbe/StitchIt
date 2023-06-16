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
mwSize *Gpus,*HImageMatrix,*ImageMatrixMemDims;
Gpus = mxGetUint64s(prhs[0]);
HImageMatrix = mxGetUint64s(prhs[1]);
ImageMatrixMemDims = mxGetUint64s(prhs[2]);

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
// Initialize Memory                
//-------------------------------------
mwSize *ArrLen;
ArrLen = (mwSize*)mxCalloc(1,sizeof(mwSize));
ArrLen[0] = ImageMatrixMemDims[0]*ImageMatrixMemDims[1]*ImageMatrixMemDims[2];
ArrInitSglAllC(Gpus,HImageMatrix,ArrLen,Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);

}

