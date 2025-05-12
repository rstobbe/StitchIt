%================================================================
%  
%================================================================

classdef SiemensStitchItDataObject < handle

    properties (SetAccess = private)                    
        DataFile; DataPath; DataName;
        DataScanHeaderBytes = 192;
        DataChannelHeaderBytes = 32; 
        DataHdr;
        DataDims;
        DataMem;
        DataInfo;
        AcqsPerImage;
        TotalAcqs;
        RxChannels;
        NumAverages;
        FovShift = [0 0 0]
        FirstSampDelay
    end
    methods 

%==================================================================
% Constructor
%==================================================================   
        function obj = SiemensStitchItDataObject(DataFile)
            ind = strfind(DataFile,filesep);
            if isempty(ind)
                error('Data path not specified properly');
            end
            obj.DataPath = DataFile(1:ind(end));
            obj.DataFile = DataFile(ind(end)+1:end);
            if strcmp(DataFile(ind(end)+1:ind(end)+4),'meas')
                obj.DataName = DataFile(ind(end)+6:end-4);
            else
                obj.DataName = DataFile(ind(end)+1:end-4);
            end
        end                

%==================================================================
% Initialize
%==================================================================           
        function Initialize(obj)
            ReadSiemensDataInfo(obj,[obj.DataPath,obj.DataFile]);
            obj.NumAverages = obj.DataHdr.lAverages; 
            if obj.DataDims.NAve < obj.DataHdr.lAverages
                obj.AcqsPerImage = obj.DataDims.Lin/obj.DataHdr.lAverages;                                    % includes dummies
            else
                obj.AcqsPerImage = obj.DataDims.Lin; 
            end
            obj.TotalAcqs = obj.AcqsPerImage * obj.NumAverages;   
            obj.RxChannels = obj.DataDims.NCha;  
        end  

%==================================================================
% ReturnFirstDataPointEachTraj
%==================================================================         
        function Data = ReturnFirstDataPointEachTraj(obj,AcqInfo)
            QDataMemPosArr = uint64(obj.DataMem.Pos(:) + obj.DataScanHeaderBytes);                                  
            QDataReadSize = obj.DataChannelHeaderBytes/8 + obj.DataDims.NCol;
            QDataStart = obj.DataChannelHeaderBytes/8 + AcqInfo.SampStart;
            QDataCol = 1;
            QDataCha = obj.DataDims.NCha;
            QDataBlockLength = length(obj.DataMem.Pos);
            QDataInfo = uint64([QDataReadSize QDataStart QDataCol QDataCha QDataBlockLength]);
            Data = 1000 * BuildComplexDataArray([obj.DataPath,obj.DataFile],QDataMemPosArr,QDataInfo);
            Data = squeeze(permute(Data,[2 1 3]));       % for now
        end

%==================================================================
% ReturnDataSetWithNoShift
%================================================================== 
        function Data = ReturnDataSetWithNoShift(obj,AcqInfo,ReconNumber) 
            Data = obj.ReturnDataSet(AcqInfo,ReconNumber); 
        end

%==================================================================
% ReturnDataSetWithShift
%================================================================== 
        function Data = ReturnDataSetWithShift(obj,AcqInfo,ReconNumber) 
            Data = obj.ReturnDataSet(AcqInfo,ReconNumber); 
            ReconInfoMat = AcqInfo.ReconInfoMat(1:3,:,:);
            ScaledFovShift(1) = -obj.FovShift(2)/1000;
            ScaledFovShift(2) = obj.FovShift(1)/1000;
            ScaledFovShift(3) = -obj.FovShift(3)/1000;
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat = repmat(PhaseShift,1,1,obj.RxChannels);
            Data = Data.*PhaseShiftMat;
        end

%==================================================================
% ReturnAllAveragedDataWithShift
%================================================================== 
        function Data = ReturnAllAveragedDataWithShift(obj,AcqInfo,ReconNumber) 
            Data = obj.ReturnAllData(AcqInfo,ReconNumber); 
            ReconInfoMat = AcqInfo.ReconInfoMat(1:3,:,:);
            ScaledFovShift(1) = -obj.FovShift(2)/1000;
            %ScaledFovShift(2) = obj.FovShift(1)/1000;             
            ScaledFovShift(2) = -obj.FovShift(1)/1000;                  % probably should be fixed for above and below.  
            ScaledFovShift(3) = -obj.FovShift(3)/1000;
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat = repmat(PhaseShift,obj.NumAverages,1,obj.RxChannels);
            Data = Data.*PhaseShiftMat;
        end        

