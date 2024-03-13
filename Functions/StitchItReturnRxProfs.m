%================================================================
% StitchIt
%   
%================================================================

classdef StitchItReturnRxProfs < handle

    properties (SetAccess = private)                                     
        Nufft
        UnallocateRamOnFinish = 0
    end
    
    methods 
        
%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItReturnRxProfs()
        end       

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,KernHolder,AcqInfo) 
            obj.Nufft = NufftReturnChannels();
            obj.Nufft.SetDoMemRegister(~obj.UnallocateRamOnFinish);
            obj.Nufft.Initialize(KernHolder,AcqInfo);
        end                       
        
%==================================================================
% CreateImage
%==================================================================         
        function [RxProfs] = CreateImage(obj,Data) 
            LowResImages = obj.Nufft.Inverse(Data);
            LowResSos = sum(abs(LowResImages).^2,4);
            RxProfs = LowResImages./sqrt(LowResSos);
        end
    
%==================================================================
% SetUnallocateRamOnFinish
%==================================================================         
        function SetUnallocateRamOnFinish(obj,val)                  
            obj.UnallocateRamOnFinish = val;
        end           
        
    end
end


