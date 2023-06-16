%================================================================
%  
%================================================================

classdef StitchItFunctions < StitchItGpu

    properties (SetAccess = private)
    end
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItFunctions()
            obj@StitchItGpu;
        end     

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Options,AcqInfo,ChanPerGpu,log)

            %--------------------------------------
            % Gpu
            %--------------------------------------            
            obj.FreeGpuMem;
            obj.GpuInit(Options.Gpus2Use);
            obj.SetChanPerGpu(ChanPerGpu);
            
            %--------------------------------------
            % Gridding Initialize
            %-------------------------------------- 
            log.trace('Gridding Initialize');
            iKern = round(1e9*(1/(Options.Kernel.res*Options.Kernel.DesforSS)))/1e9;
            Kern = Options.Kernel.Kern;
            KernHalfWid = ceil(((Options.Kernel.W*Options.Kernel.DesforSS)-2)/2);
            SubSamp = Options.Kernel.DesforSS;
            if (KernHalfWid+1)*iKern > length(Kern)
                error('Gridding Kernel Issue');
            end
            kStep = AcqInfo.kStep;
            kMatCentre = ceil(SubSamp*AcqInfo.kMaxRad/AcqInfo.kStep) + (KernHalfWid + 2); 
            kSz = kMatCentre*2 - 1;
            if kSz > Options.ZeroFill
                error(['Zero-Fill is to small. kSz = ',num2str(kSz)]);
            end 
            kShift = (Options.ZeroFill/2+1)-((kSz+1)/2);
            ConvScaleVal = Options.Kernel.convscaleval;
            ReconInfoMat(:,:,1:3) = SubSamp*(AcqInfo.ReconInfoMat(:,:,1:3)/kStep) + kMatCentre + kShift;     
            ReconInfoMat(:,:,4) = AcqInfo.ReconInfoMat(:,:,4);
            
            %--------------------------------------
            % Allocate GPU Memory
            %--------------------------------------
            log.trace('Allocate GPU Memory');
            obj.AllocateKspaceGridImageMatricesGpuMem([Options.ZeroFill Options.ZeroFill Options.ZeroFill]); 
            obj.AllocateBaseImageMatricesGpuMem([Options.BaseMatrix Options.BaseMatrix Options.BaseMatrix]); 
            obj.AllocateRcvrProfMatricesGpuMem;        
            ReconInfoSize = [AcqInfo.NumCol AcqInfo.NumTraj 4];                 % Includes SDC
            obj.AllocateReconInfoGpuMem(ReconInfoSize);                       
            SampDatSize = [AcqInfo.NumCol AcqInfo.NumTraj];
            obj.AllocateSampDatGpuMem(SampDatSize);
            
            %--------------------------------------
            % Load
            %-------------------------------------- 
            obj.LoadKernelGpuMem(Kern,iKern,KernHalfWid,ConvScaleVal,SubSamp);  
            obj.LoadReconInfoGpuMemAsync(ReconInfoMat);
            obj.LoadInvFiltGpuMem(Options.InvFilt.V); 

            %--------------------------------------
            % FftInitialize
            %--------------------------------------             
            obj.SetupFourierTransform;       
        end
        
%==================================================================
% FreeGpuMem
%==================================================================           
        function FreeGpuMem(obj) 
            if not(isempty(obj.HKspaceMatrix))
                obj.FreeKspaceMatricesGpuMem;
            end
            if not(isempty(obj.HGridImageMatrix))
                obj.FreeGridImageMatricesGpuMem;
            end
            if not(isempty(obj.HTempMatrix))
                obj.FreeTempMatricesGpuMem;
            end
            if not(isempty(obj.HBaseImageMatrix))
                obj.FreeBaseImageMatricesGpuMem;
            end   
            if not(isempty(obj.HRcvrProfMatrix))
                obj.FreeRcvrProfMatricesGpuMem;
            end              
            if not(isempty(obj.HReconInfo))
                obj.FreeReconInfoGpuMem;
            end
            if not(isempty(obj.HSampDat))
                obj.FreeSampDatGpuMem;
            end
            if not(isempty(obj.HKernel))
                obj.FreeKernelGpuMem;
            end
            if not(isempty(obj.HInvFilt))
                obj.FreeInvFiltGpuMem;
            end
            if not(isempty(obj.HFourierTransformPlan))
                obj.ReleaseFourierTransform;
            end
        end   

%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            obj.FreeGpuMem;
        end 

    end
end