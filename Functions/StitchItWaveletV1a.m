%================================================================
% StitchIt
%   
%================================================================

classdef StitchItWaveletV1a < handle

    properties (SetAccess = private)                                     
        StitchSupportingPath
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
        ReconInfoMatHold
        AcqInfo
        Wave
        Opt
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItWaveletV1a()
            obj.KernHolder = NufftKernelHolder();
        end       

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,AcqInfo,RxChannels,DispStatObj) 
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
            if obj.Gpus2Use > GpuTot
                error('More Gpus than available have been specified');
            end
            sz = size(AcqInfo.ReconInfoMat);
            if ~strcmp(AcqInfo.DataDims,'Pt2Pt') || sz(1)~=4
                error('YB_ file not specified properly - probably old version');
            end

            %---------------------------------------------
            % Set sampling density compensation to '1'
            %---------------------------------------------
            obj.AcqInfo = AcqInfo;
            ReconInfoMat = AcqInfo.ReconInfoMat;
            obj.ReconInfoMatHold = ReconInfoMat;
            ReconInfoMat(4,:,:) = 1;                           
            AcqInfo.SetReconInfoMat(ReconInfoMat); 
            
            %---------------------------------------------
            % Initialize Nufft
            %---------------------------------------------
            obj.Nufft = NufftIterate();
            obj.Nufft.SetDoMemRegister(obj.DoMemRegister);
            OtherGpuMemNeeded = 0;                               % wavelet not in gpu
            obj.Nufft.Initialize(obj,obj.KernHolder,AcqInfo,obj.RxChannels,OtherGpuMemNeeded);

            %---------------------------------------------
            % Initialize Wavelet
            %---------------------------------------------
            isDec = 0;                                          % Non-decimated to avoid blocky edges
            family = 'db1';         
            useGPUFlag = 0;
            obj.Wave = dwt(obj.LevelsPerDim,[obj.BaseMatrix obj.BaseMatrix obj.BaseMatrix],isDec,family,useGPUFlag);  
            
            %---------------------------------------------
            % Initialize Options
            %---------------------------------------------
            obj.Opt = [];
            obj.Opt.maxEig = obj.MaxEig;
            obj.Opt.resThresh = 1e-9;               % go by iterations
            obj.DispStatObj.ResetIterationCount;               
        end

%==================================================================
% LoadRxProfs
%==================================================================         
        function LoadRxProfs(obj,RxProfs)                  
            obj.Nufft.LoadRxProfs(RxProfs);
        end        
        
%==================================================================
% CreateImage
%==================================================================         
        function Image = CreateImage(obj,Data,Image0)                  
            Func = @(x,transp) obj.IterateFunc(x,transp);
            Image = BfistaRwsV1a(Func,Data,obj.Wave,obj.Lambda,Image0,obj.NumIterations,obj.Opt,obj);
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

%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            obj.AcqInfo.SetReconInfoMat(obj.ReconInfoMatHold); 
        end        
        
    end
end


