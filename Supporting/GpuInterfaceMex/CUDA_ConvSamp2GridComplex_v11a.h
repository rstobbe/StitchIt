///==========================================================
/// (v2a)
///		
///==========================================================

extern "C" void ConvSamp2GridComplex(mwSize *GpuNum, mwSize *HSampDat, mwSize *HReconInfo, mwSize *HKernel, mwSize *HImageMatrix,
                                        mwSize *SampDatMemDims, mwSize *KernelMemDims, mwSize *ImageMatrixMemDims, 
                                        mwSize *iKern, mwSize *KernHw, char *Error);