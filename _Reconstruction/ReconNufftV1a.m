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
    ReconNumber = 1
    Rcvrs
    OffResMap
    Shift
    UseExternalShift = 0
    OffResCorrection = 0
    ResetGpus = 1
    DispStatObj
    LowGpuRamCase = 0
    IntensityCorrection = 0
    ObjectAtIso = 1
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconNufftV1a()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObjArr)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconNufft',1);
    
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
    if ReconObj.ObjectAtIso
        Data = DataObj0.ReturnDataSet(ReconObj.AcqInfoRxp,[]);
    else
        if ReconObj.UseExternalShift
            Data = DataObj0.ReturnDataSetWithExternalShift(ReconObj.AcqInfoRxp,[],ReconObj.Shift);
        else
            Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoRxp,[]);
        end
    end
    ReconObj.DispStatObj.Status('Initialize',3);
    StitchIt = StitchItReturnRxProfs();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfoRxp); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate',3);
    RxProfs = StitchIt.CreateImage(Data);
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear('StitchIt','Data');

    %% Intensity Correction
    if ReconObj.IntensityCorrection
        ReconObj.DispStatObj.Status('Intensity Correction',2);
        ReconObj.DispStatObj.Status('Load Data',3);
        if ReconObj.ObjectAtIso
            Data = DataObjArr{1}.DataObj.ReturnDataSet(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        else
            if ReconObj.UseExternalShift
                Data = DataObjArr{1}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
            else
                Data = DataObjArr{1}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
            end
        end
        ReconObj.DispStatObj.Status('Initialize',3);
        StitchIt = StitchItNufftV1a();
        StitchIt.Nufft.SetUseSdc(0);
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
        StitchIt.LoadRxProfs(RxProfs);  
        ReconObj.DispStatObj.Status('Generate',3);
        IntenseCor = StitchIt.CreateImage(Data);
        ReconObj.DispStatObj.TestDisplayIntensityCorrection(IntenseCor);
        clear('StitchIt','Data');
    end
    
    %% Interpolate
    if ReconObj.OffResCorrection
        sz = size(ReconObj.OffResMap);
        if sz(1) ~= ReconObj.BaseMatrix
            ReconObj.DispStatObj.Status('Off Resonance Map',2);
            ReconObj.DispStatObj.Status('Interpolate',3);
            sz = size(ReconObj.OffResMap);
            OffResBaseMatrix = sz(1);
            Array = linspace((OffResBaseMatrix/ReconObj.BaseMatrix)/2,OffResBaseMatrix-(OffResBaseMatrix/ReconObj.BaseMatrix)/2,ReconObj.BaseMatrix) + 0.5;
            [X,Y,Z] = meshgrid(Array,Array,Array);
            ReconObj.OffResMap = interp3(ReconObj.OffResMap,X,Y,Z,'maximak');
            clear('Array','X','Y','Z');
        end
        ReconObj.DispStatObj.TestDisplayOffResMap(ReconObj.OffResMap);
    end
    
    %% Sampling Timing
    OffResTimeArr = ReconObj.AcqInfo{ReconObj.ReconNumber}.OffResTimeArr;
    
    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon',2);
    ReconObj.DispStatObj.Status('Initialize',3);
    if ReconObj.OffResCorrection
        StitchIt = StitchItNufftOffResV1a();
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
        StitchIt.LoadRxProfs(RxProfs);         
        StitchIt.LoadOffResonance(ReconObj.OffResMap,OffResTimeArr);
        clear('RxProfs','KernHolder','OffResTimeArr');
        ReconObj.OffResMap = [];
    else
        StitchIt = StitchItNufftV1a();
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
        StitchIt.LoadRxProfs(RxProfs)
        clear('RxProfs','KernHolder');
    end
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,length(DataObjArr)],'like',single(1+1i));
    
    for n = 1:length(DataObjArr)
        ReconObj.DispStatObj.Status(['Nufft Recon ',num2str(n)],2);
        ReconObj.DispStatObj.Status('Load Data',3);
        if ReconObj.ObjectAtIso
            Data = DataObjArr{n}.DataObj.ReturnDataSet(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        else
            if ReconObj.UseExternalShift
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
            else
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
            end
        end
        Data = DataObjArr{n}.DataObj.ScaleData(StitchIt,Data);
        ReconObj.DispStatObj.Status('Generate',3);
        if ReconObj.IntensityCorrection
            Image(:,:,:,n) = StitchIt.CreateImage(Data) .* abs(IntenseCor);
        else
            Image(:,:,:,n) = StitchIt.CreateImage(Data);
        end
    end
    clear('StitchIt');
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
function SetIntensityCorrection(ReconObj,val)    
    ReconObj.IntensityCorrection = val;
end
function SetUseExternalShift(ReconObj,val)    
    ReconObj.UseExternalShift = val;
end
function SetObjectAtIso(ReconObj,val)    
    ReconObj.ObjectAtIso = val;
end
function SetDisplayRxProfs(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayRxProfs(val);
end
function SetDisplayIntensityCorrection(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayIntensityCorrection(val);
end
function SetDisplayOffResMap(ReconObj,val)    
    ReconObj.DispStatObj.SetDisplayOffResMap(val);
end
function SetLowGpuRamCase(ReconObj,val)    
    ReconObj.LowGpuRamCase = val;
end

end
end