%==================================================================
% ReturnYafiDataWithShift
%================================================================== 
        function Data = ReturnYafiDataWithShift(obj,AcqInfo,ReconNumber) 
            Data0 = obj.ReturnAllData(AcqInfo,ReconNumber);
            sz = size(Data0);
            Data = zeros(sz(1)/2,sz(2),sz(3),2,'single');
            Data(:,:,:,1) = Data0(1:2:end,:,:);
            Data(:,:,:,2) = Data0(2:2:end,:,:);
            Data = Data(AcqInfo.Dummies+1:end,:,:,:);                   
            ReconInfoMat = AcqInfo.ReconInfoMat(1:3,:,:);
            ScaledFovShift(1) = -obj.FovShift(2)/1000;
            %ScaledFovShift(2) = obj.FovShift(1)/1000;             
            ScaledFovShift(2) = -obj.FovShift(1)/1000;                  % probably should be fixed for above and below.  
            ScaledFovShift(3) = -obj.FovShift(3)/1000;
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat = repmat(PhaseShift,1,1,obj.RxChannels,2);
            Data = Data.*PhaseShiftMat;
        end         

%==================================================================
% ReturnYafiData
%================================================================== 
        function Data = ReturnYafiData(obj,AcqInfo,ReconNumber) 
            Data0 = obj.ReturnAllData(AcqInfo,ReconNumber);
            sz = size(Data0);
            Data = zeros(sz(1)/2,sz(2),sz(3),2,'single');
            Data(:,:,:,1) = Data0(1:2:end,:,:);
            Data(:,:,:,2) = Data0(2:2:end,:,:);
            Data = Data(AcqInfo.Dummies+1:end,:,:,:);    
        end 

%==================================================================
% ReturnYafi2Data
%================================================================== 
        function Data = ReturnYafi2Data(obj,AcqInfo) 
            Data0 = obj.ReturnAllData(AcqInfo,[]);
            Data0 = Data0(AcqInfo.Dummies+1:end,:,:,:); 
            sz = size(Data0);
            Data = zeros(sz(1)/2,sz(2),sz(3),2,'single');
            Data(:,:,:,1) = Data0(1:2:end,:,:);
            Data(:,:,:,2) = Data0(2:2:end,:,:);   
        end 

%==================================================================
% ReturnYafi2DataWithExternalShift
%================================================================== 
        function Data = ReturnYafi2DataWithExternalShift(obj,AcqInfo,ExtFovShift) 
            Data0 = obj.ReturnAllData(AcqInfo{1},[]);
            Data0 = Data0(AcqInfo{1}.Dummies+1:end,:,:,:); 
            sz = size(Data0);
            Data = zeros(sz(1)/2,sz(2),sz(3),2,'single');
            Data(:,:,:,1) = Data0(1:2:end,:,:);
            Data(:,:,:,2) = Data0(2:2:end,:,:);   
            ScaledFovShift(1) = -ExtFovShift(2)/1000;
            ScaledFovShift(2) = ExtFovShift(1)/1000;
            ScaledFovShift(3) = -ExtFovShift(3)/1000;
            ReconInfoMat = AcqInfo{1}.ReconInfoMat(1:3,:,:); 
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat(:,:,:,1) = repmat(PhaseShift,1,1,obj.RxChannels);
            ReconInfoMat = AcqInfo{2}.ReconInfoMat(1:3,:,:); 
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat(:,:,:,2) = repmat(PhaseShift,1,1,obj.RxChannels);
            Data = Data.*PhaseShiftMat;
        end 

%==================================================================
% ReturnYafi2RxpDataWithExternalShift
%================================================================== 
        function Data = ReturnYafi2RxpDataWithExternalShift(obj,AcqInfo,ExtFovShift) 
            Data0 = obj.ReturnAllData(AcqInfo,[]);
            Data0 = Data0(AcqInfo.Dummies+1:end,:,:,:); 
            sz = size(Data0);
            Data = zeros(sz(1)/2,sz(2),sz(3),1,'single');
            Data(:,:,:,1) = Data0(1:2:end,:,:);                         % AcqInfoRxp is associated with the first image only.
            ReconInfoMat = AcqInfo.ReconInfoMat(1:3,:,:);
            ScaledFovShift(1) = -ExtFovShift(2)/1000;
            ScaledFovShift(2) = ExtFovShift(1)/1000;
            ScaledFovShift(3) = -ExtFovShift(3)/1000;
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat = repmat(PhaseShift,1,1,obj.RxChannels,1);
            Data = Data.*PhaseShiftMat;
        end

