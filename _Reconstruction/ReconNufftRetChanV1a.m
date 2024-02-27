%==================================================================
% (V1a)
%   - If multi-image experiment, coil profile from first image
%==================================================================

classdef ReconNufftRetChanV1a < handle

properties (SetAccess = private)                   
    Method = 'ReconNufftRetChanV1a'
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
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconNufftRetChanV1a()              
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
    
    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon Return Channels',2);
    ReconObj.DispStatObj.Status('Initialize',3);
    if ReconObj.OffResCorrection
        error('not coded');
        StitchIt = StitchItNufftOffResV1a();
    else
        StitchIt = StitchItNufftReturnChannelsV1a(); 
    end
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfo{ReconObj.ReconNumber},DataObj0.RxChannels); 
    DataType = single(1 + 1i);
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,DataObj0.RxChannels,length(DataObjArr)],'like',DataType);
    for n = 1:length(DataObjArr)
        ReconObj.DispStatObj.Status(['Nufft Recon ',num2str(n)],2);
        ReconObj.DispStatObj.Status('Load Data',3);
        if ReconObj.UseExternalShift
            Data = DataObjArr{n}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
        else
            Data = DataObjArr{n}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        end
        Data = DataObjArr{n}.DataObj.ScaleData(StitchIt,Data);
        ReconObj.DispStatObj.Status('Generate',3);
        if ReconObj.OffResCorrection
            error('not coded');
            Image(:,:,:,:,n) = StitchIt.CreateImage(Data,RxProfs,OffResMapInt,OffResTimeArr);
        else
            Image(:,:,:,:,n) = StitchIt.CreateImage(Data);
        end
    end
    clear StichIt
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
function SetDisplayOffResMap(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayOffResMap(val);
end


end
end