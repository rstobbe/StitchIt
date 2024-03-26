%==================================================================
% (V1b)
%   - Add RespPhase Recon Selection.
%==================================================================

classdef ReconLungStitchItWaveletV1b < handle

properties (SetAccess = private)                   
    Method = 'ReconNufftV1b'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    ReconNumber = 1
    Rcvrs
    Shift
    LevelsPerDim
    NumIterations
    Lambda
    MaxEig
    UseExternalShift = 0
    ResetGpus = 1
    DispStatObj
    RespPhaseImages2Do = 1
    LowRamCase = 0
    LowGpuRamCase = 0
    SaveFov = [400 400 400];    % Y-X-Z   (Has to be isotropic for now - need to decide how to save new Fov for display)
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconLungStitchItWaveletV1b()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObjArr)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconLungStitchItWavelet',1);
    
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
    MetaData.NumTraj = ReconObj.AcqInfoRxp.NumTraj;
    MetaData.NumAverages = DataObj0.NumAverages;
    MetaData.TR = DataObj0.DataInfo.ExpPars.Sequence.tr;
    TrajMashInfo = TrajMash20RespPhasesGaussian(FirstDataPoints,MetaData);
    WeightArr = single(TrajMashInfo.WeightArr);
    NumImages = length(ReconObj.RespPhaseImages2Do);
    if NumImages > size(WeightArr)
        error('Too many RespPhase images specified');
    end
    
    %% Load Data
    ReconObj.DispStatObj.Status('Load Data',2);
    if ReconObj.UseExternalShift
        DataFull = DataObjArr{1}.DataObj.ReturnAllAveragedDataWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
    else
        DataFull = DataObjArr{1}.DataObj.ReturnAllAveragedDataWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
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

        % StitchItNufft Setup
        ReconObj.DispStatObj.Status('Initial Image Initialize',2);
        StitchItInit = StitchItNufftV1a(); 
        StitchItInit.SetUnallocateRamOnFinish(ReconObj.LowRamCase); 
        StitchItInit.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
        
        % StitchItWavelet Setup
        ReconObj.DispStatObj.Status('StitchIt Recon Initialize',2);
        StitchIt = StitchItWaveletV1a();  
        StitchIt.SetUnallocateRamOnFinish(ReconObj.LowRamCase); 
        StitchIt.SetLevelsPerDim(ReconObj.LevelsPerDim);
        StitchIt.SetNumIterations(ReconObj.NumIterations);
        StitchIt.SetLambda(ReconObj.Lambda);
        StitchIt.SetMaxEig(ReconObj.MaxEig);        
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.DispStatObj);         
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
        Data = DoTrajMash(DataRxProfFull,WeightArr(:,ReconObj.RespPhaseImages2Do(nim)),DataObj0.NumAverages);
        Data = DataObj0.ScaleData(StitchItRx,Data);
        RxProfs = StitchItRx.CreateImage(Data);
        ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
        if ReconObj.LowGpuRamCase
            clear StitchItRx
        end

        % Initial Image
        if ReconObj.LowGpuRamCase
            ReconObj.DispStatObj.Status('Nufft Recon Initialize',2);
            StitchItInit = StitchItNufftV1a(); 
            StitchItInit.SetUnallocateRamOnFinish(ReconObj.LowRamCase); 
            StitchItInit.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
        end
        ReconObj.DispStatObj.Status(['Initial Image ',num2str(ReconObj.RespPhaseImages2Do(nim))],2);
        Data = DoTrajMash(DataFull,WeightArr(:,ReconObj.RespPhaseImages2Do(nim)),DataObj0.NumAverages);
        Data = DataObj0.ScaleData(StitchItInit,Data);
        StitchItInit.LoadRxProfs(RxProfs);
        Image0 = StitchItInit.CreateImage(Data);
        ReconObj.DispStatObj.TestDisplayInitialImages(Image0,['Image0Resp',num2str(ReconObj.RespPhaseImages2Do(nim))]);
        if ReconObj.LowGpuRamCase
            clear StitchItInit
        end
        
        % StitchIt Recon
        if ReconObj.LowGpuRamCase
            ReconObj.DispStatObj.Status('StitchIt Recon Initialize',2);
            StitchIt = StitchItWaveletV1a();  
            StitchIt.SetUnallocateRamOnFinish(ReconObj.LowRamCase); 
            StitchIt.SetLevelsPerDim(ReconObj.LevelsPerDim);
            StitchIt.SetNumIterations(ReconObj.NumIterations);
            StitchIt.SetLambda(ReconObj.Lambda);
            StitchIt.SetMaxEig(ReconObj.MaxEig);        
            StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.DispStatObj); 
        end
        ReconObj.DispStatObj.Status(['StitchIt Recon ',num2str(ReconObj.RespPhaseImages2Do(nim))],2);
        StitchIt.LoadRxProfs(RxProfs);
        if ReconObj.LowRamCase
            RxProfs = [];                           % unallocate this memory
        end
        ImageOut = StitchIt.CreateImage(Data,Image0);
        Image(:,:,:,nim) = ImageOut(Start(1):Stop(1),Start(2):Stop(2),Start(3):Stop(3));
        if nim == 1
            AbsMaxEig = abs(StitchIt.MaxEig); 
            ReconObj.SetMaxEig(AbsMaxEig);
        end
        if ReconObj.LowGpuRamCase
            clear StitchIt
        end
       
    end
    clear StitchIt
    clear StitchItInit
    clear StitchItRx
    ReconObj.DispStatObj.StatusClear();
    
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
function SetShift(ReconObj,val)    
    ReconObj.Shift = val;
    ReconObj.UseExternalShift = 1;
end
function SetLevelsPerDim(ReconObj,val)    
    ReconObj.LevelsPerDim = val;
end
function SetLambda(ReconObj,val)    
    ReconObj.Lambda = val;
end
function SetNumIterations(ReconObj,val)    
    ReconObj.NumIterations = val;
end
function SetMaxEig(ReconObj,val)    
    ReconObj.MaxEig = val;
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
function SetDisplayIterations(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayIterations(val);
end
function SetDisplayIterationStep(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayIterationStep(val);
end
function SetSaveIterationStep(ReconObj,val)    
    ReconObj.DispStatObj.SetSaveIterationStep(val);
end
function SetLowRamCase(ReconObj,val)    
    ReconObj.LowRamCase = val;
end
function SetLowGpuRamCase(ReconObj,val)    
    ReconObj.LowGpuRamCase = val;
end
function SetRespPhaseImages2Do(ReconObj,val)    
    ReconObj.RespPhaseImages2Do = val;
end
function SetSaveFov(ReconObj,val)    
    ReconObj.SaveFov = val;
end

end
end