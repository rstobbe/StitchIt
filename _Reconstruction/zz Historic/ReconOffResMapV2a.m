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
    LowGpuRamCase = 0
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

    %% NufftKernel
    ReconObj.DispStatObj.Status('Load Nufft Kernel',2);
    KernHolder = NufftKernelHolder();
    if ReconObj.LowGpuRamCase
        KernHolder.SetReducedSubSamp();           % probably not a big savings...
    end
    KernHolder.SetBaseMatrix(ReconObj.BaseMatrix);
    KernHolder.Initialize(ReconObj.AcqInfoRxp,DataObj0.RxChannels);
    
    %% RxProfs
    ReconObj.DispStatObj.Status('RxProfs',2);
    ReconObj.DispStatObj.Status('Load Data',3);
    OffResImageNumber = 1;
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoRxp,OffResImageNumber);
    ReconObj.DispStatObj.Status('Initialize',3);
    StitchIt = StitchItReturnRxProfs();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfoRxp); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate',3);
    RxProfs = StitchIt.CreateImage(Data);
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear('StitchIt','Data');   
        
    %% Create Off Resonance Map Setup
    ReconObj.DispStatObj.Status('Off Resonance Map',2);
    ReconObj.DispStatObj.Status('Initialize1',3);
    OffResImageNumber = 1;
    StitchIt = StitchItNufftV1a();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfoOffRes{OffResImageNumber});
    StitchIt.LoadRxProfs(RxProfs)   
    ReconObj.DispStatObj.Status('Load Data1',3);
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoOffRes{OffResImageNumber},OffResImageNumber);        
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate Image1',3);
    Image1 = StitchIt.CreateImage(Data);
    ReconObj.DispStatObj.TestDisplayInitialImages(Image1,'OffResImage1');
    clear('StitchIt');
    
    ReconObj.DispStatObj.Status('Initialize2',3);
    OffResImageNumber = 2;
    StitchIt = StitchItNufftV1a();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfoOffRes{OffResImageNumber});
    StitchIt.LoadRxProfs(RxProfs)   
    ReconObj.DispStatObj.Status('Load Data2',3);
    Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoOffRes{OffResImageNumber},OffResImageNumber);        
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate Image2',3);
    Image2 = StitchIt.CreateImage(Data);
    ReconObj.DispStatObj.TestDisplayInitialImages(Image2,'OffResImage2');
    clear('StitchIt');
    
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
    %-----
    %OffResMap(OffResMap < -200) = 0;        % was added without version change.  
    %-----
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