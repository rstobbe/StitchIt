///==========================================================
/// 
///==========================================================

extern "C" void FFT3DSetupSglGpu(mwSize *GpuNum, unsigned int *HPlan, mwSize *MatSz, char *Error);
extern "C" void FFT3DSetupAllGpu(mwSize *GpuTot, unsigned int *HPlan, mwSize *MatSz, char *Error);
extern "C" void FFT3DAllGpu(mwSize *GpuTot, mwSize *HdIm, mwSize *HdkDat, unsigned int *HPlan, char *Error);
extern "C" void FFT3DSglGpu(mwSize *GpuNum, mwSize *HdIm, mwSize *HdkDat, unsigned int *HPlan, char *Error);
extern "C" void IFFT3DAllGpu(mwSize *GpuTot, mwSize *HdIm, mwSize *HdkDat, unsigned int *HPlan, char *Error);
extern "C" void IFFT3DSglGpu(mwSize *GpuNum, mwSize *HdIm, mwSize *HdkDat, unsigned int *HPlan, char *Error);
extern "C" void FFT3DTeardownAllGpu(mwSize *GpuTot, unsigned int *HPlan, char *Error);
extern "C" void FFT3DTeardownSglGpu(mwSize *GpuNum, unsigned int *HPlan, char *Error);