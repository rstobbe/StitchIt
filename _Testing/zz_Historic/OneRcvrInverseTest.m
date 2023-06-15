%%
ZeroFill = 208;
BaseMatrix = 130;
RxProfs = complex(ones([BaseMatrix BaseMatrix BaseMatrix],'single'),1e-12*ones([BaseMatrix BaseMatrix BaseMatrix],'single'));

%%
Options = StitchItNufft1aOptions(); 
Options.SetZeroFill(ZeroFill);

load('E:\Trajectories\BartTesting\F220_V0058_E100_T100_N800_SW100_1O\YB_F220_V58_E100_T100_N800_P104_S10100_IDRecon.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';
            
Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

file = 'E:\Trajectories\BartTesting\F220_V0058_E100_T100_N800_SW100_1O\Testing\KSMP_Sphere220.mat';
DataObj = SimulationDataObject(file);    
DataObj.Initialize(Options);

%%
tic
Image = Nufft.Inverse(DataObj.DataFull{1});
toc
Nufft.Finish;
ImportImageCompass(Image,'Image');