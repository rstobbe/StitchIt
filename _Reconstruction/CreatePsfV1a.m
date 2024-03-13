%==================================================================
% 
%  
%==================================================================

classdef CreatePsfV1a < handle

properties (SetAccess = private)                   
    Method = 'CreatePsfV1a'
    BaseMatrix
    AcqInfo
    ResetGpus = 1
    DispStatObj
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = CreatePsfV1a()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj)         
    %% Reset GPUs
    err.flag = 0;
    if ReconObj.ResetGpus
        ReconObj.DispStatObj.Status('Reset GPUs',2);
        for n = 1:gpuDeviceCount
            gpuDevice(n);
        end
    end

    %% Create Psf
    ReconObj.DispStatObj.Status('Create Psf',2);
    StitchItPsf = StitchItNufftPsfV1a();                                          
    StitchItPsf.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchItPsf.SetSubSample(2.0);
    StitchItPsf.SetFov2ReturnGridMatrix;
    RxChannels = 1;
    StitchItPsf.Initialize(ReconObj.AcqInfo{1},RxChannels); 
    Data = ones([ReconObj.AcqInfo{1}.NumTraj,ReconObj.AcqInfo{1}.NumCol],'like',single(1+1i)); 
    Image = StitchItPsf.CreateImage(Data);

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