%==================================================================
% (V1c)
%   - TrajMash as Input.  
%==================================================================

classdef ReconLungNufftV1c < handle

properties (SetAccess = private)                   
    Method = 'ReconNufftV1c'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    ReconNumber = 1
    Rcvrs
    Shift
    UseExternalShift = 0
    ResetGpus = 1
    DispStatObj
    RespPhaseImages2Do = 1
    LowRamCase = 0
    LowGpuRamCase = 0
    SaveFov = [400 400 400];    % Y-X-Z   (Has to be isotropic for now - need to decide how to save new Fov for display)
    TrajMash
    ObjectAtIso = 1
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconLungNufftV1c()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObjArr)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconLungNufft',1);
    
    %% Test  
    DataObj0 = DataObjArr{1}.DataObj;
    ReconObj.DispStatObj.SetDataObj(DataObj0);
    err.flag = 0;
    if ~strcmp(ReconObj.AcqInfo{ReconObj.ReconNumber}.name,DataObj0.DataInfo.TrajName)
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
    FirstDataPoints = DataObj0.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{ReconObj.ReconNumber});
    TrajMashFunc = str2func(ReconObj.TrajMash);
    TrajMashInfo = TrajMashFunc(FirstDataPoints,DataObj0,ReconObj.AcqInfoRxp);
    WeightArr = single(TrajMashInfo.WeightArr);
    TrajLocAllAcq = single(ReconObj.AcqInfoRxp.TrajLocAllAcq);
    NumImages = TrajMashInfo.NumImages;

    %% Load Data
    ReconObj.DispStatObj.Status('Load Data',2);
    if ReconObj.ObjectAtIso
        DataFull = DataObjArr{1}.DataObj.ReturnAllData(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
    else
        if ReconObj.UseExternalShift
            DataFull = DataObjArr{1}.DataObj.ReturnAllAveragedDataWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
        else
            DataFull = DataObjArr{1}.DataObj.ReturnAllAveragedDataWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
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
    KernHolder.Initialize(ReconObj.AcqInfoRxp,DataObj0.RxChannels);
    
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
    Fov = ReconObj.AcqInfoRxp.Fov;
    for n = 1:3
        Sz(n) = 2*round(((ReconObj.SaveFov(n)/Fov)*ReconObj.BaseMatrix)/2);
        Start(n) = (ReconObj.BaseMatrix - Sz(n))/2; 
        Stop(n) = Start(n) + Sz(n) - 1;
    end
    Image = zeros([Sz(1),Sz(2),Sz(3),NumImages],'like',single(1+1i));         
    
    %% Loop Through
    for nim = 1:NumImages
        % RxProfs
        if ReconObj.LowGpuRamCase
            ReconObj.DispStatObj.Status('RxProf Initialize',2);
            StitchItRx = StitchItReturnRxProfs();
            StitchItRx.SetUnallocateRamOnFinish(ReconObj.LowRamCase);                                             
            StitchItRx.Initialize(KernHolder,ReconObj.AcqInfoRxp); 
        end
        ReconObj.DispStatObj.Status(['RxProfs ',num2str(ReconObj.RespPhaseImages2Do(nim))],2);
        Data = DoTrajMashV2(DataRxProfFull,WeightArr,TrajLocAllAcq);
        Data = DataObj0.ScaleData(StitchItRx,Data);
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
        Data = DoTrajMashV2(DataFull,WeightArr,TrajLocAllAcq);
        Data = DataObj0.ScaleData(StitchIt,Data);
        ReconObj.DispStatObj.Status(['Nufft Recon ',num2str(ReconObj.RespPhaseImages2Do(nim))],2);
        StitchIt.LoadRxProfs(RxProfs);
        if ReconObj.LowRamCase
            RxProfs = [];                           % unallocate this memory
        end
        ImageOut = StitchIt.CreateImage(Data);
        Image(:,:,:,nim) = ImageOut(Start(1):Stop(1),Start(2):Stop(2),Start(3):Stop(3));
        ReconObj.DispStatObj.TestDisplayInitialImages(Image(:,:,:,nim),['Image',num2str(ReconObj.RespPhaseImages2Do(nim))]);
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
function SetRespPhaseImages2Do(ReconObj,val)    
    ReconObj.RespPhaseImages2Do = val;
end
function SetTrajMash(ReconObj,val)    
    ReconObj.TrajMash = val;
end
function SetSaveFov(ReconObj,val)    
    ReconObj.SaveFov = val;
end
function SetObjectAtIso(ReconObj,val)    
    ReconObj.ObjectAtIso = val;
end

end
end