%================================================================
%  
%================================================================

classdef SimulationStitchItDataConvert < handle

    properties (SetAccess = private)                    
        DataFile 
        DataPath 
        DataName
        DataInfo
        NumTrajs
        RxChannels
        NumAverages
        TotalAcqs
        DataFull
        FovShift = [0 0 0]
        FirstSampDelay
    end
    methods 

%==================================================================
% Constructor
%==================================================================   
        function obj = SimulationStitchItDataConvert()
        end

%==================================================================
% ConvertSimulationData
%==================================================================   
        function ConvertSimulationData(obj,SAMP,STCH,SampDat)
            obj.FirstSampDelay = 0;
            obj.DataFull{1} = SampDat;

            sz = size(obj.DataFull{1});
            obj.NumTrajs = sz(1);
            if length(sz) == 2
                obj.RxChannels = 1;
                obj.NumAverages = 1;
            elseif length(sz) == 3
                obj.RxChannels = sz(3);
                obj.NumAverages = 1;
            elseif length(sz) == 4
                obj.RxChannels = sz(3);
                obj.NumAverages = sz(4);
            end
            obj.TotalAcqs = obj.NumTrajs * obj.NumAverages;
            
            obj.DataFile = [];
            obj.DataPath = [];
            obj.DataName = [];
            
            obj.DataInfo.ExpPars = '';
            obj.DataInfo.ExpDisp = '';
            obj.DataInfo.PanelOutput = [];
            obj.DataInfo.Seq = 'Simulation';
            obj.DataInfo.Protocol = '';
            obj.DataInfo.VolunteerID = '';
            obj.DataInfo.TrajName = STCH.name;
            obj.DataInfo.TrajImpName = '';
            obj.DataInfo.RxChannels = 1;
            obj.DataInfo.SimSampGridMatrix = SAMP.GridMatrix;                
        end

%==================================================================
% ScaleData
%==================================================================   
        function Data = ScaleData(obj,KernHolder,Data)
            %Scale = ((KernHolder.GridMatrix/obj.DataInfo.SimSampGridMatrix)^3)/KernHolder.BaseMatrix^1.5;              This might depend on the recon...
            Scale = (KernHolder.GridMatrix/obj.DataInfo.SimSampGridMatrix)^1.5;
            Data = Data*Scale;
        end        

%==================================================================
% ReturnDataSetWithShift
%================================================================== 
        function Data = ReturnDataSetWithShift(obj,AcqInfo,ReconNumber)
            Data = obj.DataFull{ReconNumber};
        end
        
%==================================================================
% ReturnDataSet
%================================================================== 
        function Data = ReturnDataSet(obj,AcqInfo,ReconNumber)  
            Data = obj.DataFull{ReconNumber};
        end        
        
            
    end
end