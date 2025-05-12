%==================================================================
% (V2b)
%   - Mask value to input
%==================================================================

classdef ReconYafiV2b < handle

properties (SetAccess = private)                   
    Method = 'ReconYafiV2b'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    Rcvrs
    Shift
    UseExternalShift = 0
    OffResCorrection = 0
    ResetGpus = 1
    LowGpuRamCase = 0
    DispStatObj
    ObjectAtIso = 1
    ReturnType = 0
    Mean1
    Mean2
    Ratio
    MaskVal
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconYafiV2b()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj,DataObjArr)     
    %% Status Display
    %ReconObj.DispStatObj.StatusClear();
    ReconObj.DispStatObj.Status('ReconYafiV1c',1);
    
    %% Test  
    DataObj0 = DataObjArr{1}.DataObj;
    ReconObj.DispStatObj.SetDataObj(DataObj0);
    err.flag = 0;
    if ~strcmp(ReconObj.AcqInfo{1}.name,DataObj0.DataInfo.TrajName)
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
    if length(ReconObj.AcqInfo) ~= 2
        err.flag = 1;
        err.msg = 'This Recon_File Not for Yafi2';
        return
    end

    %% TestSteadyState
    FirstDataPoints = DataObj0.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{1});
    ReconObj.Mean1 = mean(abs(FirstDataPoints(21:2:end,1)));        % channel 1
    ReconObj.Mean2 = mean(abs(FirstDataPoints(22:2:end,1)));
    ReconObj.Ratio = ReconObj.Mean1/ReconObj.Mean2;
    Fh = figure(1234); 
    subplot(1,2,1); hold on;
    plot(abs(FirstDataPoints(1:2:end,1)));
    plot(abs(FirstDataPoints(2:2:end,1)));
    ylim([0 25])
    subplot(1,2,2); hold on;
    plot(abs(FirstDataPoints(1:2:end,1))./abs(FirstDataPoints(2:2:end,1)));
    ylim([1 3]);
    Fh.Position = [700 700 1000 400];

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
    KernHolder.Initialize(ReconObj.AcqInfo{1},DataObj0.RxChannels);    

    %% RxProfs
    ReconObj.DispStatObj.Status('RxProfs',2);
    ReconObj.DispStatObj.Status('Load Data',3);
    if ReconObj.ObjectAtIso
        Data = DataObj0.ReturnYafi2Data(ReconObj.AcqInfoRxp,[]);
    else
        % if ReconObj.UseExternalShift
        %     Data = DataObj0.ReturnDataSetWithExternalShift(ReconObj.AcqInfoRxp,[],ReconObj.Shift);
        % else
        %     Data = DataObj0.ReturnDataSetWithShift(ReconObj.AcqInfoRxp,[]);
        % end
    end
    ReconObj.DispStatObj.Status('Initialize',3);
    StitchIt = StitchItReturnRxProfs();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfoRxp); 
    Data = DataObj0.ScaleData(StitchIt,Data);
    ReconObj.DispStatObj.Status('Generate',3);
    Data0 = Data(:,:,:,1);                                                  % Doesn't matter which Rxp to use (either first or second image - gets divided out)
    % Data0 = Data(:,:,:,2);
    RxProfs = StitchIt.CreateImage(Data0);
    %--
    % ReconObj.DispStatObj.SetDisplayRxProfs(1);
    %--
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear('StitchIt','Data');
    
    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon',2);
    StitchIt = StitchItNufftV1a();
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,1,length(DataObjArr),3],'like',single(1+1i));
    ReconObj.DispStatObj.Status('Load Data',3);
    if ReconObj.ObjectAtIso
        Data = DataObj0.ReturnYafi2Data(ReconObj.AcqInfo{n},n);
    else
        % if ReconObj.UseExternalShift
        %     Data = DataObj0.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{n},n,ReconObj.Shift);
        % else
        %     Data = DataObj0.ReturnDataSetWithShift(ReconObj.ReconObj.AcqInfo{n},[]);
        % end
    end
    Data = DataObj0.ScaleData(KernHolder,Data);  
    for n = 1:2
        StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{n}); 
        StitchIt.LoadRxProfs(RxProfs)
        ReconObj.DispStatObj.Status(['Generate ',num2str(n)],3);
        Image(:,:,:,:,:,n) = StitchIt.CreateImage(Data(:,:,:,n));
    end
    ImageMasked = Image;
    ImageMasked(abs(ImageMasked) < ReconObj.MaskVal*max(abs(ImageMasked(:)))) = NaN;
    ImRat = abs(ImageMasked(:,:,:,:,:,2))./abs(ImageMasked(:,:,:,:,:,1));
    ImRat(ImRat > 1) = NaN;
    TrRat = DataObj0.DataInfo.ExpPars.Sequence.tr2/DataObj0.DataInfo.ExpPars.Sequence.tr1;
    if ReconObj.ReturnType == 0
        Image = (180*acos((TrRat*ImRat-1)./(TrRat-ImRat))/pi)/DataObj0.DataInfo.ExpPars.Sequence.flip;
    else
        Image(:,:,:,:,:,3) = (180*acos((TrRat*ImRat-1)./(TrRat-ImRat))/pi)/DataObj0.DataInfo.ExpPars.Sequence.flip;
    end
    % Image(:,:,:,:,n,4) = (TrRat*ImRat-1)./(TrRat-ImRat);
    % Image(:,:,:,:,n,5) = (TrRat*ImRat-1);
    % Image(:,:,:,:,n,6) = (TrRat-ImRat);
    % Image(:,:,:,:,n,7) = (ImRat);

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
function SetAcqInfoRxp(ReconObj,val)    
    ReconObj.AcqInfoRxp = val;
end
function SetMaskVal(ReconObj,val)    
    ReconObj.MaskVal = val;
end
function SetReconNumber(ReconObj,val)    
    ReconObj.ReconNumber = val;
end
function SetRcvrs(ReconObj,val)    
    ReconObj.Rcvrs = val;
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
function SetLowGpuRamCase(ReconObj,val)    
    ReconObj.LowGpuRamCase = val;
end
function SetReturnType(ReconObj,val)    
    ReconObj.ReturnType = val;
end

end
end