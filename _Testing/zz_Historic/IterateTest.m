%%
reset(gpuDevice(1))
reset(gpuDevice(2))

%%
ZeroFill = 224;
BaseMatrix = 140;
N = 10;
RxProfs = single(simRcvrSens([BaseMatrix BaseMatrix BaseMatrix],N,[]));
ImportImageCompass(RxProfs,'RxProfs');
% RxProfsSos = sum((RxProfs.*conj(RxProfs)),4);                 % This is '1' everywhere
% ImportImageCompass(RxProfsSos,'IMG_RxProfsSos');

%%
Options = StitchItNufft1aOptions(); 
Options.SetZeroFill(ZeroFill);

load('E:\Trajectories\BartTesting\F224_V0054_E100_T100_N450_SLD10050_1O\YB_F224_V54_E100_T100_N450_P75_S2010050_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

% ReconInfoMat = AcqInfo.ReconInfoMat;
% ReconInfoMat(:,:,4) = 1;
% AcqInfo.SetReconInfoMat(ReconInfoMat);

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\BartTesting\F224_V0054_E100_T100_N450_SLD10050_1O\StichItTestSphere220\KSMP_Sphere22010C_ZF224.mat';
DataObj = SimulationDataObject(file);    
DataObj.Initialize(Options);
Data = DataObj.DataFull{1};

%%
sz = size(Data);
Data = Data(:);
Data = Data(1:2:end) + 1i*Data(2:2:end);
InA = zeros(length(Data)*2,1,'single');
InA(1:2:end) = real(Data);
InA(2:2:end) = imag(Data);
Data = reshape(InA,sz);
Image0 = Nufft.Inverse(Data);
sz = size(Image0);
Image0 = Image0(:);
Image0 = reshape(Image0,sz);
DataOut = Nufft.Forward(Image0);
Image1 = Nufft.Inverse(DataOut);

Nufft.Finish;

ImportImageCompass(Image0,'Sphere220_0');
ImportImageCompass(Image1,'Sphere220_1');

