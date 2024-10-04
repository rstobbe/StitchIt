%==================================================================
% (V2a)
%   - TrajMash as Object Input.  
%==================================================================

classdef ReconLungNufftV2a < handle

properties (SetAccess = private)                   
    Method = 'ReconNufftV2a'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    ReconNumber = 1
    Rcvrs
    Shift
    UseExternalShift = 0
    ResetGpus = 1
    DispStatObj
    LowRamCase = 0
    LowGpuRamCase = 0
    DoSaveSmallerFov = 0;
    SaveSmallerFov = [400 400 400];    % Y-X-Z   (Has to be isotropic for now - need to decide how to save new Fov for display)
    TrajMashObj
    ObjectAtIso = 1
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconLungNufftV2a()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObj)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconLungNufft',1);
    
    %% Test  
    if iscell(DataObj)
        DataObj = DataObj{1}.DataObj;
    end
    ReconObj.DispStatObj.SetDataObj(DataObj);
    err.flag = 0;
    if ~strcmp(ReconObj.AcqInfo{ReconObj.ReconNumber}.name,DataObj.DataInfo.TrajName)
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
    if ReconObj.ReconNumber > length(ReconObj.AcqInfo)
        err.flag = 1;
        err.msg = 'ReconNumber beyond length Recon_File';
        return
    end

    %% TrajMash
    ReconObj.DispStatObj.Status('Solve TrajMash',2);
    FirstDataPoints = DataObj.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{ReconObj.ReconNumber});
    ReconObj.TrajMashObj.CreateNavigatorWaveform(FirstDataPoints,DataObj,ReconObj.AcqInfoRxp);
    ReconObj.TrajMashObj.WeightTrajectories();
    NumImages = ReconObj.TrajMashObj.NumImages;

    %% Load Data
    ReconObj.DispStatObj.Status('Load Data',2);
    if ReconObj.ObjectAtIso
        DataFull = DataObj.ReturnAllData(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
    else
        if ReconObj.UseExternalShift
            DataFull = DataObj.ReturnAllAveragedDataWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
        else
            DataFull = DataObj.ReturnAllAveragedDataWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        end
    end
    DataRxProfFull = DataFull(:,1:ReconObj.AcqInfoRxp.NumCol,:);
    
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
%     if ReconObj.LowGpuRamCase
%         KernHolder.SetReducedSubSamp();           % probably not a big savings...
%     end
    KernHolder.SetBaseMatrix(ReconObj.BaseMatrix);
    KernHolder.Initialize(ReconObj.AcqInfoRxp,DataObj.RxChannels);
    
    %% Setup
    if ~ReconObj.LowGpuRamCase
        % RxProf Setup
        ReconObj.DispStatObj.Status('RxProf Initialize',2);
        StitchItRx = StitchItReturnRxProfs();
        StitchItRx.SetUnallocateRamOnFinish(ReconObj.LowRamCase);                                             
        StitchItRx.Initialize(KernHolder,ReconObj.AcqInfoRxp);    
        % StitchIt Setup
        ReconObj.DispStatObj.Status('Nufft Recon Initialize',2);
        StitchIt = StitchItNufftV1a(); 
        StitchIt.SetUnallocateRamOnFinish(ReconObj.LowRamCase); 
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});   
    end 
    if ReconObj.DoSaveSmallerFov
        Fov = ReconObj.AcqInfoRxp.Fov;
        for n = 1:3
            Sz(n) = 2*round(((ReconObj.SaveSmallerFov(n)/Fov)*ReconObj.BaseMatrix)/2);
            Start(n) = (ReconObj.BaseMatrix - Sz(n))/2; 
            Stop(n) = Start(n) + Sz(n) - 1;
        end
        Image = zeros([Sz(1),Sz(2),Sz(3),NumImages],'like',single(1+1i)); 
    else
        Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,NumImages],'like',single(1+1i)); 
    end

    %% Loop Through
    for nim = 1:NumImages
        % RxProfs
        if ReconObj.LowGpuRamCase
            ReconObj.DispStatObj.Status('RxProf Initialize',2);
            StitchItRx = StitchItReturnRxProfs();
            StitchItRx.SetUnallocateRamOnFinish(ReconObj.LowRamCase);                                             
            StitchItRx.Initialize(KernHolder,ReconObj.AcqInfoRxp); 
        end
        ReconObj.DispStatObj.Status(['RxProfs ',num2str(nim)],2);
        Data = ReconObj.TrajMashObj.DoTrajMash(DataRxProfFull,nim);
        Data = DataObj.ScaleData(StitchItRx,Data);
        RxProfs = StitchItRx.CreateImage(Data);
        ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
        if ReconObj.LowGpuRamCase
            clear StitchItRx
        end         
        % Image
        if ReconObj.LowGpuRamCase
            ReconObj.DispStatObj.Status('Nufft Recon Initialize',2);
            StitchIt = StitchItNufftV1a(); 
            StitchIt.SetUnallocateRamOnFinish(ReconObj.LowRamCase); 
            StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
        end
        ReconObj.DispStatObj.Status(['Nufft Recon ',num2str(nim)],2);
        Data = ReconObj.TrajMashObj.DoTrajMash(DataFull,nim);
        Data = DataObj.ScaleData(StitchIt,Data);
        StitchIt.LoadRxProfs(RxProfs);
        if ReconObj.LowRamCase
            RxProfs = [];                           % unallocate this memory
        end
        ImageOut = StitchIt.CreateImage(Data);
        if ReconObj.DoSaveSmallerFov
            Image(:,:,:,nim) = ImageOut(Start(1):Stop(1),Start(2):Stop(2),Start(3):Stop(3));
        else
            Image(:,:,:,nim) = ImageOut;
        end
        ReconObj.DispStatObj.TestDisplayInitialImages(Image(:,:,:,nim),['Image',num2str(nim)]);
        if ReconObj.LowGpuRamCase
            clear StitchIt
        end
    end
    clear StitchIt
    clear StitchItRx
    clear StitchItI
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
function SetReconNumber(ReconObj,val)    
    ReconObj.ReconNumber = val;
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
function SetTrajMashObj(ReconObj,val)    
    ReconObj.TrajMashObj = val;
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

end
end