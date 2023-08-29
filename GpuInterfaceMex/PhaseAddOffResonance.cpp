///==========================================================
/// (v1a)
///		
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "CUDA_PhaseAddOffRes_v11b.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 7) mexErrMsgTxt("Should have 7 inputs");
mwSize *GpuNum,*HBaseHoldImageMatrix,*HOffResMatrix,*HBaseImageMatrix,*HSampTim;
mwSize *SampNum,*ImageMatrixMemDims;
GpuNum = mxGetUint64s(prhs[0]);
HBaseHoldImageMatrix = mxGetUint64s(prhs[1]);
HOffResMatrix = mxGetUint64s(prhs[2]);
HBaseImageMatrix = mxGetUint64s(prhs[3]);
HSampTim = mxGetUint64s(prhs[4]);
SampNum = mxGetUint64s(prhs[5]);
ImageMatrixMemDims = mxGetUint64s(prhs[6]);
        
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
// PhaseAddOffRes      
//-------------------------------------
PhaseAddOffRes(GpuNum,HBaseHoldImageMatrix,HOffResMatrix,HBaseImageMatrix,HSampTim,SampNum,ImageMatrixMemDims,Error);

//-------------------------------------
// Return Error                    
//------------------------------------- 
plhs[0] = mxCreateString(Error);
mxFree(Error);

}

