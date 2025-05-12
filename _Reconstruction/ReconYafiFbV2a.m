%==================================================================
% (V2a)
%   - TrajMash as Object Input.  
%==================================================================

classdef ReconYafiFbV2a < handle

properties (SetAccess = private)                   
    Method = 'ReconYafiFbV2a'
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
    DoSaveSmallerFov = 0;
    SaveSmallerFov = [400 400 400];    % Y-X-Z   (Has to be isotropic for now - need to decide how to save new Fov for display)
    TrajMashObj
    MaskVal
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconYafiFbV2a()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObj)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconYafiFbV2a',1);
    
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
        err.msg = 'This Recon_File Not for YafiFb (Id212)';
        return
    end

    %% TrajMash
    ReconObj.DispStatObj.Status('Solve TrajMash',2);
    FirstDataPoints = DataObj.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{1});
    FirstDataPoints = FirstDataPoints(ReconObj.AcqInfo{1}.Dummies+1:2:end,:);
    ReconObj.TrajMashObj.CreateNavigatorWaveform(FirstDataPoints,DataObj,ReconObj.AcqInfo{1});
    ReconObj.TrajMashObj.WeightTrajectories();
    NumImages = ReconObj.TrajMashObj.NumImages;
    if NumImages ~= 1
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
    sz = size(DataFull);
    YafiData = zeros((sz(1)-ReconObj.AcqInfo{1}.Dummies)/2,sz(2),sz(3),2,'single');
    YafiData(:,:,:,1) = DataFull(ReconObj.AcqInfo{1}.Dummies+1:2:end,:,:);
    YafiData(:,:,:,2) = DataFull(ReconObj.AcqInfo{1}.Dummies+2:2:end,:,:);
    YafiDataRxProf = YafiData(:,1:ReconObj.AcqInfoRxp.NumCol,:,1);        % Use first image (doesn't matter - it gets divided out anyway)

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
    Data = ReconObj.TrajMashObj.DoTrajMash(YafiDataRxProf,1);
    Data = DataObj.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate',3);
    RxProfs = StitchIt.CreateImage(Data);
    %--
    %ReconObj.DispStatObj.SetDisplayRxProfs(1);
    %--
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear('StitchIt','Data');
    
    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon',2);
    StitchIt = StitchItNufftV1a();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{1}); 
    StitchIt.LoadRxProfs(RxProfs);
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,1,1,3],'like',single(1+1i));
    for n = 1:2
        Data = ReconObj.TrajMashObj.DoTrajMash(YafiData(:,:,:,n),1);
        Data = DataObj.ScaleData(KernHolder,Data);          
        ReconObj.DispStatObj.Status(['Generate ',num2str(n)],3);
        Image(:,:,:,:,:,n) = StitchIt.CreateImage(Data);
    end
    ImageMasked = Image;
    MeanImage = abs(mean(Image,6));
    MeanImage = repmat(MeanImage,1,1,1,1,1,2);
    Mask = zeros(size(Image));
    Mask(MeanImage < ReconObj.MaskVal*max(MeanImage(:))) = 1;
    ImageMasked(logical(Mask)) = NaN;
    ImRat = abs(ImageMasked(:,:,:,:,:,2))./abs(ImageMasked(:,:,:,:,:,1));
    ImRat(ImRat > 1) = NaN;
    TrRat = DataObj.DataInfo.ExpPars.Sequence.tr2/DataObj.DataInfo.ExpPars.Sequence.tr1;
    if ReconObj.ReturnType == 0
        Image = (180*acos((TrRat*ImRat-1)./(TrRat-ImRat))/pi)/DataObj.DataInfo.ExpPars.Sequence.flip;
    else
        Image(:,:,:,:,:,3) = (180*acos((TrRat*ImRat-1)./(TrRat-ImRat))/pi)/DataObj.DataInfo.ExpPars.Sequence.flip;
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
function SetReturnType(ReconObj,val)    
    ReconObj.ReturnType = val;
end
function SetMaskVal(ReconObj,val)    
    ReconObj.MaskVal = val;
end

end
end