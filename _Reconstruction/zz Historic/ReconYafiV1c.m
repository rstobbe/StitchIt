%==================================================================
% (V1c)
%   - Return Options
%==================================================================

classdef ReconYafiV1c < handle

properties (SetAccess = private)                   
    Method = 'ReconYafiV1c'
    BaseMatrix
    AcqInfo
    AcqInfoRxp
    ReconNumber = 1
    Rcvrs
    Shift
    UseExternalShift = 0
    OffResCorrection = 0
    ResetGpus = 1
    LowGpuRamCase = 0
    DispStatObj
    ObjectAtIso = 1
    ReturnType = 0
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = ReconYafiV1c()              
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

    %% TestSteadyState
    FirstDataPoints = DataObj0.ReturnFirstDataPointEachTraj(ReconObj.AcqInfo{ReconObj.ReconNumber});
    figure(1234);
    plot(abs(FirstDataPoints));

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

    %% RxProfs
    ReconObj.DispStatObj.Status('RxProfs',2);
    ReconObj.DispStatObj.Status('Load Data',3);
    if ReconObj.ObjectAtIso
        Data = DataObj0.ReturnYafiData(ReconObj.AcqInfoRxp,[]);
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
    Data0 = Data(:,:,:,1);                              % Use first image     
    % Data0 = Data(:,:,:,2);                                % Use second image 
    RxProfs = StitchIt.CreateImage(Data0);
    %--
    % ReconObj.DispStatObj.SetDisplayRxProfs(1);
    %--
    ReconObj.DispStatObj.TestDisplayRxProfs(RxProfs);
    clear('StitchIt','Data');
    
    %% Image
    ReconObj.DispStatObj.Status('Nufft Recon Return Channels Initialize',2);
    StitchIt = StitchItNufftV1a();
    StitchIt.Initialize(KernHolder,ReconObj.AcqInfo{ReconObj.ReconNumber}); 
    StitchIt.LoadRxProfs(RxProfs)
    Image = zeros([ReconObj.BaseMatrix,ReconObj.BaseMatrix,ReconObj.BaseMatrix,1,length(DataObjArr),3],'like',single(1+1i));
    for n = 1:length(DataObjArr)
        ReconObj.DispStatObj.Status(['Nufft Recon Return Channels ',num2str(n)],2);
        ReconObj.DispStatObj.Status('Load Data',3);
        if ReconObj.ObjectAtIso
            Data = DataObjArr{n}.DataObj.ReturnYafiData(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber);
        else
            % if ReconObj.UseExternalShift
            %     Data = DataObjArr{n}.DataObj.ReturnDataSetWithExternalShift(ReconObj.AcqInfo{ReconObj.ReconNumber},ReconObj.ReconNumber,ReconObj.Shift);
            % else
            %     Data = DataObj0.ReturnDataSetWithShift(ReconObj.ReconObj.AcqInfo{ReconObj.ReconNumber},[]);
            % end
        end
        Data = DataObjArr{n}.DataObj.ScaleData(KernHolder,Data);       
        ReconObj.DispStatObj.Status('Generate',3);
        for m = 1:2
            Image(:,:,:,:,n,m) = StitchIt.CreateImage(Data(:,:,:,m));
        end
        ImRat = abs(Image(:,:,:,:,n,2))./abs(Image(:,:,:,:,n,1));
        ImRat(ImRat > 1) = NaN;
        TrRat = DataObj0.DataInfo.ExpPars.Sequence.tr2/DataObj0.DataInfo.ExpPars.Sequence.tr1;
        if ReconObj.ReturnType == 0
            Image = (180*acos((TrRat*ImRat-1)./(TrRat-ImRat))/pi)/DataObj0.DataInfo.ExpPars.Sequence.flip;
        else
            Image(:,:,:,:,n,3) = (180*acos((TrRat*ImRat-1)./(TrRat-ImRat))/pi)/DataObj0.DataInfo.ExpPars.Sequence.flip;
        end
        % Image(:,:,:,:,n,4) = (TrRat*ImRat-1)./(TrRat-ImRat);
        % Image(:,:,:,:,n,5) = (TrRat*ImRat-1);
        % Image(:,:,:,:,n,6) = (TrRat-ImRat);
        % Image(:,:,:,:,n,7) = (ImRat);
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
function SetAcqInfoRxp(ReconObj,val)    
    ReconObj.AcqInfoRxp = val;
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