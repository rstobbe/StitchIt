%================================================================
% StitchItNufftV1a
%   
%================================================================

classdef StitchItNufftV1a < handle

    properties (SetAccess = private)                                     
        Nufft
        UnallocateRamOnFinish = 0
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItNufftV1a()
            obj.Nufft = NufftIterate(); 
        end       

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,KernHolder,AcqInfo) 
            obj.Nufft.SetDoMemRegister(~obj.UnallocateRamOnFinish);
            obj.Nufft.Initialize(KernHolder,AcqInfo);
        end           
        
%==================================================================
% CreateImage
%==================================================================         
        function Image = CreateImage(obj,Data)
            Image = obj.Nufft.Inverse(Data);
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
% SetUnallocateRamOnFinish
%==================================================================         
        function SetUnallocateRamOnFinish(obj,val)                  
            obj.UnallocateRamOnFinish = val;
        end  
        
    end
end


