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
mwSize *Gpus,*Handle;
Gpus = mxGetUint64s(prhs[0]);
Handle = mxGetUint64s(prhs[1]);

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");
mwSize ArrDim[2];

char *Error;
mwSize errorlen = 200;
Error = (char*)mxCalloc(errorlen,sizeof(char));
strcpy(Error,"no error");

//-------------------------------------
// Free Memory                
//-------------------------------------
ArrFreeSglAll(Gpus,Handle,Error);

//-------------------------------------
// Return                  
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

