%% Regridding Demo with RWS NUFFT

%% Setup and Data
clear
BaseMatrix = 70;
N = 1;
RxProfs = complex(ones([BaseMatrix BaseMatrix BaseMatrix N],'single'),1e-20*ones([BaseMatrix BaseMatrix BaseMatrix N],'single'));

Options = StitchItNufft1aOptions(); 
Options.SetBaseMatrix(BaseMatrix);

load('E:\Trajectories\BartTesting\F224_V0429_E100_T100_N98_SLD10050_1O\YB_F224_V429_E100_T100_N98_P70_S2010050_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\BartTesting\F224_V0429_E100_T100_N98_SLD10050_1O\StitchItTesting\KSMP_SheppLogan200.mat';           
DataObj = SimulationDataObject(file);    
DataObj.InitializeForStitchIt(Options);
Data = DataObj.DataFull{1};

%% Regrid
Image0 = Nufft.Inverse(Data);
ImportImageCompass(Image0,'Regrid');
Nufft.Finish;
SzIm = size(Image0);
SzData = size(Data);

%% Iterate
%---------------------------------------
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;                    % set sampling density compensation to '1'.  
AcqInfo.SetReconInfoMat(ReconInfoMat);
%---------------------------------------
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

Func = @(x,transp) StitchItLsqrFunc(x,transp,Nufft,SzIm,SzData);
Nit = 50; 
tic
Image = lsqr(Func,Data(:),[],Nit,[],[],Image0(:));
%Image = lsqr(Func,Data,[],Nit,[],[],[]);
toc
Nufft.Finish;

Image = reshape(Image,SzIm);
ImportImageCompass(Image,'Iterate');

