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
mwSize *GpuNum,*HMatrix;
float *Matrix;
GpuNum = mxGetUint64s(prhs[0]);
HMatrix = mxGetUint64s(prhs[1]);
Matrix = (float*)mxGetComplexSingles(prhs[2]);

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
ArrLen[0] = temp[0]*temp[1]*temp[2];

//-------------------------------------
// Load Matrix         
//-------------------------------------
ArrLoadSglOneAsyncC(GpuNum,Matrix,HMatrix,ArrLen,Error);
if (strcmp(Error,"no error") != 0) {
	plhs[0] = mxCreateString(Error); return;
	}

//-------------------------------------
// Return Error                    
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);
mxFree(ArrLen);

}

