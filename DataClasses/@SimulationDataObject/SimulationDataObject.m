%================================================================
%  
%================================================================

classdef SimulationDataObject < handle

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
        function obj = SimulationDataObject(file)
            load(file);
            SAMP = saveData.SAMP;
            if isprop(SAMP.KSMP,'Delay')
                obj.FirstSampDelay = SAMP.KSMP.Delay;
            else
                obj.FirstSampDelay = 0;
            end
            if ~iscell(SAMP.SampDat)
                if ~isreal(SAMP.SampDat)
                    % 'old' simulation data...
                    SampDat = single(permute(SAMP.SampDat,[2 1 3]));
                    sz = size(SampDat);
                    obj.DataFull{1} = zeros(sz(1)*2,sz(2),'single');
                    obj.DataFull{1}(1:2:end-1,:) = single(real(SampDat));
                    obj.DataFull{1}(2:2:end,:) = single(imag(SampDat));
                else
                    % still 'old' - simulation should be in cell array...
                    obj.DataFull{1} = SAMP.SampDat;
                end
            else
                obj.DataFull = SAMP.SampDat;
            end
            % NumTrajs / RxChannels / NumAverages should be the same for all
            sz = size(obj.DataFull{1});
            TrajDim = 2;
            if isfield(SAMP,'DataDims')
                if strcmp(SAMP.DataDims,'Pt2Pt')
                    TrajDim = 1;
                end
            end
            obj.NumTrajs = sz(TrajDim);
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
            
            obj.DataFile = SAMP.name;
            obj.DataPath = SAMP.path;
            obj.DataName = SAMP.name;
            
            obj.DataInfo.ExpPars = '';
            obj.DataInfo.ExpDisp = '';
            obj.DataInfo.PanelOutput = SAMP.PanelOutput;
            obj.DataInfo.Seq = 'Simulation';
            obj.DataInfo.Protocol = SAMP.name;
            obj.DataInfo.VolunteerID = SAMP.name;
            obj.DataInfo.TrajName = '';
            obj.DataInfo.TrajImpName = '';
            obj.DataInfo.RxChannels = 1;
            if isfield(SAMP,'ZF')
                obj.DataInfo.SimSampGridMatrix = SAMP.ZF;
            elseif isfield(SAMP,'GridMatrix')
                obj.DataInfo.SimSampGridMatrix = SAMP.GridMatrix;
            end
        end
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Options)
            Scale = (Options.GridMatrix/obj.DataInfo.SimSampGridMatrix)^3;
            for n = 1:length(obj.DataFull)
                obj.DataFull{n} = obj.DataFull{n}*Scale;
            end
            if isprop(Options,'IntensityScale')
                Options.SetIntensityScale(1);
            end
        end

%==================================================================
% ScaleData
%==================================================================   
        function Data = ScaleData(obj,StitchIt,Data)
            Scale = ((StitchIt.GridMatrix/obj.DataInfo.SimSampGridMatrix)^3)/StitchIt.BaseMatrix^1.5;
            Data = Data*Scale;
        end        
        
%==================================================================
% ReturnDataSet
%================================================================== 
        function Data = ReturnDataSet(obj,AcqInfo,SetNum)  
            Data = obj.DataFull{SetNum};
        end        
        
            
    end
end