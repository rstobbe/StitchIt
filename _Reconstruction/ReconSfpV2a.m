%==================================================================
% (V2a)
%   - start YfpV2a
%==================================================================

classdef ReconSfpV2a < handle

properties (SetAccess = private)                   
    Method = 'ReconSfpV2a'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    Rcvrs
    Shift
    UseExternalShift = 0
    OffResCorrection = 0
    ResetGpus = 1
    LowGpuRamCase = 0
    LowRamCase = 0
    DispStatObj
    ObjectAtIso = 1
    ReturnType = 0
    DoSaveSmallerFov = 0
    SaveSmallerFov = [400 400 400];   
    TrajMashfunc
    TrajMashIpt
    SteadyStateTest = 0
    FirstDataPointTest = 0
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconSfpV2a()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObj)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconYfpFbV2a',1);
    
    %% Test  
    if iscell(DataObj)
        DataObj = DataObj{1}.DataObj;
    end
    ReconObj.DispStatObj.SetDataObj(DataObj);
    err.flag = 0;
    if ~strcmp(ReconObj.AcqInfo{1}.name,DataObj.DataInfo.TrajName)
        answer = questdlg('Data and Recon have different names - continue?');
        switch answer
            case 'No'
                err.flag = 1;
                err.msg = 'Data and Recon do not match';
                return
            case 'Cancel'
                err.flag = 1;
                err.msg = 'Data and Recon do not match';
                return
        end
    end
    if length(ReconObj.AcqInfo) ~= 1
        err.flag = 1;
        err.msg = 'This Recon_File Not for YfpFb (Id103)';
        return
    end

    %% Info
    NumImages = DataObj.DataInfo.ExpPars.Sequence.NumImages;
    Dummies = DataObj.DataInfo.ExpPars.Sequence.Dummies;
    NumTraj = ReconObj.AcqInfo{1}.NumTraj;
    TrajPerImage = NumTraj + Dummies;    

    %% Test
    if ReconObj.SteadyStateTest
        FirstDataPoints0 = DataObj.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{1});
        figure(1234); hold on;
        plot((1:TrajPerImage*NumImages),mean(abs(FirstDataPoints0),2),'b');
        for n = 1:NumImages
            plot(TrajPerImage*(n-1)+Dummies+(1:NumTraj),mean(abs(FirstDataPoints0(TrajPerImage*(n-1)+Dummies+(1:NumTraj),:)),2),'r');         
        end
    end
    if ReconObj.FirstDataPointTest
        DataPreSamp = DataObj.ReturnPreSampDataPlusTen(ReconObj.AcqInfo{1},1);
        MeanDataPreSamp = squeeze(mean(DataPreSamp,1));
        figure(2345); hold on;
        plot([ReconObj.AcqInfo{1}.SampStart ReconObj.AcqInfo{1}.SampStart],[-1 1],'k:')
        plot(abs(MeanDataPreSamp(1,:,1)),'k');
        plot(real(DataPreSamp(1,:,1)),'r');
        plot(imag(DataPreSamp(1,:,1)),'b');
    end

    %% Load Data
    ReconObj.DispStatObj.Status('Load Data',2);
    if ReconObj.ObjectAtIso
        DataFull = DataObj.ReturnAllData(ReconObj.AcqInfo{1},1);
    else
        if ReconObj.UseExternalShift
            DataFull = DataObj.ReturnAllAveragedDataWithExternalShift(ReconObj.AcqInfo{1},1,ReconObj.Shift);
        else
            DataFull = DataObj.ReturnAllAveragedDataWithShift(ReconObj.AcqInfo{1},1);
        end
    end
    sz = size(DataFull);
    if length(sz) == 2
        sz(3) = 1;
    end
    YfpData = zeros(NumTraj,sz(2),sz(3),NumImages,'single');
    for n = 1:NumImages
        YfpData(:,:,:,n) = DataFull(TrajPerImage*(n-1)+Dummies+(1:NumTraj),:,:);
    end

    %% Reset GPUs
    if ReconObj.ResetGpus
        ReconObj.DispStatObj.Status('Reset GPUs',2);
        for n = 1:gpuDeviceCount
            gpuDevice(n);
        end
    end

    %% NufftKernel
    ReconObj.DispStatObj.Status('Load Nufft Kernel',2);
    KernHolder = NufftKernelHolder();
    if ReconObj.LowGpuRamCase
        KernHolder.SetReducedSubSamp();           % Important for very large zero-fill.  
    end
    KernHolder.SetBaseMatrix(ReconObj.BaseMatrix);
    KernHolder.Initialize(ReconObj.AcqInfo{1},DataObj.RxChannels);    

    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon',2);
    StitchIt = StitchItReturnChannels();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{1}); 
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,1,1,NumImages],'like',single(1+1i));
    YfpData = DataObj.ScaleData(KernHolder,YfpData);  
    for n = 1:NumImages    
        ReconObj.DispStatObj.Status(['Generate ',num2str(n)],3);
        ImageOut = StitchIt.CreateImage(YfpData(:,:,:,n));
        Image(:,:,:,:,:,n) = ImageOut;
    end
    %--
    Image = 1000*Image;     % Siemens scale
    %--

    clear StitchIt
    %ReconObj.DispStatObj.StatusClear();

end

%==================================================================
% Set
%==================================================================  
%% Set
function SetBaseMatrix(ReconObj,val)    
    ReconObj.BaseMatrix = val;
end
function SetAcqInfo(ReconObj,val)    
    ReconObj.AcqInfo = val;
end
function SetAcqInfoRxp(ReconObj,val)    
    ReconObj.AcqInfoRxp = val;
end
function SetRcvrs(ReconObj,val)    
    ReconObj.Rcvrs = val;
end
function SetLowRamCase(ReconObj,val)    
    ReconObj.LowRamCase = val;
end
function SetLowGpuRamCase(ReconObj,val)    
    ReconObj.LowGpuRamCase = val;
end
function SetShift(ReconObj,val)    
    ReconObj.Shift = val;
    ReconObj.UseExternalShift = 1;
end
function SetUseExternalShift(ReconObj,val)    
    ReconObj.UseExternalShift = val;
end
function SetDisplayRxProfs(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayRxProfs(val);
end
function SetDisplayInitialImages(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayInitialImages(val);
end
function SetDisplayOffResMap(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayOffResMap(val);
end
function SetTrajMashInfo(ReconObj,TrajMashfunc,TrajMashIpt)    
    ReconObj.TrajMashfunc = TrajMashfunc;
    ReconObj.TrajMashIpt = TrajMashIpt;
end
function SetSaveSmallerFov(ReconObj,val)    
    ReconObj.SaveSmallerFov = [val val val];
end
function SetDoSaveSmallerFov(ReconObj,val)    
    ReconObj.DoSaveSmallerFov = val;
end
function SetObjectAtIso(ReconObj,val)    
    ReconObj.ObjectAtIso = val;
end
function SetReturnType(ReconObj,val)    
    ReconObj.ReturnType = val;
end

end
end