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
mwSize NumAve;
mxComplexSingle *Data;
float *Weights;
Data = mxGetComplexSingles(prhs[0]);
Weights = mxGetSingles(prhs[1]);
NumAve = (mwSize)mxGetScalar(prhs[2]);

const mwSize *temp;
mwSize NumCol,NumAcq,NumRx,NumTraj;
temp = mxGetDimensions(prhs[0]);
NumAcq = (mwSize)temp[0];
NumCol = (mwSize)temp[1];
NumRx = (mwSize)temp[2];
NumTraj = mwSize(float(NumAcq)/float(NumAve));

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
                Acq = p + i*NumTraj;
                WeightedData[m*NumCol*NumTraj + n*NumTraj + p].real += Weights[p*NumAve + i] * Data[m*NumCol*NumAcq + n*NumAcq + Acq].real;
                WeightedData[m*NumCol*NumTraj + n*NumTraj + p].imag += Weights[p*NumAve + i] * Data[m*NumCol*NumAcq + n*NumAcq + Acq].imag;
            }
        }
    }
}


}

