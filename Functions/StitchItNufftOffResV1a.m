%================================================================
% StitchIt
%   
%================================================================

classdef StitchItNufftOffResV1a < handle

    properties (SetAccess = private)                                     
        Nufft
        UnallocateRamOnFinish = 0
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItNufftOffResV1a()
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


