///==========================================================
/// (v1a)
///		
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 3) mexErrMsgTxt("Should have 3 inputs");
mxComplexSingle *Data;
float *Weights, *TrajLocAllAcq;
Data = mxGetComplexSingles(prhs[0]);
Weights = mxGetSingles(prhs[1]);
TrajLocAllAcq = mxGetSingles(prhs[2]);

const mwSize *temp;
mwSize NumCol,NumAcq,NumRx,NumTraj,NumAve;
temp = mxGetDimensions(prhs[0]);
NumAcq = (mwSize)temp[0];
NumCol = (mwSize)temp[1];
NumRx = (mwSize)temp[2];
temp = mxGetDimensions(prhs[1]);
NumTraj = (mwSize)temp[0];
NumAve = (mwSize)temp[1];

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 output");

mwSize ArrDim[3];
ArrDim[0] = NumTraj; 
ArrDim[1] = NumCol; 
ArrDim[2] = NumRx; 
plhs[0] = mxCreateNumericArray(3,ArrDim,mxSINGLE_CLASS,mxCOMPLEX);
mxComplexSingle *WeightedData;
WeightedData = mxGetComplexSingles(plhs[0]);

//-------------------------------------
// Weight / Sum Data         
//-------------------------------------
int n,m,p,i;
mwSize Acq;

for (m=0; m<NumRx; m++) { 
    for (n=0; n<NumCol; n++) {    
        for (p=0; p<NumTraj; p++) { 
            for (i=0; i<NumAve; i++) {
                Acq = TrajLocAllAcq[i*NumTraj + p] - 1;
                WeightedData[m*NumCol*NumTraj + n*NumTraj + p].real += Weights[i*NumTraj + p] * Data[m*NumCol*NumAcq + n*NumAcq + Acq].real;
                WeightedData[m*NumCol*NumTraj + n*NumTraj + p].imag += Weights[i*NumTraj + p] * Data[m*NumCol*NumAcq + n*NumAcq + Acq].imag;
            }
        }
    }
}


}

