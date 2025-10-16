%==================================================================
% (V1b)
%   - Option for 'ObjectAtIso'
%==================================================================

classdef ReconNufftRetChanV1b < handle

properties (SetAccess = private)                   
    Method = 'ReconNufftRetChanV1b'
    BaseMatrix
    AcqInfo
    ReconNumber = 1
    Rcvrs
    OffResMap
    Shift
    UseExternalShift = 0
    OffResCorrection = 0
    ResetGpus = 1
    LowGpuRamCase = 0
    ObjectAtIso = 0
    DispStatObj
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconNufftRetChanV1b()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObjArr)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconNufftRetChanV1b',1);
    
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

    %% Info
    % NumImages = DataObj0.DataInfo.ExpPars.Sequence.NumImages;
    NumImages = 1;
    if not(isfield(DataObj0.DataInfo.ExpPars.Sequence,'Dummies'))
        Dummies = 0;
    else
        Dummies = DataObj0.DataInfo.ExpPars.Sequence.Dummies;
    end
    NumTraj = ReconObj.AcqInfo{1}.NumTraj;
    TrajPerImage = NumTraj + Dummies;    

    %% Test
    FirstDataPoints0 = DataObj0.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{1});
    figure(1234); hold on;
    plot((1:TrajPerImage*NumImages),mean(abs(FirstDataPoints0),2),'b');
    for n = 1:NumImages
        plot(TrajPerImage*(n-1)+Dummies+(1:NumTraj),mean(abs(FirstDataPoints0(TrajPerImage*(n-1)+Dummies+(1:NumTraj),:)),2),'r');         
    end
    DataPreSamp = DataObj0.ReturnPreSampDataPlusTen(ReconObj.AcqInfo{1},1);
    MeanDataPreSamp = squeeze(mean(DataPreSamp,1));
    figure(2345); hold on;
    plot([ReconObj.AcqInfo{1}.SampStart ReconObj.AcqInfo{1}.SampStart],[-1 1],'k:')
    plot(abs(MeanDataPreSamp(1,:,1)),'k');
    plot(real(DataPreSamp(1,:,1)),'r');
    plot(imag(DataPreSamp(1,:,1)),'b');

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
        KernHolder.SetReducedSubSamp();           % Important for very large zero-fill.  
    end
    KernHolder.SetBaseMatrix(ReconObj.BaseMatrix);
    KernHolder.Initialize(ReconObj.AcqInfo{ReconObj.ReconNumber},DataObj0.RxChannels);    
    
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
    ReconObj.DispStatObj.Status('Nufft Recon Return Channels Initialize',2);
    if ReconObj.OffResCorrection
        error('not coded');
        %StitchIt = StitchItReturnChannelsOffRes();
    else
        StitchIt = StitchItReturnChannels(); 
    end
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber}); 
    DataType = single(1 + 1i);
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,DataObj0.RxChannels,length(DataObjArr)],'like',DataType);
    for n = 1:length(DataObjArr)
        ReconObj.DispStatObj.Status('Nufft Recon Return Channels',2);
        ReconObj.DispStatObj.Status('Load Data',3);
        if ReconObj.ObjectAtIso
            Data = DataObjArr{n}.DataObj.ReturnDataSetWithNoShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        else
            if ReconObj.UseExternalShift
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
            else
                Data = DataObjArr{n}.DataObj.ReturnDataSetWithShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
            end
        end
        Data = DataObjArr{n}.DataObj.ScaleData(KernHolder,Data);        % should update to 'KernHolder' everywhere
        ReconObj.DispStatObj.Status('Generate',3);
        if ReconObj.OffResCorrection
            error('not coded');
            %Image(:,:,:,:,n) = StitchIt.CreateImage(Data,RxProfs,OffResMapInt,OffResTimeArr);
        else
            Image(:,:,:,:,n) = StitchIt.CreateImage(Data);
        end
    end
    clear StitchIt
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
function SetLowGpuRamCase(ReconObj,val)    
    ReconObj.LowGpuRamCase = val;
end
function SetObjectAtIso(ReconObj,val)    
    ReconObj.ObjectAtIso = val;
end


end
end