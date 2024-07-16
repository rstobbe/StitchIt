%================================================================
% Simulation
%   
%================================================================

classdef SampleOffResImage < handle

    properties (SetAccess = private)                                     
        Nufft
        UnallocateRamOnFinish = 0
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = SampleOffResImage()
            obj.Nufft = NufftOffResIterate(); 
        end       

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,KernHolder,AcqInfo) 
            obj.Nufft.SetDoMemRegister(~obj.UnallocateRamOnFinish);
            obj.Nufft.Initialize(KernHolder,AcqInfo);
        end  
 
%==================================================================
% Sample
%==================================================================         
        function Data = Sample(obj,Image)
            obj.Nufft.ReStartForward;
            Data = obj.Nufft.Forward(Image);
            if obj.UnallocateRamOnFinish
                obj.Nufft.UnallocateRamRxProfs;
            end       
        end

%==================================================================
% LoadRxProfs
%==================================================================         
        function LoadRxProfs(obj,RxProfs)                  
            obj.Nufft.LoadRxProfs(RxProfs);
        end          

%==================================================================
% LoadOffResonance
%==================================================================         
        function LoadOffResonance(obj,OffResMap,OffResTimeArr)                  
            obj.Nufft.LoadOffResonance(OffResMap,OffResTimeArr);
        end 

%==================================================================
% SetUnallocateRamOnFinish
%==================================================================         
        function SetUnallocateRamOnFinish(obj,val)                  
            obj.UnallocateRamOnFinish = val;
        end   
        
    end
end


