%==================================================================
% (V1a)
%   - 
%==================================================================

classdef ReconOffResMapV1a < handle

properties (SetAccess = private)                   
    Method = 'ReconOffResMapV1a'
    BaseMatrix
    AcqInfoOffRes
    Rcvrs
    ResetGpus = 1
    DispStatObj
    RelMaskVal
    KernRad
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconOffResMapV1a()              
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
    
    %% Create Off Resonance Map
    ReconObj.DispStatObj.Status('Off Resonance Map',2);
    OffResImageNumber = 1;
    ReconObj.DispStatObj.Status('Load Data',3);
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoOffRes{OffResImageNumber},OffResImageNumber);        
    ReconObj.DispStatObj.Status('Image1: Initialize',3);
    StitchIt = StitchItNufftReturnChannelsV1a(); 
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    RxChannels = DataObj0.RxChannels;
    StitchIt.Initialize(ReconObj.AcqInfoOffRes{OffResImageNumber},RxChannels); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Image1: Generate',3);
    Image1 = StitchIt.CreateImage(Data);
    
    OffResImageNumber = 2;
    ReconObj.DispStatObj.Status('Load Data',3);
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoOffRes{OffResImageNumber},OffResImageNumber);        
    ReconObj.DispStatObj.Status('Image2: Initialize',3);
    StitchIt = StitchItNufftReturnChannelsV1a(); 
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    RxChannels = DataObj0.RxChannels;
    StitchIt.Initialize(ReconObj.AcqInfoOffRes{OffResImageNumber},RxChannels); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Image2: Generate',3);
    Image2 = StitchIt.CreateImage(Data);
    
    ReconObj.DispStatObj.Status('Combine Images',3);
    Image = cat(5,Image1,Image2);
    RefCoil = 5;
    Vox = ReconObj.AcqInfoOffRes{OffResImageNumber}.Fov./ReconObj.BaseMatrix;
    Vox = [Vox Vox Vox];
    %--
    %tic
    %[Image,Sens] = AdaptiveCmbRws(Image,Vox,RefCoil,ReconObj.KernRad);
    [Image,Sens] = AdaptiveCmbRws2(Image,Vox,RefCoil,ReconObj.KernRad);        % no time penalty for this - same data // small time-saving with smaller kernval
    %toc
    %--
    ReconObj.DispStatObj.TestDisplaySensitivityMaps(Sens);
    ReconObj.DispStatObj.TestDisplayCombinedImages(Image);

    ReconObj.DispStatObj.Status('Create Map',3);
    TimeDiff = (ReconObj.AcqInfoOffRes{2}.SampStartTime - ReconObj.AcqInfoOffRes{1}.SampStartTime)/1000;
    OffResMap0 = (angle(Image(:,:,:,2))-angle(Image(:,:,:,1)))/(2*pi*TimeDiff);
    OffResMap = single(OffResMap0);
    
    MaxFreq = 0.5/TimeDiff;    
    OffResMap(OffResMap0 < -MaxFreq) = 1/TimeDiff + OffResMap0(OffResMap0 < -MaxFreq);
    OffResMap(OffResMap0 > MaxFreq) = OffResMap0(OffResMap0 > MaxFreq) - 1/TimeDiff;
    
    MaskImage = abs(Image(:,:,:,1));
    OffResMap(MaskImage < ReconObj.RelMaskVal*max(MaskImage(:))) = 0;
    MaskImage = abs(Image(:,:,:,2));
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
function SetRcvrs(ReconObj,val)    
    ReconObj.Rcvrs = val;
end
function SetRelMaskVal(ReconObj,val)    
    ReconObj.RelMaskVal = val;
end
function SetKernRad(ReconObj,val)    
    ReconObj.KernRad = val;
end
function SetDisplayCombinedImages(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayCombinedImages(val);
end
function SetDisplaySensitivityMaps(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplaySensitivityMaps(val);
end


end
end