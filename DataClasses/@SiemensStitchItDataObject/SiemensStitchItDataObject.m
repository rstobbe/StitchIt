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
        function AllData = ReturnAllData(obj,AcqInfo)
            QDataMemPosArr = uint64(obj.DataMem.Pos(:) + obj.DataScanHeaderBytes);                                  
            QDataReadSize = obj.DataChannelHeaderBytes/8 + obj.DataDims.NCol;
            QDataStart = obj.DataChannelHeaderBytes/8 + AcqInfo.SampStart;
            QDataCol = AcqInfo.NumCol;
            QDataCha = obj.DataDims.NCha;
            QDataBlockLength = length(obj.DataMem.Pos);
            QDataInfo = uint64([QDataReadSize QDataStart QDataCol QDataCha QDataBlockLength]);
            AllData = BuildComplexDataArray([obj.DataPath,obj.DataFile],QDataMemPosArr,QDataInfo);
            AllData = AllData * 1000;
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