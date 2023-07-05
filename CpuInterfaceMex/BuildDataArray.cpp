///==========================================================
/// (v1a)
///		
///==========================================================

#include "mex.h"
#include "matrix.h"
#include "math.h"
#include "string.h"
#include "stdio.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[])
{

//-------------------------------------
// Input                        
//-------------------------------------
if (nrhs != 3) mexErrMsgTxt("Should have 3 inputs");
char *DataFile;
size_t buflen;
buflen = mxGetN(prhs[0]) + 1;
DataFile = (char*)mxMalloc(buflen);
mxGetString(prhs[0],DataFile,(mwSize)buflen);

unsigned long long *DataMemPosArr;
DataMemPosArr = mxGetUint64s(prhs[1]);
const mwSize *temp;
temp = mxGetDimensions(prhs[1]);
mwSize DataMemPosArrLen;
DataMemPosArrLen = temp[0]*temp[1];

mwSize *DataInfo;
DataInfo = mxGetUint64s(prhs[2]);
mwSize DataReadSize,DataStart,DataCol,DataCha,DataBlockSize;
DataReadSize = 2*DataInfo[0];
DataStart = 2*(DataInfo[1]-1);
DataCol = 2*DataInfo[2];
DataCha = DataInfo[3];
DataBlockSize = DataInfo[4];

//-------------------------------------
// Output                       
//-------------------------------------
if (nlhs != 1) mexErrMsgTxt("Should have 1 outputs");
mwSize ArrDim[3];
ArrDim[0] = DataCol; 
ArrDim[1] = DataBlockSize;
ArrDim[2] = DataCha;
plhs[0] = mxCreateNumericArray(3,ArrDim,mxSINGLE_CLASS,mxREAL);
float *Data;
Data = (float*)mxGetSingles(plhs[0]);

//-------------------------------------
// Open File                   
//-------------------------------------
FILE *pFile;
pFile = fopen(DataFile,"rb");
if (pFile==NULL) {
    mexPrintf("File Not Opened\n");
    mxFree(DataFile);
    return;
}

//-------------------------------------
// Read From File                     
//-------------------------------------
float *ReadArray;
ReadArray = (float*)mxMalloc(sizeof(float)*DataReadSize*DataCha);
for (int i=0;i<DataMemPosArrLen;i++){
    _fseeki64(pFile,DataMemPosArr[i],SEEK_SET);
    fread(ReadArray,sizeof(float),DataReadSize*DataCha,pFile);
    for (int j=0;j<DataCha;j++){
        for (int k=0;k<DataCol;k++){
            Data[(j*DataCol*DataBlockSize)+(i*DataCol)+k] = ReadArray[(j*DataReadSize)+DataStart+k];
        }
    }    
}

fclose (pFile);
mxFree(DataFile);
mxFree(ReadArray);

}