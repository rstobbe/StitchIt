///==========================================================
/// (v1a)
///		- 
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_AccumBaseImagesWithRcvrs_v11a.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 5) mexErrMsgTxt("Should have 5 inputs");
mwSize *GpuNum,*HComplexMatrixBaseFinal,*HComplexMatrixRcvrProf,*HComplexMatrixBase,*MatSzBase;
GpuNum = mxGetUint64s(prhs[0]);
HComplexMatrixBaseFinal = mxGetUint64s(prhs[1]);
HComplexMatrixRcvrProf = mxGetUint64s(prhs[2]);
HComplexMatrixBase = mxGetUint64s(prhs[3]);
MatSzBase = mxGetUint64s(prhs[4]);

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
AccumBaseImagesWithRcvrs(GpuNum,HComplexMatrixBaseFinal,HComplexMatrixRcvrProf,HComplexMatrixBase,MatSzBase[0],Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

