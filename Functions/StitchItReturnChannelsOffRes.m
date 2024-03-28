%================================================================
% StitchIt
%   
%================================================================

classdef StitchItReturnChannelsOffRes < handle

    properties (SetAccess = private)                                     
        Nufft
        UnallocateRamOnFinish = 0
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItReturnChannelsOffRes()
            obj.Nufft = NufftReturnChannelsOffRes(); 
            error('finish');
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
% SetUnallocateRamOnFinish
%==================================================================         
        function SetUnallocateRamOnFinish(obj,val)                  
            obj.UnallocateRamOnFinish = val;
        end  
        
    end
end

