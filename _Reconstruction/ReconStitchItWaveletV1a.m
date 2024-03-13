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
    Image0
    UseExternalShift = 0
    OffResCorrection = 1
    CreateInitialImage = 1
    ResetGpus = 1
    DispStatObj
    LowRamCase = 0
    LowGpuRamCase = 0
    IntensityCorrection = 1
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
    %% Status Display
    ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconStitchItWavelet',1);
    
    %% Test  
    Image = [];
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
    Test = ReconObj.AcqInfo{1}.ReconInfoMat(4,1,1);
    if Test == 1
        err.flag = 1;
        err.msg = 'Reload Recon_File';
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
    if ReconObj.UseExternalShift
        Data = DataObj0.ReturnDataSetWithExternalShift(ReconObj.AcqInfoRxp,[],ReconObj.Shift);
    else
        Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoRxp,[]);
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
        if ReconObj.UseExternalShift
            Data = DataObjArr{1}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
        else
            Data = DataObjArr{1}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        end
        ReconObj.DispStatObj.Status('Initialize',3);
        StitchIt = StitchItNufftV1a();
        StitchIt.Nufft.SetUseSdc(0);
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
        StitchIt.LoadRxProfs(RxProfs);  
        ReconObj.DispStatObj.Status('Generate',3);
        IntenseCor = StitchIt.CreateImage(Data);
        %totgblnum = ImportImageCompass(Image,'IntensCorTest');
        %Gbl2ImageOrtho('IM3',totgblnum);
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
    
    %% Initial Images
    if ReconObj.CreateInitialImage
        ReconObj.DispStatObj.Status('Initial Images',2);
        ReconObj.DispStatObj.Status('Initialize',3);
        if ReconObj.OffResCorrection
            StitchIt = StitchItNufftOffResV1a();
            StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
            StitchIt.LoadRxProfs(RxProfs);         
            StitchIt.LoadOffResonance(ReconObj.OffResMap,OffResTimeArr);
        else
            StitchIt = StitchItNufftV1a();
            StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber});
            StitchIt.LoadRxProfs(RxProfs);
        end
        ReconObj.Image0 = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,length(DataObjArr)],'like',single(1+1i));
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
            ReconObj.Image0(:,:,:,n) = StitchIt.CreateImage(Data);
        end
        clear('StitchIt');
    end
    ReconObj.DispStatObj.TestDisplayInitialImages(ReconObj.Image0,'Image0');
    
    %% Wavelet 
    ReconObj.DispStatObj.Status('StichItWavelet',2);    
    ReconObj.DispStatObj.Status('Initialize',3);
    if ReconObj.OffResCorrection
        StitchIt = StitchItWaveletOffResV1a();
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.DispStatObj);
        StitchIt.LoadRxProfs(RxProfs);         
        StitchIt.LoadOffResonance(ReconObj.OffResMap,OffResTimeArr);
        clear('RxProfs','KernHolder','OffResTimeArr');
        ReconObj.OffResMap = [];
    else
        StitchIt = StitchItWaveletV1a();
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.DispStatObj);
        StitchIt.LoadRxProfs(RxProfs);
        clear('RxProfs','KernHolder');
    end
    StitchIt.SetLevelsPerDim(ReconObj.LevelsPerDim);
    StitchIt.SetNumIterations(ReconObj.NumIterations);
    StitchIt.SetLambda(ReconObj.Lambda);
    StitchIt.SetMaxEig(ReconObj.MaxEig);      

    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,length(DataObjArr)],'like',single(1+1i));
    for n = 1:length(DataObjArr)
        ReconObj.DispStatObj.Status('Load Data',3);
        if length(DataObjArr) > 1 || ReconObj.CreateInitialImage == 0
            if ReconObj.UseExternalShift
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
            else
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
            end
        end
        Data = DataObjArr{n}.DataObj.ScaleData(StitchIt,Data);
        ReconObj.DispStatObj.Status('Generate',3);
        if ReconObj.IntensityCorrection
            Image(:,:,:,n) = StitchIt.CreateImage(Data,ReconObj.Image0(:,:,:,n)) .* abs(IntenseCor);
        else
            Image(:,:,:,n) = StitchIt.CreateImage(Data,ReconObj.Image0(:,:,:,n));
        end
        AbsMaxEig(n) = abs(StitchIt.MaxEig);
    end
    ReconObj.SetMaxEig(AbsMaxEig);
    clear('StitchIt');
    ReconObj.DispStatObj.StatusClear();
end

%==================================================================
% Set
%==================================================================  
%% Set
function SetBaseMatrix(ReconObj,val)    
    ReconObj.BaseMatrix = val;
end
function SetLowRamCase(ReconObj,val)    
    ReconObj.LowRamCase = val;
end
function SetLowGpuRamCase(ReconObj,val)    
    ReconObj.LowGpuRamCase = val;
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
function SetImage0(ReconObj,val) 
    ReconObj.CreateInitialImage = 0;
    ReconObj.Image0 = val;
end


end
end