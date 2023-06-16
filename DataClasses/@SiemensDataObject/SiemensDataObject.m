%================================================================
%  
%================================================================

classdef SiemensDataObject < handle

    properties (SetAccess = private)                    
        DataFile; DataPath; DataName;
        DataScanHeaderBytes = 192;
        DataChannelHeaderBytes = 32; 
        DataHdr;
        DataDims;
        DataMem;
        DataInfo;
        DataBlockLength
        AcqsPerImage;
        TotalAcqs;
        RxChannels;
        NumAverages;
        DataBlock;
        FovShift = [0 0 0]
    end
    methods 

%==================================================================
% Constructor
%==================================================================   
        function obj = SiemensDataObject(DataFile)
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
        function Initialize(obj,Options)
            ReadSiemensDataInfo(obj,[obj.DataPath,obj.DataFile]);
            obj.NumAverages = obj.DataHdr.lAverages; 
            if obj.DataDims.NAve < obj.DataHdr.lAverages
                obj.AcqsPerImage = obj.DataDims.Lin/obj.DataHdr.lAverages;                                    % includes dummies
            else
                obj.AcqsPerImage = obj.DataDims.Lin; 
            end
            obj.TotalAcqs = obj.AcqsPerImage * obj.NumAverages;   
            obj.RxChannels = obj.DataDims.NCha;  
            obj.DataBlockLength = Options.ReconTrajBlockLength;
            if strcmp(Options.IntensityScale,'Default')
                Options.SetIntensityScale(1e12);
            end
        end  

%==================================================================
% SetAcqsPerImage
%==================================================================          
        function SetAcqsPerImage(obj,Val)
            obj.AcqsPerImage = Val;
        end

%==================================================================
% ReadSiemensHeader
%==================================================================   
        function ReadSiemensHeader(obj)
            ReadSiemensDataInfo(obj,[obj.DataPath,obj.DataFile]);
        end            
        
%==================================================================
% ReadDataBlock
%================================================================== 
        function ReadDataBlock(obj,Trajs,Rcvrs,AveNum,AcqNum,AcqInfo,Log)
            Acqs = obj.AcqsPerImage*(AveNum-1) + Trajs + AcqInfo.Dummies;
            if Acqs(end) > obj.TotalAcqs
                error('Check Recon');
            end
            QDataMemPosArr = uint64(obj.DataMem.Pos(Acqs) + obj.DataScanHeaderBytes);                                  
            QDataReadSize = obj.DataChannelHeaderBytes/8 + obj.DataDims.NCol;
            QDataStart = obj.DataChannelHeaderBytes/8 + AcqInfo.SampStart;
            QDataCol = AcqInfo.NumCol;
            QDataCha = obj.DataDims.NCha;
            QDataBlockLength = obj.DataBlockLength;
            QDataInfo = uint64([QDataReadSize QDataStart QDataCol QDataCha QDataBlockLength]);
            tDataBlock = BuildDataArray([obj.DataPath,obj.DataFile],QDataMemPosArr,QDataInfo);
            obj.DataBlock = tDataBlock(:,:,Rcvrs);
        end

%==================================================================
% ReturnAllData
%================================================================== 
        function AllData = ReturnAllData(obj,AcqNum,AcqInfo,Log)
            QDataMemPosArr = uint64(obj.DataMem.Pos(:) + obj.DataScanHeaderBytes);                                  
            QDataReadSize = obj.DataChannelHeaderBytes/8 + obj.DataDims.NCol;
            QDataStart = obj.DataChannelHeaderBytes/8 + AcqInfo.SampStart;
            QDataCol = AcqInfo.NumCol;
            QDataCha = obj.DataDims.NCha;
            QDataBlockLength = length(obj.DataMem.Pos);
            QDataInfo = uint64([QDataReadSize QDataStart QDataCol QDataCha QDataBlockLength]);
            AllData = BuildDataArray([obj.DataPath,obj.DataFile],QDataMemPosArr,QDataInfo);
        end        
        
%==================================================================
% ExtractSequenceParams
%==================================================================         
        function Params = ExtractSequenceParams(obj,SeqParams)
            for n = 1:length(SeqParams)
                switch SeqParams{n}
                    case 'TR'
                        Params{n} = obj.DataHdr.alTR{1}/1000;
                    case 'NumAverages'
                        obj.NumAverages = obj.DataHdr.lAverages;                
                        Params{n} = obj.DataHdr.lAverages;
                end
            end
        end

%==================================================================
% SetDataBlock
%==================================================================             
        function SetDataBlock(obj,DataBlock0)
            obj.DataBlock = DataBlock0;
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
% ZeroData
%==================================================================         
%         function ZeroData(obj,ZeroDataInds)
%             obj.DataBlock(:,ZeroDataInds,:) = 0;
%         end        
        
    end
end