%%
% reset(gpuDevice(1))
% reset(gpuDevice(2))

%%
ZeroFill = 112;
BaseMatrix = 70;
% ZeroFill = 96;
% BaseMatrix = 64;
N = 1;
RxProfs = complex(ones([BaseMatrix BaseMatrix BaseMatrix N],'single'),1e-20*ones([BaseMatrix BaseMatrix BaseMatrix N],'single'));

Options = StitchItNufft1aOptions(); 
Options.SetZeroFill(ZeroFill);

load('E:\Trajectories\BartTesting\F224_V0429_E100_T100_N98_SLD10050_1O\YB_F224_V429_E100_T100_N98_P70_S2010050_IDReconBW12B0.mat');
warning 'off';
AcqInfo = saveData.WRT.STCH{1};
warning 'on';

Nufft = StitchItNufft1a(Options);
Nufft.Log.SetVerbosity(3);
Nufft.Setup(AcqInfo,RxProfs);

%%
Image = single(phantom3d(BaseMatrix));
SimImage = complex(Image,1e-20*ones([BaseMatrix BaseMatrix BaseMatrix],'single'));
FtSimImage1 = ifftn(SimImage) * BaseMatrix^1.5;     
FtSimImage2 = fftn(SimImage) / BaseMatrix^1.5;
Test1 = max(real(FtSimImage1(:)))                                   % These should give the same value    
Test2 = max(real(FtSimImage1(:)))

%%
DataOut = Nufft.Forward(SimImage);                                  % Should have the 'same' value as above 
TestDataOut = max(DataOut(:))
Image1 = Nufft.Inverse(DataOut);

Nufft.Finish;

ImportImageCompass(Image,'BaseImage');
ImportImageCompass(Image1,'ReconImage');

