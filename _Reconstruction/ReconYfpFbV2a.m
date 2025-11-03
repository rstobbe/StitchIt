%==================================================================
% (V2a)
%   - 
%==================================================================

classdef ReconYfpFbV2a < handle

properties (SetAccess = private)                   
    Method = 'ReconYfpFbV2a'
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
    TrajMashObj
    SteadyStateTest = 1
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconYfpFbV2a()              
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
    NumRcvrs = DataObj.DataInfo.ExpPars.rcvrs;
    NumTraj = ReconObj.AcqInfo{1}.NumTraj;
    NumAverages = ReconObj.AcqInfo{1}.NumAverages;
    TrajPerImage = NumTraj*NumAverages;
    TrajPerImagePlusDummies = NumTraj*NumAverages + Dummies;    

    %% First Data Points
    FirstDataPoints0 = zeros(TrajPerImagePlusDummies*NumImages,NumRcvrs,'like',single(1+1i));
    FirstDataPointsTemp = DataObj.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{1});
    FirstDataPoints0(1:length(FirstDataPointsTemp),:) = FirstDataPointsTemp;                              % hack for missing data points at the end.  
    FirstDataPoints = zeros(TrajPerImage,NumRcvrs,NumImages,'like',single(1+1i));
    for n = 1:NumImages
        FirstDataPoints(:,:,n) = FirstDataPoints0(TrajPerImagePlusDummies*(n-1)+Dummies+(1:TrajPerImage),:);
    end
    DataPreSamp = DataObj.ReturnPreSampDataPlusTwenty(ReconObj.AcqInfo{1},1);
    MeanDataPreSamp = squeeze(mean(DataPreSamp,1));
    figure(2345); hold on;
    plot([ReconObj.AcqInfo{1}.SampStart ReconObj.AcqInfo{1}.SampStart],[-1 1],'k:')
    plot(abs(MeanDataPreSamp(:,1)),'k');
    plot(real(DataPreSamp(1,:,1)),'r');
    plot(imag(DataPreSamp(1,:,1)),'b');
    clear DataPreSamp

    %% Test
    if ReconObj.SteadyStateTest
        figure(1234); hold on;
        plot((1:TrajPerImagePlusDummies*NumImages),mean(abs(FirstDataPoints0),2),'b');
        for n = 1:NumImages
            plot(TrajPerImagePlusDummies*(n-1)+Dummies+(1:TrajPerImage),mean(abs(FirstDataPoints(:,:,n)),2),'r');         
        end
    end

    %% TrajMash
    ReconObj.DispStatObj.Status('Solve TrajMash',2);
    for n = 1:NumImages
        TrajMashObjArray(n) = copy(ReconObj.TrajMashObj);
        TrajMashObjArray(n).SetTrajMashNum(n);
        TrajMashObjArray(n).SetNumTraj(ReconObj.AcqInfo{1}.NumTraj);
        TrajMashObjArray(n).SetNumAverages(ReconObj.AcqInfo{1}.NumAverages);
        TrajMashObjArray(n).SetTrajLocAllAcq(ReconObj.AcqInfo{1}.TrajLocAllAcq);
        TrajMashObjArray(n).SetTr(DataObj.DataInfo.ExpPars.Sequence.trnav(n));
        TrajMashObjArray(n).CreateNavigatorWaveform(FirstDataPoints(:,:,n));
        TrajMashObjArray(n).WeightTrajectories();
        NumRespPhases = TrajMashObjArray(n).NumImages;
    end

    %% Load Data
    ReconObj.DispStatObj.Status('Load Data',2);
    DataFull = zeros(TrajPerImagePlusDummies*NumImages,ReconObj.AcqInfo{1}.NumCol,NumRcvrs,'like',single(1+1i));
    if ReconObj.ObjectAtIso
        DataFullTemp = DataObj.ReturnAllData(ReconObj.AcqInfo{1},1);
    else
        if ReconObj.UseExternalShift
            DataFullTemp = DataObj.ReturnAllAveragedDataWithExternalShift(ReconObj.AcqInfo{1},1,ReconObj.Shift);
        else
            DataFullTemp = DataObj.ReturnAllAveragedDataWithShift(ReconObj.AcqInfo{1},1);
        end
    end
    sz = size(DataFullTemp);
    DataFull(1:sz(1),:,:) = DataFullTemp;
    clear DataFullTemp;
    YfpData = zeros(TrajPerImage,ReconObj.AcqInfo{1}.NumCol,NumRcvrs,NumImages,'like',single(1+1i));
    for n = 1:NumImages
        YfpData(:,:,:,n) = DataFull(TrajPerImagePlusDummies*(n-1)+Dummies+(1:TrajPerImage),:,:);
    end
    clear DataFull;

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
    RxProfIm = 2;                                                   % use same for all
    RxProfRespPhase = 1;                                            % use same for all     
    YfpDataRxProf = YfpData(:,1:ReconObj.AcqInfoRxp.NumCol,:,RxProfIm);                    
    YfpDataRxProf = TrajMashObjArray(RxProfIm).DoTrajMash(YfpDataRxProf,RxProfRespPhase);    
    YfpDataRxProf = DataObj.ScaleData(KernHolder,YfpDataRxProf);
    ReconObj.DispStatObj.Status('Generate',3);
    RxProfs = StitchIt.CreateImage(YfpDataRxProf);
    %--
    %ReconObj.DispStatObj.SetDisplayRxProfs(1);
    %--
    if ReconObj.DoSaveSmallerFov
        Fov = ReconObj.AcqInfoRxp.Fov;
        for n = 1:3
            Sz(n) = 2*round(((ReconObj.SaveSmallerFov(n)/Fov)*ReconObj.BaseMatrix)/2);
            Start(n) = (ReconObj.BaseMatrix - Sz(n))/2; 
            Stop(n) = Start(n) + Sz(n) - 1;
        end
        ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs(Start(1):Stop(1),Start(2):Stop(2),Start(3):Stop(3),:));
    else
        ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    end
    clear('StitchIt','YfpDataRxProf');

    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon',2);
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
        Image = zeros([Sz(1),Sz(2),Sz(3),1,NumRespPhases,NumImages],'like',single(1+1i)); 
    else
        Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,1,NumRespPhases,NumImages],'like',single(1+1i));
    end
    for n = 1:NumImages    
        for m = 1:NumRespPhases
            ReconObj.DispStatObj.Status(['Generate Image: ',num2str(n),'  Resp Phase: ',num2str(m)],3);
            Data = TrajMashObjArray(n).DoTrajMash(YfpData(:,:,:,n),m);
            Data = DataObj.ScaleData(KernHolder,Data);
            ImageOut = StitchIt.CreateImage(Data);
            if ReconObj.DoSaveSmallerFov
                ImageOut = ImageOut(Start(1):Stop(1),Start(2):Stop(2),Start(3):Stop(3),:);
            end
            Image(:,:,:,:,m,n) = ImageOut;
        end
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

end
end