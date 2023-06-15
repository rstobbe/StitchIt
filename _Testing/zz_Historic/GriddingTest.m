
Gpus2Use = 2;
ChanPerGpu = 4;
Test = GpuInterface;
Test.GpuInit(Gpus2Use);
Test.SetChanPerGpu(ChanPerGpu);

Image = single(randn(64,64,64,8)) + 1i*single(randn(64,64,64,8));
Test.AllocateLoadComplexImages(Image);

%%
Test.AllocateInitializeRetFovImages([40 40 40]);

%%
Test.ReturnFov(0,1);

%%
ImageRetFov = Test.ReturnOneImageRetFovMatrixGpuMem(0,1);

%%
s1 = (64-40)/2 + 1;
s2 = s1 + 40 - 1;
ImageRetFov0 = Image(s1:s2,s1:s2,s1:s2,1);

test1 = sum(ImageRetFov(:))
test2 = sum(ImageRetFov0(:))
