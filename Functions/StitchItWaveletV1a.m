%================================================================
% StitchIt
%   
%================================================================

classdef StitchItWaveletV1a < handle

    properties (SetAccess = private)                                     
        LevelsPerDim = [1 1 1]
        NumIterations = 50
        MaxEig
        Lambda
        Nufft
        DispStatObj
        UnallocateRamOnFinish = 0
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItWaveletV1a()
            obj.Nufft = NufftIterate(); 
        end       

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,KernHolder,AcqInfo,DispStatObj) 
            obj.DispStatObj = DispStatObj;
            obj.Nufft.SetDoMemRegister(~obj.UnallocateRamOnFinish);
            obj.Nufft.SetUseSdc(0);
            obj.Nufft.Initialize(KernHolder,AcqInfo);             
        end

%==================================================================
% CreateImage
%==================================================================         
        function Image = CreateImage(obj,Data,Image0)                  
            isDec = 0;                                          % Non-decimated to avoid blocky edges
            family = 'db1';           
            useGPUFlag = 0;
            Wave = dwt(obj.LevelsPerDim,size(Image0),isDec,family,useGPUFlag);  
            Func = @(x,transp) obj.IterateFunc(x,transp);
            Opt = [];
            Opt.maxEig = obj.MaxEig;
            Opt.resThresh = 1e-9;                           % go by iterations
            obj.DispStatObj.ResetIterationCount;
            Image = BfistaRwsV1a(Func,Data,Wave,obj.Lambda,Image0,obj.NumIterations,Opt,obj);
            if obj.UnallocateRamOnFinish
                obj.Nufft.UnallocateRamRxProfs;
            end
        end

%==================================================================
% IterateFunc
%==================================================================           
        function Out = IterateFunc(obj,In,Transp)
            switch Transp
                case 'notransp'
                    Out = obj.Nufft.Forward(In);
                case 'transp'
                    Out = obj.Nufft.Inverse(In); 
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
        
%==================================================================
% SetLevelsPerDim
%==================================================================   
        function SetLevelsPerDim(obj,val)
            obj.LevelsPerDim = val;
        end         

%==================================================================
% SetMaxEig
%==================================================================   
        function SetMaxEig(obj,val)
            obj.MaxEig = val;
        end          
        
%==================================================================
% SetNumIterations
%==================================================================         
        function SetNumIterations(obj,val)
            obj.NumIterations = val;
        end        

%==================================================================
% SetLambda
%==================================================================         
        function SetLambda(obj,val)
            obj.Lambda = val;
        end                                     

end
end