%==================================================================
% ReturnYvf2Data
%================================================================== 
        function Data = ReturnYvf2Data(obj,AcqInfo,ReconNumber) 
            Data0 = obj.ReturnAllData(AcqInfo,ReconNumber);
            sz = size(Data0);
            Data = zeros(AcqInfo.NumTraj,sz(2),sz(3),2,'single');
            Start = AcqInfo.Dummies;
            Data(:,:,:,1) = Data0(Start+(1:AcqInfo.NumTraj),:,:,:); 
            Start = AcqInfo.Dummies*2 + AcqInfo.NumTraj;
            Data(:,:,:,2) = Data0(Start+(1:AcqInfo.NumTraj),:,:,:); 
        end 

%==================================================================
% ReturnDataSetWithExternalShift
%================================================================== 
        function Data = ReturnDataSetWithExternalShift(obj,AcqInfo,ReconNumber,ExtFovShift) 
            Data = obj.ReturnDataSet(AcqInfo,ReconNumber); 
            ReconInfoMat = AcqInfo.ReconInfoMat(1:3,:,:);
            ScaledFovShift(1) = -ExtFovShift(2)/1000;
            ScaledFovShift(2) = ExtFovShift(1)/1000;
            ScaledFovShift(3) = -ExtFovShift(3)/1000;
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat = repmat(PhaseShift,1,1,obj.RxChannels);
            Data = Data.*PhaseShiftMat;
        end        

%==================================================================
% ReturnAllData
%================================================================== 
        function Data = ReturnAllData(obj,AcqInfo,ReconNumber)
            QDataMemPosArr = uint64(obj.DataMem.Pos(:) + obj.DataScanHeaderBytes);                                  
            QDataReadSize = obj.DataChannelHeaderBytes/8 + obj.DataDims.NCol;
            QDataStart = obj.DataChannelHeaderBytes/8 + AcqInfo.SampStart;
            QDataCol = AcqInfo.NumCol;
            QDataCha = obj.DataDims.NCha;
            QDataBlockLength = length(obj.DataMem.Pos);
            QDataInfo = uint64([QDataReadSize QDataStart QDataCol QDataCha QDataBlockLength]);
            Data = 1000 * BuildComplexDataArray([obj.DataPath,obj.DataFile],QDataMemPosArr,QDataInfo);
            Data = permute(Data,[2 1 3]);       % for now
        end            
        
%==================================================================
% ReturnDataSet
%================================================================== 
        function Data = ReturnDataSet(obj,AcqInfo,ReconNumber)       
            QDataMemPosArr = uint64(obj.DataMem.Pos(AcqInfo.TrajsInSet) + obj.DataScanHeaderBytes);                                  
            QDataReadSize = obj.DataChannelHeaderBytes/8 + obj.DataDims.NCol;
            QDataStart = obj.DataChannelHeaderBytes/8 + AcqInfo.SampStart;
            QDataCol = AcqInfo.NumCol;
            QDataCha = obj.DataDims.NCha;
            QDataBlockLength = length(QDataMemPosArr);
            QDataInfo = uint64([QDataReadSize QDataStart QDataCol QDataCha QDataBlockLength]);
            Data = 1000 * BuildComplexDataArray([obj.DataPath,obj.DataFile],QDataMemPosArr,QDataInfo);
            Data = permute(Data,[2 1 3]);       % for now
            obj.FirstSampDelay = obj.DataInfo.ExpPars.FirstSampDelay;
        end
        
%==================================================================
% ScaleData
%==================================================================   
        function Data = ScaleData(obj,KernHolder,Data)
            Scale = 1;
            Data = Data*Scale;
        end             
        
%==================================================================
% SetDataDims (For Hacking)
%==================================================================         
        function SetDataDims(obj,NCol,NCha,Lin)
            obj.DataDims.NCol = NCol;
            obj.DataDims.NCha = NCha;
            obj.DataDims.Lin = Lin;
        end      

%==================================================================
% AddShiftDim3
%==================================================================         
        function AddShiftDim3(obj,Add)
            obj.FovShift(3) = obj.FovShift(3) + Add;
        end         

    end
end