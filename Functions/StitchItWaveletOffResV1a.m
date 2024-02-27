%================================================================
% StitchIt
%   
%================================================================

classdef StitchItWaveletOffResV1a < handle

    properties (SetAccess = private)                                     
        StitchSupportingPath
        AcqInfo
        KernHolder
        GridMatrix
        BaseMatrix
        Gpus2Use
        RxChannels
        Fov2Return = 'BaseMatrix'
        LevelsPerDim = [1 1 1]
        NumIterations = 50
        MaxEig
        Lambda
        Nufft
        DispStatObj
        DoMemRegister = 1
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItWaveletOffResV1a()
            obj.KernHolder = NufftKernelHolder();
        end       

%==================================================================
% Setup
%==================================================================   
        function Initialize(obj,AcqInfo,RxChannels,DispStatObj) 
            obj.AcqInfo = AcqInfo;
            obj.KernHolder.Initialize(AcqInfo,obj);
            obj.RxChannels = RxChannels;
            obj.DispStatObj = DispStatObj;
            GpuTot = gpuDeviceCount;
            if isempty(obj.Gpus2Use)
                if obj.RxChannels == 1
                    obj.Gpus2Use = 1;
                else
                    obj.Gpus2Use = GpuTot;
                end
            end
%             %-----
%             obj.Gpus2Use = GpuTot - 1;            % wavelet stuff on own
%             %-----
            if obj.Gpus2Use > GpuTot
                error('More Gpus than available have been specified');
            end
            sz = size(AcqInfo.ReconInfoMat);
            if ~strcmp(AcqInfo.DataDims,'Pt2Pt') || sz(1)~=4
                error('YB_ file not specified properly - probably old version');
            end
        end    
        
%==================================================================
% CreateImage
%==================================================================         
        function Image = CreateImage(obj,Data,RxProfs,OffResMap,OffResTimeArr,Image0)                  
            ReconInfoMat = obj.AcqInfo.ReconInfoMat;
            ReconInfoMat(4,:,:) = 1;                            % set sampling density compensation to '1'. 
            obj.AcqInfo.SetReconInfoMat(ReconInfoMat); 
            obj.Nufft = NufftOffResIterate();
            obj.Nufft.SetDoMemRegister(obj.DoMemRegister);
            sz = size(OffResMap);
%---------------------
            %OtherGpuMemNeeded = sz(1)^3 * 8 * 16;               % wavelet holders + temp
            OtherGpuMemNeeded = 0;                               % wavelet not in gpu
            obj.Nufft.Initialize(obj,obj.KernHolder,obj.AcqInfo,obj.RxChannels,RxProfs,OffResMap,OffResTimeArr,OtherGpuMemNeeded);
%---------------------
            isDec = 0;                                          % Non-decimated to avoid blocky edges
            family = 'db1';
%---------------------            
            useGPUFlag = 0;
%---------------------
            Wave = dwt(obj.LevelsPerDim,size(Image0),isDec,family,useGPUFlag);  
            Func = @(x,transp) obj.IterateFunc(x,transp);
            Opt = [];
            Opt.maxEig = obj.MaxEig;
            Opt.resThresh = 1e-9;               % go by iterations
            obj.DispStatObj.ResetIterationCount;
            %--
            Image = BfistaRwsV1a(Func,Data,Wave,obj.Lambda,Image0,obj.NumIterations,Opt,obj);
            %--
            clear Nufft
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
% SetStitchSupportingPath
%==================================================================         
        function SetStitchSupportingPath(obj,val)
            obj.StitchSupportingPath = val;
        end  
        
%==================================================================
% SetDoMemRegister
%==================================================================           
        function SetDoMemRegister(obj,val)
            obj.DoMemRegister = val;
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

%==================================================================
% TestFov2ReturnGridMatrix
%==================================================================         
        function bool = TestFov2ReturnGridMatrix(obj)
            bool = 0;
            if strcmp(obj.Fov2Return,'GridMatrix')
                bool = 1;
            end
        end 

end
end

