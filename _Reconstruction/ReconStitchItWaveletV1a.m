%==================================================================
% (V1a)
%   - If multi-image experiment, coil profile from first image
%==================================================================

classdef ReconStitchItWaveletV1a < handle

properties (SetAccess = private)                   
    Method = 'ReconStitchItWaveletV1a'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    ReconNumber
    Rcvrs
    OffResMap
    Shift
    LevelsPerDim
    NumIterations
    Lambda
    MaxEig
    UseExternalShift = 0
    OffResCorrection = 1
    ResetGpus = 1
    DispStatObj
    DoMemRegister = 1
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconStitchItWaveletV1a() 
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

    %% Reset GPUs
    if ReconObj.ResetGpus
        ReconObj.DispStatObj.Status('Reset GPUs',2);
        for n = 1:gpuDeviceCount
            gpuDevice(n);
        end
    end
    
    %% RxProfs
    ReconObj.DispStatObj.Status('RxProfs',2);
    ReconObj.DispStatObj.Status('Load Data',3);
    if ReconObj.UseExternalShift
        Data = DataObj0.ReturnDataSetWithExternalShift(ReconObj.AcqInfoRxp,[],ReconObj.Shift);
    else
        Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoRxp,[]);
    end
    ReconObj.DispStatObj.Status('Initialize',3);
    StitchIt = StitchItReturnRxProfs();
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfoRxp,DataObj0.RxChannels); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate',3);
    RxProfs = StitchIt.CreateImage(Data);
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear SitchIt

    %% Interpolate
    if ReconObj.OffResCorrection
        ReconObj.DispStatObj.Status('Off Resonance Map',2);
        ReconObj.DispStatObj.Status('Interpolate',3);
        sz = size(ReconObj.OffResMap);
        OffResBaseMatrix = sz(1);
        Array = linspace((OffResBaseMatrix/ReconObj.BaseMatrix)/2,OffResBaseMatrix-(OffResBaseMatrix/ReconObj.BaseMatrix)/2,ReconObj.BaseMatrix) + 0.5;
        [X,Y,Z] = meshgrid(Array,Array,Array);
        OffResMapInt = interp3(ReconObj.OffResMap,X,Y,Z,'maximak');
        ReconObj.DispStatObj.TestDisplayOffResMap(OffResMapInt);
    end
    
    %% Sampling Timing
    OffResTimeArr = ReconObj.AcqInfo{ReconObj.ReconNumber}.OffResTimeArr;
    
    %% Initial Images
    ReconObj.DispStatObj.Status('Initial Images',2);
    ReconObj.DispStatObj.Status('Initialize',3);
    if ReconObj.OffResCorrection
        StitchIt = StitchItNufftOffResV1a();
    else
        StitchIt = StitchItNufftV1a(); 
    end
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfo{ReconObj.ReconNumber},DataObj0.RxChannels); 
    Image0 = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,length(DataObjArr)],'like',RxProfs);
    for n = 1:length(DataObjArr)
        ReconObj.DispStatObj.Status('Load Data',3);
        if ReconObj.UseExternalShift
            Data = DataObjArr{n}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
        else
            Data = DataObjArr{n}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        end
        Data = DataObjArr{n}.DataObj.ScaleData(StitchIt,Data);
        ReconObj.DispStatObj.Status('Generate',3);
        if ReconObj.OffResCorrection
            Image0(:,:,:,n) = StitchIt.CreateImage(Data,RxProfs,OffResMapInt,OffResTimeArr);
        else
            Image0(:,:,:,n) = StitchIt.CreateImage(Data,RxProfs);
        end
    end
    ReconObj.DispStatObj.TestDisplayInitialImages(Image0);
    clear StichIt
    
    %% Wavelet 
    ReconObj.DispStatObj.Status('StichItWavelet',2);    
    ReconObj.DispStatObj.Status('Initialize',3);
    if ReconObj.OffResCorrection
        StitchIt = StitchItWaveletOffResV1a(); 
    else
        StitchIt = StitchItWaveletV1a();
    end
    StitchIt.SetDoMemRegister(ReconObj.DoMemRegister);
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetLevelsPerDim(ReconObj.LevelsPerDim);
    StitchIt.SetNumIterations(ReconObj.NumIterations);
    StitchIt.SetLambda(ReconObj.Lambda);
    StitchIt.SetMaxEig(ReconObj.MaxEig);      
    RxChannels = DataObj0.RxChannels;
    StitchIt.Initialize(ReconObj.AcqInfo{ReconObj.ReconNumber},RxChannels,ReconObj.DispStatObj); 
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,length(DataObjArr)],'like',RxProfs);
    for n = 1:length(DataObjArr)
        if ReconObj.ResetGpus
            ReconObj.DispStatObj.Status('Reset GPUs',3);            % Would be nice to fix the memory leak
            for m = 1:gpuDeviceCount
                gpuDevice(m);
            end
        end 
        ReconObj.DispStatObj.Status('Load Data',3);
        if length(DataObjArr) > 1
            if ReconObj.UseExternalShift
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
            else
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
            end
        end
        Data = DataObjArr{n}.DataObj.ScaleData(StitchIt,Data);
        ReconObj.DispStatObj.Status('Generate',3);
        if ReconObj.OffResCorrection
            Image(:,:,:,n) = StitchIt.CreateImage(Data,RxProfs,OffResMapInt,OffResTimeArr,Image0(:,:,:,n));
        else
            Image(:,:,:,n) = StitchIt.CreateImage(Data,RxProfs,Image0(:,:,:,n));
        end
        AbsMaxEig(n) = abs(StitchIt.MaxEig);
    end
    ReconObj.SetMaxEig(AbsMaxEig);
    clear StitchIt
    ReconObj.DispStatObj.StatusClear();
end

%==================================================================
% Set
%==================================================================  
%% Set
function SetBaseMatrix(ReconObj,val)    
    ReconObj.BaseMatrix = val;
end
function SetDoMemRegister(ReconObj,val)    
    ReconObj.DoMemRegister = val;
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
function SetDisplayRxProfs(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayRxProfs(val);
end
function SetDisplayOffResMap(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayOffResMap(val);
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

end
end