%==================================================================
% (V2a)
%   - Use Rxp 
%==================================================================

classdef ReconOffResMapV2a < handle

properties (SetAccess = private)                   
    Method = 'ReconOffResMapV2a'
    BaseMatrix
    AcqInfoOffRes
    AcqInfoRxp
    Rcvrs
    ResetGpus = 1
    DispStatObj
    RelMaskVal
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconOffResMapV2a()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateOffResMap
%==================================================================  
function [OffResMap,err] = CreateOffResMap(ReconObj,DataObjArr)     
    %% Test  
    DataObj0 = DataObjArr{1}.DataObj;
    ReconObj.DispStatObj.SetDataObj(DataObj0);
    err.flag = 0;
    if ~strcmp(ReconObj.AcqInfoOffRes{1}.name,DataObj0.DataInfo.TrajName)
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
    OffResImageNumber = 1;
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoRxp,OffResImageNumber);
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
        
    %% Create Off Resonance Map
    ReconObj.DispStatObj.Status('Off Resonance Map',2);
    OffResImageNumber = 1;
    ReconObj.DispStatObj.Status('Load Data',3);
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoOffRes{OffResImageNumber},OffResImageNumber);        
    ReconObj.DispStatObj.Status('Image1: Initialize',3);
    StitchIt = StitchItNufftV1a(); 
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfoOffRes{OffResImageNumber},DataObj0.RxChannels); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Image1: Generate',3);
    Image1 = StitchIt.CreateImage(Data,RxProfs);
    ReconObj.DispStatObj.TestDisplayInitialImages(Image1,'OffResImage1');
    
    OffResImageNumber = 2;
    ReconObj.DispStatObj.Status('Load Data',3);
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoOffRes{OffResImageNumber},OffResImageNumber);        
    ReconObj.DispStatObj.Status('Image2: Initialize',3);
    StitchIt = StitchItNufftV1a(); 
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfoOffRes{OffResImageNumber},DataObj0.RxChannels); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Image2: Generate',3);
    Image2 = StitchIt.CreateImage(Data,RxProfs);
    ReconObj.DispStatObj.TestDisplayInitialImages(Image2,'OffResImage2');
    
    ReconObj.DispStatObj.Status('Create Map',3);
    TimeDiff = (ReconObj.AcqInfoOffRes{2}.SampStartTime - ReconObj.AcqInfoOffRes{1}.SampStartTime)/1000;
    OffResMap0 = (angle(Image2)-angle(Image1))/(2*pi*TimeDiff);
    OffResMap = single(OffResMap0);
    
    MaxFreq = 0.5/TimeDiff;    
    OffResMap(OffResMap0 < -MaxFreq) = 1/TimeDiff + OffResMap0(OffResMap0 < -MaxFreq);
    OffResMap(OffResMap0 > MaxFreq) = OffResMap0(OffResMap0 > MaxFreq) - 1/TimeDiff;
    
    MaskImage = abs(Image1);
    OffResMap(MaskImage < ReconObj.RelMaskVal*max(MaskImage(:))) = 0;
    MaskImage = abs(Image2);
    OffResMap(MaskImage < ReconObj.RelMaskVal*max(MaskImage(:))) = 0;

end

%==================================================================
% Set
%==================================================================  
%% Set
function SetBaseMatrix(ReconObj,val)    
    ReconObj.BaseMatrix = val;
end
function SetAcqInfoOffRes(ReconObj,val)    
    ReconObj.AcqInfoOffRes = val;
end
function SetAcqInfoRxp(ReconObj,val)    
    ReconObj.AcqInfoRxp = val;
end
function SetRcvrs(ReconObj,val)    
    ReconObj.Rcvrs = val;
end
function SetRelMaskVal(ReconObj,val)    
    ReconObj.RelMaskVal = val;
end
function SetDisplayInitialImages(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayInitialImages(val);
end
function SetDisplayRxProfs(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayRxProfs(val);
end


end
end