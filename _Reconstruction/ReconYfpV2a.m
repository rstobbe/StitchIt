%==================================================================
% (V2a)
%   - 
%==================================================================

classdef ReconYfpV2a < handle

properties (SetAccess = private)                   
    Method = 'ReconYfpV2a'
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
    DoSaveSmallerFov = 1;
    SaveSmallerFov = [400 400 200];   
    TrajMashfunc
    TrajMashIpt
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconYfpV2a()              
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

    %% Test
    SteadyStateTest = 1;
    if SteadyStateTest
        FirstDataPoints0 = DataObj.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{1});
        NumImages = DataObj.DataInfo.ExpPars.Sequence.NumImages;
        Dummies = DataObj.DataInfo.ExpPars.Sequence.Dummies;
        NumTraj = ReconObj.AcqInfo{1}.NumTraj;
        TrajPerImage = NumTraj + Dummies;
        figure(1234); hold on;
        plot((1:TrajPerImage),mean(abs(FirstDataPoints0),2),'b');
        for n = 1:NumImages
            plot(TrajPerImage*(n-1)+Dummies+(1:NumTraj),mean(abs(FirstDataPoints0(TrajPerImage*(n-1)+Dummies+(1:NumTraj),:)),2),'r');         
        end
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
    YfpData = zeros(NumTraj,sz(2),sz(3),NumImages,'single');
    for n = 1:NumImages
        YfpData(:,:,:,n) = DataFull(TrajPerImage*(n-1)+Dummies+1:TrajPerImage*n,:,:);
    end
    YfpDataRxProf = YfpData(:,1:ReconObj.AcqInfoRxp.NumCol,:,1);          % Use first image (doesn't matter - it gets 'divided out' anyway)

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

    %% RxProfs
    ReconObj.DispStatObj.Status('RxProfs',2);
    ReconObj.DispStatObj.Status('Initialize',3);
    StitchIt = StitchItReturnRxProfs();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfoRxp);
    YfpDataRxProf = DataObj.ScaleData(StitchIt,YfpDataRxProf);
    ReconObj.DispStatObj.Status('Generate',3);
    RxProfs = StitchIt.CreateImage(YfpDataRxProf);
    %--
    %ReconObj.DispStatObj.SetDisplayRxProfs(1);
    %--
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear('StitchIt','YfpDataRxProf');
    
    % NumImages = 1;

    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon',2);
    % StitchIt = StitchItReturnChannels();
    % StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{1}); 
    StitchIt = StitchItNufftV1a();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{1}); 
    StitchIt.LoadRxProfs(RxProfs);
    if ReconObj.DoSaveSmallerFov
        Fov = ReconObj.AcqInfoRxp.Fov;
        for n = 1:3
            Sz(n) = 2*round(((ReconObj.SaveSmallerFov(n)/Fov)*ReconObj.BaseMatrix)/2);
            Start(n) = (ReconObj.BaseMatrix - Sz(n))/2; 
            Stop(n) = Start(n) + Sz(n) - 1;
        end
        % Image = zeros([Sz(1),Sz(2),Sz(3),DataObj.RxChannels,1,NumImages],'like',single(1+1i)); 
        Image = zeros([Sz(1),Sz(2),Sz(3),1,1,NumImages],'like',single(1+1i)); 
    else
        % Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,DataObj.RxChannels,1,NumImages],'like',single(1+1i));
        Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,1,1,NumImages],'like',single(1+1i));
    end
    YfpData = DataObj.ScaleData(KernHolder,YfpData);  
    for n = 1:NumImages    
        ReconObj.DispStatObj.Status(['Generate ',num2str(n)],3);
        ImageOut = StitchIt.CreateImage(YfpData(:,:,:,n));
        if ReconObj.DoSaveSmallerFov
            ImageOut = ImageOut(Start(1):Stop(1),Start(2):Stop(2),Start(3):Stop(3),:);
        end
        % Image(:,:,:,:,:,n) = (sum((abs(ImageOut)).^2,4)).^(1/2);
        Image(:,:,:,:,:,n) = ImageOut;
    end

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