%================================================================
% Simulation
%   
%================================================================

classdef SampleOffResImage < handle

    properties (SetAccess = private)                                     
        StitchSupportingPath
        AcqInfo
        KernHolder
        GridMatrix
        BaseMatrix
        Gpus2Use
        RxChannels
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = SampleOffResImage()
            obj.KernHolder = NufftKernelHolder();
        end       

%==================================================================
% Setup
%==================================================================   
        function Initialize(obj,AcqInfo,RxChannels) 
            DisplayStatusCompass('Initialize',3);
            obj.AcqInfo = AcqInfo;
            obj.KernHolder.Initialize(obj.AcqInfo,obj);
            obj.RxChannels = RxChannels;
            GpuTot = gpuDeviceCount;
            if obj.RxChannels == 1
                obj.Gpus2Use = 1;
            else
                if isempty(obj.Gpus2Use)
                obj.Gpus2Use = GpuTot;
                end
                if obj.Gpus2Use > GpuTot
                    error('More Gpus than available have been specified');
                end
            end
        end    
        
%==================================================================
% Sample
%==================================================================         
        function Data = Sample(obj,Image,RxProfs,OffResMap,OffResTimeArr)
            DisplayStatusCompass('Sample k-Space',3);
            Nufft = NufftOffResIterate();
            Nufft.Initialize(obj,obj.KernHolder,obj.AcqInfo,obj.RxChannels,RxProfs,OffResMap,OffResTimeArr);
            Nufft.SetSimulationScale;
            Data = Nufft.Forward(Image);
            clear Nufft;
            DisplayClearStatusCompass();
        end

%==================================================================
% SetStitchSupportingPath
%==================================================================         
        function SetStitchSupportingPath(obj,val)
            obj.StitchSupportingPath = val;
        end             

%==================================================================
% SetAcqInfo
%==================================================================         
        function SetAcqInfo(obj,val)
            obj.AcqInfo = val;
        end               
        
%==================================================================
% SetGpus2Use
%==================================================================         
        function SetGpus2Use(obj,val)
            obj.Gpus2Use = val;
        end
        
%==================================================================
% SetGridMatrix
%==================================================================   
        function SetGridMatrix(obj,val)
            obj.GridMatrix = val;
        end              

%==================================================================
% SetBaseMatrix
%==================================================================   
        function SetBaseMatrix(obj,val)
            obj.BaseMatrix = val;
        end   
        
%==================================================================
% TestFov2ReturnGridMatrix
%==================================================================         
        function bool = TestFov2ReturnGridMatrix(obj)
            bool = 0;
        end   
        
    end
end


