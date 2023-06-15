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

Gmag = imgradient3(abs(Image0));
[Gx,Gy,Gz] = imgradientxyz(abs(Image0));
ImportImageCompass(Gmag,'Gmag1');            
ImportImageCompass(Gx,'Gx1');           
ImportImageCompass(Gy,'Gy1');            
ImportImageCompass(Gz,'Gz1');            
ImportImageCompass((Gx.^2 + Gy.^2 + Gz.^2).^0.5,'Gmag1b');  

Sobel(:,:,1) = [ 1  3  1;  3  6  3;  1  3  1];
Sobel(:,:,2) = [ 0  0  0;  0  0  0;  0  0  0];
Sobel(:,:,3) = [-1 -3 -1; -3 -6 -3; -1 -3 -1];

Gz2 = convn(Image0,Sobel,'same');
ImportImageCompass(Gz2,'Gz2');   
Gz2b = convn(Image0,permute(Sobel,[2 1 3]),'same');
ImportImageCompass(Gz2,'Gz2b');   

Gy2 = convn(Image0,permute(Sobel,[2 3 1]),'same');
ImportImageCompass(Gy2,'Gy2');  
Gy2b = convn(Image0,permute(Sobel,[1 3 2]),'same');
ImportImageCompass(Gy2b,'Gy2b');  

Gx2 = convn(Image0,permute(Sobel,[3 2 1]),'same');
ImportImageCompass(Gx2,'Gx2');  
Gx2b = convn(Image0,permute(Sobel,[3 1 2]),'same');
ImportImageCompass(Gx2b,'Gx2b');  

ImportImageCompass((Gx2.^2 + Gy2.^2 + Gz2.^2).^0.5,'Gmag2');  


%% CGNE Version
% ReconInfoMat = AcqInfo.ReconInfoMat;
% ReconInfoMat(:,:,4) = 1;
% AcqInfo.SetReconInfoMat(ReconInfoMat);
% Nufft = StitchItNufft1a(Options);
% Nufft.Log.SetVerbosity(3);
% Nufft.Setup(AcqInfo,RxProfs);
% 
% Func = @(x,transp) StitchItLsqrFunc(x,transp,Nufft,SzIm,SzData);
% Nit = 50;
% ImageIn = Image0(:);
% Data = Data0(:);
% tic
% Lambda = 0.1;
% Rin = 1;
% Image = cgne(Func,Data,[],Nit,[],Lambda,Rin);
% toc
% Nufft.Finish;
% 
% Image = reshape(Image,SzIm);
% ImportImageCompass(Image,'Cgne0p1');            % same result as above.