%%
reset(gpuDevice(1))
reset(gpuDevice(2))

%%
ZeroFill = 224;
BaseMatrix = 140;
N = 10;
RxProfs = single(simRcvrSens([BaseMatrix BaseMatrix BaseMatrix],N,[]));
% ImportImageCompass(RxProfs,'RxProfs');
% RxProfsSos = sum((RxProfs.*conj(RxProfs)),4);                 % This is '1' everywhere
% ImportImageCompass(RxProfsSos,'IMG_RxProfsSos');

Options = StitchItNufft1aOptions(); 
Options.SetZeroFill(ZeroFill);

load('E:\Trajectories\BartTesting\F224_V0054_E100_T100_N450_SLD10050_1O\YB_F224_V54_E100_T100_N450_P75_S2010050_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\BartTesting\F224_V0054_E100_T100_N450_SLD10050_1O\StichItTestSphere220\KSMP_Sphere22010C_ZF224.mat';
DataObj = SimulationDataObject(file);    
DataObj.Initialize(Options);
Data0 = DataObj.DataFull{1};
Image0 = Nufft.Inverse(Data0);
ImportImageCompass(Image0,'Sphere220_0');
Nufft.Finish;
SzIm = size(Image0);
SzDat = size(Data0);

%%
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;
AcqInfo.SetReconInfoMat(ReconInfoMat);
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

Func = @(x,transp) StitchItLsqrFunc(x,transp,Nufft,SzIm,SzDat);
Nit = 1;
ImageIn = Image0(:);
Data = Data0(:);
Data = Data(1:2:end) + 1i*Data(2:2:end);
%Image = lsqr(Func,Data,1e-8,Nit,[],[],ImageIn);
Image = lsqr(Func,Data,1e-12,Nit,[],[],[]);
Nufft.Finish;

Image = reshape(Image,SzIm);
ImportImageCompass(Image,'Sphere220_1');

