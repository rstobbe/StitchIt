%==================================================================
% (V1a)
%   - 
%==================================================================

classdef ReconNufftV1a < handle

properties (SetAccess = private)                   
    Method = 'ReconNufftV1a'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    ReconNumber
    Rcvrs
    OffResMap
    Shift
    DoOffResCor = 'Yes'
    DisplayVerbose = 'No'
    ResetGpus = 'Yes'
    UseExternalShift = 0
    CompassCalling = 0
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconNufftV1a()              
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObjArr)     
    %% Test  
    if ~ReconObj.CompassCalling
        ReconObj.DisplayVerbose = 'No';
    end
    DataObj = DataObjArr{1}.DataObj;          % Recon designed for single image
    err.flag = 0;
    if ~strcmp(ReconObj.AcqInfo{ReconObj.ReconNumber}.name,DataObj.DataInfo.TrajName)
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
        DisplayStatusCompass(ReconObj,'Reset GPUs',2);
        for n = 1:gpuDeviceCount
            gpuDevice(n);
        end
    end
    
    %% RxProfs
    DisplayStatusCompass(ReconObj,'RxProfs',2);
    DisplayStatusCompass(ReconObj,'Load Data',3);
    if ReconObj.UseExternalShift
        Data = DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfoRxp,[],ReconObj.Shift);
    else
        Data = DataObj.ReturnDataSetWithShift(ReconObj.AcqInfoRxp,[]);
    end
    DisplayStatusCompass(ReconObj,'RxProfs: Initialize',3);
    StitchIt = StitchItReturnRxProfs();
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfoRxp,DataObj.RxChannels); 
    Data = DataObj.ScaleData(StitchIt,Data);
    DisplayStatusCompass(ReconObj,'RxProfs: Generate',3);
    RxProfs = StitchIt.CreateImage(Data);
    clear SitchIt

    %% Interpolate
    if strcmp(ReconObj.DoOffResCor,'Yes')
        DisplayStatusCompass(ReconObj,'Off Resonance Map',2);
        DisplayStatusCompass(ReconObj,'Interpolate',3);
        sz = size(ReconObj.OffResMap);
        OffResBaseMatrix = sz(1);
        Array = linspace((OffResBaseMatrix/ReconObj.BaseMatrix)/2,OffResBaseMatrix-(OffResBaseMatrix/ReconObj.BaseMatrix)/2,ReconObj.BaseMatrix) + 0.5;
        [X,Y,Z] = meshgrid(Array,Array,Array);
        OffResMapInt = interp3(ReconObj.OffResMap,X,Y,Z,'maximak');
        if strcmp(ReconObj.DisplayVerbose,'Yes')
            totgblnum = ImportOffResMapCompass(OffResMapInt,'OffResMapInt',[],[],max(abs(ReconObj.OffResMap(:))));
            Gbl2ImageOrtho('IM3',totgblnum);
        end
    end
    
    %% Sampling Timing
    OffResTimeArr = ReconObj.AcqInfo{ReconObj.ReconNumber}.OffResTimeArr;
    
    %% Image
    DisplayStatusCompass(ReconObj,'Nufft Recon',2);
    DisplayStatusCompass(ReconObj,'Load Data',3);
    if ReconObj.UseExternalShift
        Data = DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
    else
        Data = DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
    end
    DisplayStatusCompass(ReconObj,'Nufft Recon: Initialize',3);
    if strcmp(ReconObj.DoOffResCor,'Yes')
        StitchIt = StitchItSuperRegridInputRxProfOffRes();
    else
        StitchIt = StitchItSuperRegridInputRxProf(); 
    end
    StitchIt.SetBaseMatrix(ReconObj.BaseMatrix);
    StitchIt.SetFov2ReturnBaseMatrix;
    StitchIt.Initialize(ReconObj.AcqInfo{ReconObj.ReconNumber},DataObj.RxChannels); 
    Data = DataObj.ScaleData(StitchIt,Data);
    DisplayStatusCompass(ReconObj,'Nufft Recon: Generate',3);
    tic
    if strcmp(ReconObj.DoOffResCor,'Yes')
        Image = StitchIt.CreateImage(Data,RxProfs,OffResMapInt,OffResTimeArr);
    else
        Image = StitchIt.CreateImage(Data,RxProfs);
    end
    toc
    beep
    clear StichIt
    

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
function SetDoOffResCor(ReconObj,val)    
    ReconObj.DoOffResCor = val;
end
function SetDisplayVerbose(ReconObj,val)    
    ReconObj.DisplayVerbose = val;
end
function SetCompassCalling(ReconObj,val)    
    ReconObj.CompassCalling = val;
end
function SetUseExternalShift(ReconObj,val)    
    ReconObj.UseExternalShift = val;
end

end
end