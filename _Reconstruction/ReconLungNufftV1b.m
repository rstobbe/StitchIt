%==================================================================
% (V1b)
%   - Add RespPhase Recon Selection.
%==================================================================

classdef ReconLungNufftV1b < handle

properties (SetAccess = private)                   
    Method = 'ReconNufftV1b'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    ReconNumber = 1
    Rcvrs
    OffResMap
    Shift
    UseExternalShift = 0
    OffResCorrection = 0
    ResetGpus = 1
    DispStatObj
    RespPhaseImages2Do = 1
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconLungNufftV1b()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObjArr)     
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

    %% RxProf Setup
    ReconObj.DispStatObj.Status('RxProf Initialize',2);
    StitchItRx = StitchItReturnRxProfs();
    StitchItRx.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchItRx.SetFov2ReturnBaseMatrix;
    StitchItRx.Initialize(ReconObj.AcqInfoRxp,DataObj0.RxChannels);      
    
    %% StitchIt Setup
    ReconObj.DispStatObj.Status('Nufft Recon Initialize',2);
    StitchIt = StitchItNufftV1a(); 
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfo{ReconObj.ReconNumber},DataObj0.RxChannels); 
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,NumImages],'like',single(1+1i));      
    
    %% Loop Through
  
    for nim = 1:NumImages
   
        %%% RxProfs
        ReconObj.DispStatObj.Status(['RxProfs ',num2str(ReconObj.RespPhaseImages2Do(nim))],2);
        Data = DoTrajMash(DataRxProfFull,WeightArr(:,ReconObj.RespPhaseImages2Do(nim)),DataObj0.NumAverages);
        Data = DataObj0.ScaleData(StitchItRx,Data);
        RxProfs = StitchItRx.CreateImage(Data);
        ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);

        %%% Image
        ReconObj.DispStatObj.Status(['Nufft Recon ',num2str(ReconObj.RespPhaseImages2Do(nim))],2);
        Data = DoTrajMash(DataFull,WeightArr(:,ReconObj.RespPhaseImages2Do(nim)),DataObj0.NumAverages);
        Data = DataObj0.ScaleData(StitchIt,Data);
        Image(:,:,:,nim) = StitchIt.CreateImage(Data,RxProfs);
        ReconObj.DispStatObj.TestDisplayInitialImages(Image(:,:,:,nim),['Image',num2str(ReconObj.RespPhaseImages2Do(nim))]);
        
    end
    clear StitchIt
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
function SetAcqInfoOffRes(ReconObj,val)    
    ReconObj.AcqInfoOffRes = val;
end
function SetReconNumber(ReconObj,val)    
    ReconObj.ReconNumber = val;
end
function SetRcvrs(ReconObj,val)    
    ReconObj.Rcvrs = val;
end
function SetOffResMap(ReconObj,val)    
    ReconObj.OffResMap = val;
end
function SetShift(ReconObj,val)    
    ReconObj.Shift = val;
    ReconObj.UseExternalShift = 1;
end
function SetOffResCorrection(ReconObj,val)    
    ReconObj.OffResCorrection = val;
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

end
end