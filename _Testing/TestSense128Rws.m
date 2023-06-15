%% Regridding Demo with RWS NUFFT

%% Setup and Data
clear
BaseMatrix = 140;
N = 10;
RxProfs = single(simRcvrSens([BaseMatrix BaseMatrix BaseMatrix],N,[]));

Options = StitchItNufft1aOptions(); 
Options.SetBaseMatrix(BaseMatrix);

load('E:\Trajectories\CompSensYarnTest\F224_V0054_E100_T100_N450_SLD10050_1O\YB_F224_V54_E100_T100_N450_P75_S2010050_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\CompSensYarnTest\F224_V0054_E100_T100_N450_SLD10050_1O\StitchItTesting\KSMP_SheppLogan200R10.mat';        
DataObj = SimulationDataObject(file);    
DataObj.InitializeForStitchIt(Options);
Data = DataObj.DataFull{1};

%% Regrid
Image0 = Nufft.Inverse(Data);
ImportImageCompass(Image0,'Regrid');
Nufft.Finish;
SzIm = size(Image0);
SzData = size(Data);

%% Sense (no regularization)
%---------------------------------------
% ReconInfoMat = AcqInfo.ReconInfoMat;
% ReconInfoMat(:,:,4) = 1;                    % set sampling density compensation to '1'.  
% AcqInfo.SetReconInfoMat(ReconInfoMat);
% %---------------------------------------
% Nufft = StitchItNufft1a(Options);
% Nufft.Log.SetVerbosity(3);
% Nufft.Setup(AcqInfo,RxProfs);
% 
% Func = @(x,transp) StitchItLsqrFunc(x,transp,Nufft,SzIm,SzData);
% Nit = 200; 
% tic
% [Image,flag,relres,iter,resvec] = lsqr(Func,Data(:),[],Nit,[],[],Image0(:));
% %Image = lsqr(Func,Data(:),[],Nit,[],[],[]);
% toc
% Nufft.Finish;
% 
% Image = reshape(Image,SzIm);
% ImportImageCompass(Image,'SenseNoReg200');

%% Sense (Tikhonov)
%---------------------------------------
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;                    % set sampling density compensation to '1'.  
AcqInfo.SetReconInfoMat(ReconInfoMat);
%---------------------------------------
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

Opt.Lambda = 0.1;
Func = @(x,transp) StitchItLsqrTikFunc(x,transp,Nufft,SzIm,SzData,Opt);
Nit = 100; 
Data = [Data(:); zeros(numel(Image0),1)]; 
tic
[Image,flag,relres,iter,resvec] = lsqr(Func,Data(:),[],Nit,[],[],Image0(:));
%Image = lsqr(Func,Data(:),[],Nit,[],[],[]);
toc
Nufft.Finish;

Image = reshape(Image,SzIm);
ImportImageCompass(Image,'SenseTik100');