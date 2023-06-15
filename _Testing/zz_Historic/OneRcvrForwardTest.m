%%
ZeroFill = 224;
BaseMatrix = 140;
N = 1;
RxProfs = complex(ones([BaseMatrix BaseMatrix BaseMatrix N],'single'),1e-20*ones([BaseMatrix BaseMatrix BaseMatrix N],'single'));

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

file = 'E:\Trajectories\BartTesting\F224_V0054_E100_T100_N450_SLD10050_1O\StichItTestSphere220\KSMP_Sphere220_ZF224.mat';           
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

% In this test the image is 'mottled' because of the jagged outline of the simulated sphere (at this low ZF creation value).  