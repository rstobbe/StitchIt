%%
% reset(gpuDevice(1))
% reset(gpuDevice(2))

%%
ZeroFill = 224;
BaseMatrix = 140;
N = 1;
RxProfs = complex(ones([BaseMatrix BaseMatrix BaseMatrix N],'single'),1e-20*ones([BaseMatrix BaseMatrix BaseMatrix N],'single'));

Options = StitchItNufft1aOptions(); 
Options.SetZeroFill(ZeroFill);

load('E:\Trajectories\BartTesting\F224_V0054_E100_T100_N1152_SU110_1O\YB_F224_V54_E100_T100_N1152_P119_S10110_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

%%
Image = single(phantom3d(BaseMatrix));
SimImage = complex(Image,1e-20*ones([BaseMatrix BaseMatrix BaseMatrix],'single'));
Data = Nufft.Forward(SimImage);
Data = Data(:);

Image0 = Nufft.Inverse(Data);
ImportImageCompass(Image0,'Regrid1');
Nufft.Finish;
SzIm = size(Image0);

%%
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;
AcqInfo.SetReconInfoMat(ReconInfoMat);
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

Func = @(x,transp) StitchItLsqrFunc(x,transp,Nufft,SzIm);
Nit = 40;
ImageIn = Image0(:);
tic
%Image = lsqr(Func,Data,1e-8,Nit,[],[],ImageIn);
Image = lsqr(Func,Data,1e-12,Nit,[],[],[]);
toc
Nufft.Finish;

Image = reshape(Image,SzIm);
ImportImageCompass(Image,'It1');

