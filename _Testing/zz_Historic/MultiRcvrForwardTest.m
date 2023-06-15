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
            
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\BartTesting\F224_V0054_E100_T100_N450_SLD10050_1O\StichItTestSphere220\KSMP_Sphere22010C_ZF224.mat';
DataObj = SimulationDataObject(file);    
DataObj.Initialize(Options);
Data = DataObj.DataFull{1};

%%
%tic
Image0 = Nufft.Inverse(Data);

load('E:\Trajectories\BartTesting\F224_V0054_E100_T100_N450_SLD10050_1O\StichItTestSphere220\TestImage224NoR');     % This is the simulated image used to generate the KSMP data above
bot = (ZeroFill-BaseMatrix)/2 + 1;                                                                                  % The subsamp fov increase must be removed for this test.  
top = bot + BaseMatrix - 1;
SimImage = single(complex(zfOb(bot:top,bot:top,bot:top),1e-20*ones([BaseMatrix BaseMatrix BaseMatrix],'single')));
DataOut = Nufft.Forward(SimImage);
Image1 = Nufft.Inverse(DataOut);

Nufft.Finish;

ImportImageCompass(Image0,'Sphere220_0');
ImportImageCompass(Image1,'Sphere220_1');

