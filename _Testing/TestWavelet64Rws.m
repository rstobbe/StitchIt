%% Regridding Demo with RWS NUFFT

%% Setup and Data
clear
BaseMatrix = 150;
N = 10;
RxProfs = single(simRcvrSens([BaseMatrix BaseMatrix BaseMatrix],N,[]));

Options = StitchItNufft1aOptions(); 
Options.SetBaseMatrix(BaseMatrix);

load('E:\Trajectories\CompSensYarnTest\F224_V0429_E100_T100_N98_SLD10050_1O\YB_F224_V429_E100_T100_N98_P70_S2010050_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\CompSensYarnTest\F224_V0429_E100_T100_N98_SLD10050_1O\StitchItTesting\KSMP_SheppLogan200R10.mat';           
DataObj = SimulationDataObject(file);    
DataObj.InitializeForStitchIt(Options);
Data = DataObj.DataFull{1};

%% Regrid
Image0 = Nufft.Inverse(Data);
ImportImageCompass(Image0,'Regrid');
Nufft.Finish;

%% Sense (no regularization)
%---------------------------------------
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;                        % set sampling density compensation to '1'.  
AcqInfo.SetReconInfoMat(ReconInfoMat);
%---------------------------------------
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

levelsPerDim = [2 2 2];
isDec = 0;                                      % Non-decimated to avoid blocky edges
Wave = dwt(levelsPerDim,size(Image0),isDec);

Func = @(x,transp) StitchItLsqrWavFunc(x,transp,Nufft);
Nit = 200;
Lambda = 0.1;
Opt = [];
tic
[Image,resSqAll,RxAll,mseAll] = bfista(Func,Data,Wave,Lambda,Image0,Nit,Opt);
toc
Nufft.Finish;

ImportImageCompass(Image,'Wave222_200_0p1_Base150');
