%% Regridding Demo with RWS NUFFT

%% Setup and Data
clear
BaseMatrix = 70;
N = 1;
RxProfs = complex(ones([BaseMatrix BaseMatrix BaseMatrix N],'single'),1e-20*ones([BaseMatrix BaseMatrix BaseMatrix N],'single'));

Options = StitchItNufft1aOptions(); 
Options.SetBaseMatrix(BaseMatrix);

load('E:\Trajectories\BartTesting\F224_V0054_E100_T100_N1152_SU110_1O\YB_F224_V54_E100_T100_N1152_P119_S10110_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\BartTesting\F224_V0054_E100_T100_N1152_SU110_1O\StitchItTestSheppLogan\KSMP_SheppLogan200.mat';           
DataObj = SimulationDataObject(file);    
DataObj.InitializeForStitchIt(Options);
Data = DataObj.DataFull{1};
Data = Data(:);

%% Regrid
Image0 = Nufft.Inverse(Data);
ImportImageCompass(Image0,'Regrid1');
Nufft.Finish;
SzIm = size(Image0);

%% Iterate
%---------------------------------------
ReconInfoMat = AcqInfo.ReconInfoMat;
ReconInfoMat(:,:,4) = 1;                    % set sampling density compensation to '1'.  
AcqInfo.SetReconInfoMat(ReconInfoMat);
%---------------------------------------
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

Func = @(x,transp) StitchItLsqrFunc(x,transp,Nufft,SzIm);
Nit = 5;
ImageIn = Image0(:);
tic
Image = lsqr(Func,Data,[],Nit,[],[],ImageIn);
%Image = lsqr(Func,Data,[],Nit,[],[],[]);
toc
Nufft.Finish;

Image = reshape(Image,SzIm);
ImportImageCompass(Image,'It1');

