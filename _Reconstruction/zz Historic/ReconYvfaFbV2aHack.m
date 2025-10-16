%==================================================================
% (V2a)
%   - TrajMash as Object Input.  
%==================================================================

classdef ReconYvfaFbV2aHack < handle

properties (SetAccess = private)                   
    Method = 'ReconYvfaFbV2aHack'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    Rcvrs
    Shift
    UseExternalShift = 0
    OffResCorrection = 0
    ResetGpus = 0
    LowGpuRamCase = 0
    LowRamCase = 0
    DispStatObj
    ObjectAtIso = 1
    ReturnType = 0
    DoSaveSmallerFov = 0;
    SaveSmallerFov = [400 400 400];    % Y-X-Z   (Has to be isotropic for now - need to decide how to save new Fov for display)
    TrajMashfunc
    TrajMashIpt
    MaskVal
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconYvfaFbV2aHack()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObj)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconYvfaFbV2a',1);
    
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
        err.msg = 'This Recon_File Not for YvfaFb (Id212)';
        return
    end

    %% TrajMash
    ReconObj.DispStatObj.Status('Solve TrajMash',2);
    temp = DataObj.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{1});
    %FirstDataPoints0(end+1:end+3,:) = 0;


     FirstDataPoints0 = temp(101201:202400,:);
    
    % NumFlips = DataObj.DataInfo.ExpPars.Sequence.numflips;
    NumFlips = DataObj.DataInfo.ExpPars.Sequence.NumImages;
    Dummies = ReconObj.AcqInfo{1}.Dummies;
    NumTraj = ReconObj.AcqInfo{1}.NumTraj;
    NumAverages = ReconObj.AcqInfo{1}.NumAverages;
    TrajPerFlip = (NumTraj + Dummies) * NumAverages;
    func = str2func(ReconObj.TrajMashfunc);     


    NumFlips = 2;


    for n = 1:NumFlips
        TrajMashObjArray(n) = func();
        TrajMashObjArray(n).InitViaCompass(ReconObj.TrajMashIpt);
        FirstDataPoints = FirstDataPoints0(n*2000+[TrajPerFlip*(n-1)+1:TrajPerFlip*n],:);
        FirstDataPoints = FirstDataPoints(Dummies+1:end,:);
        TrajMashObjArray(n).TrajMashObj.CreateNavigatorWaveform(FirstDataPoints,DataObj,ReconObj.AcqInfo{1});
        TrajMashObjArray(n).TrajMashObj.WeightTrajectories();
    end
    if TrajMashObjArray(1).TrajMashObj.NumImages ~= 1
        err.flag = 1;
        err.msg = 'Only one TrajMash image is supported';
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
 
temp = DataFull;
DataFull = temp(101201:202400,:,:);
    %DataFull(end+1:end+3,:,:) = 0;  % RT - error 1 - missing data points
   % DataFull=DataFull(1:end-1,:,:); 
    sz = size(DataFull);

   % YvfaData = zeros((sz(1)-ReconObj.AcqInfo{1}.Dummies)/NumFlips,sz(2),sz(3),NumFlips,'single');
    %RT - error 2 - Dummies is listed as zero -- should be 2000??
    



YvfaData = zeros((sz(1)-4000)/NumFlips,sz(2),sz(3),NumFlips,'single');  % RT error 3 - does not account for dummies correctly



    for n = 1:NumFlips
       % YvfaData(:,:,:,n) = DataFull([TrajPerFlip*(n-1)+1:TrajPerFlip*n],:,:);  % RT error 4 - does not accont for dummies correctly 
        YvfaData(:,:,:,n) = DataFull(2000*(n)+[TrajPerFlip*(n-1)+1:TrajPerFlip*n],:,:);  % RT error 4 - does not accont for dummies correctly 

    end
    YvfaDataRxProf = YvfaData(:,1:ReconObj.AcqInfoRxp.NumCol,:,1);          % Use first image (doesn't matter - it gets 'divided out' anyway)

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
    Data = TrajMashObjArray(1).TrajMashObj.DoTrajMash(YvfaDataRxProf,1);    % Use first image (doesn't matter - it gets 'divided out' anyway)
    Data = DataObj.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate',3);
    RxProfs = StitchIt.CreateImage(Data);
    %--
    ReconObj.DispStatObj.SetDisplayRxProfs(1);
    %--
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear('StitchIt','Data');
    
    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon',2);
    StitchIt = StitchItNufftV1a();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{1}); 
    StitchIt.LoadRxProfs(RxProfs);
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,1,1,NumFlips],'like',single(1+1i));
    for n = 1:NumFlips
        Data = TrajMashObjArray(n).TrajMashObj.DoTrajMash(YvfaData(:,:,:,n),1);
        Data = DataObj.ScaleData(KernHolder,Data);          
        ReconObj.DispStatObj.Status(['Generate ',num2str(n)],3);
        Image(:,:,:,:,:,n) = StitchIt.CreateImage(Data);
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
function SetMaskVal(ReconObj,val)    
    ReconObj.MaskVal = val;
end

end
end