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
% ReturnAllData
%================================================================== 
        function Data = ReturnAllData(obj,AcqInfo)
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
% ReturnDataSetWithShift
%================================================================== 
        function Data = ReturnDataSetWithShift(obj,AcqInfo,ReconNumber) 
            Data = obj.ReturnDataSet(AcqInfo,ReconNumber); 
            ReconInfoMat = AcqInfo.ReconInfoMat(1:3,:,:);
            ScaledFovShift(1) = -obj.FovShift(2)/1000;
            ScaledFovShift(2) = -obj.FovShift(1)/1000;
            ScaledFovShift(3) = obj.FovShift(3)/1000;
            PhaseShift = exp(-1i*2*pi*squeeze(pagemtimes(ScaledFovShift,ReconInfoMat)));
            PhaseShiftMat = repmat(PhaseShift,1,1,obj.RxChannels);
            Data = Data.*PhaseShiftMat;
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
        function Data = ScaleData(obj,StitchIt,Data)
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
        
    end
end