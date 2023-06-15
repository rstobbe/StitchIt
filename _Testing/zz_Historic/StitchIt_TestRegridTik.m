%%
% reset(gpuDevice(1))
% reset(gpuDevice(2))

%%
ZeroFill = 112;
BaseMatrix = 70;
% ZeroFill = 224;
% BaseMatrix = 140;
% ZeroFill = 240;
% BaseMatrix = 150;
N = 10;
%RxProfs = complex(ones([BaseMatrix BaseMatrix BaseMatrix N],'single'),1e-20*ones([BaseMatrix BaseMatrix BaseMatrix N],'single'));
RxProfs = single(simRcvrSens([BaseMatrix BaseMatrix BaseMatrix],N,[]));

Options = StitchItNufft1aOptions(); 
Options.SetZeroFill(ZeroFill);

load('E:\Trajectories\BartTesting\F224_V0429_E100_T100_N98_SLD10050_1O\YB_F224_V429_E100_T100_N98_P70_S2010050_IDReconBW12B0.mat');
%load('E:\Trajectories\BartTesting\F224_V0429_E100_T100_N98_SLD10050_1O\YB_F224_V429_E100_T100_N98_P70_S2010050_IDReconBW12B2.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

%%
file = 'E:\Trajectories\BartTesting\F224_V0429_E100_T100_N98_SLD10050_1O\StitchItTesting\KSMP_SheppLogan200R10.mat'; 
%file = 'E:\Trajectories\BartTesting\F224_V0429_E100_T100_N98_SLD10050_1O\StitchItTesting\KSMP_SheppLogan200R10_ZF112.mat';      
DataObj = SimulationDataObject(file);    
DataObj.InitializeForStitchIt(Options);
Data0 = DataObj.DataFull{1};

% Val = 0.05;
% Data = Data + Val*(randn(size(Data)) + 1i*randn(size(Data)));

Image0 = Nufft.Inverse(Data0);
ImportImageCompass(Image0,'Regrid1');
Nufft.Finish;
SzIm = size(Image0);
SzData = size(Data0);

%% LSQR Version
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;
AcqInfo.SetReconInfoMat(ReconInfoMat);
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

%Opt.Lambda = 1*sqrt(norm(Image0(:),2));
%Opt.Lambda = 0;
Opt.Lambda = 0.1;
Func = @(x,transp) StitchItLsqrTikFunc(x,transp,Nufft,SzIm,SzData,Opt);
Nit = 50;
ImageIn = Image0(:);
Data = Data0(:);
tic
Data = [Data; zeros(numel(Image0),1)]; 
%Image = lsqr(Func,Data,1e-8,Nit,[],[],ImageIn);
Image = lsqr(Func,Data,1e-12,Nit,[],[],[]);
toc
Nufft.Finish;

Image = reshape(Image,SzIm);
ImportImageCompass(Image,'Tik0p1');

%% CGNE Version
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;
AcqInfo.SetReconInfoMat(ReconInfoMat);
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

Func = @(x,transp) StitchItLsqrFunc(x,transp,Nufft,SzIm,SzData);
Nit = 50;
ImageIn = Image0(:);
Data = Data0(:);
tic
Lambda = 0.1;
Image = cgne(Func,Data,[],Nit,[],Lambda,1);
toc
Nufft.Finish;

Image = reshape(Image,SzIm);
ImportImageCompass(Image,'Cgne0p1');            % same result as above.