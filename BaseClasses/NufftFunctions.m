%================================================================
%  
%================================================================

classdef NufftFunctions < NufftGpu

    properties (SetAccess = private)
    end
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftFunctions()
            obj@NufftGpu;
        end     

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Nufft,KernHolder,AcqInfo)

            %--------------------------------------
            % Gpu
            %--------------------------------------            
            obj.FreeGpuMem;
            obj.GpuInit(Nufft.NumGpuUsed);
            obj.SetChanPerGpu(Nufft.ChanPerGpu);
            
            %--------------------------------------
            % Gridding Initialize
            %-------------------------------------- 
            iKern = round(1e9*(1/(KernHolder.Kernel.res*KernHolder.Kernel.DesforSS)))/1e9;
            Kern = KernHolder.Kernel.Kern;
            KernHalfWid = ceil(((KernHolder.Kernel.W*KernHolder.Kernel.DesforSS)-2)/2);
            SubSamp = KernHolder.Kernel.DesforSS;
            if (KernHalfWid+1)*iKern > length(Kern)
                error('Gridding Kernel Issue');
            end
            kStep = AcqInfo.kStep;
            kMatCentre = ceil(SubSamp*AcqInfo.kMaxRad/AcqInfo.kStep) + (KernHalfWid + 2); 
            kSz = kMatCentre*2 - 1;
            if kSz > Nufft.GridMatrix
                error(['Zero-Fill is to small. kSz = ',num2str(kSz)]);
            end 
            kShift = (Nufft.GridMatrix/2+1)-((kSz+1)/2);
            ConvScaleVal = KernHolder.Kernel.convscaleval;
            ReconInfoMat(:,:,1:3) = SubSamp*(AcqInfo.ReconInfoMat(:,:,1:3)/kStep) + kMatCentre + kShift;     
            ReconInfoMat(:,:,4) = AcqInfo.ReconInfoMat(:,:,4);
            
            %--------------------------------------
            % Allocate GPU Memory
            %--------------------------------------
            obj.AllocateKspaceGridImageMatricesGpuMem([Nufft.GridMatrix Nufft.GridMatrix Nufft.GridMatrix]); 
            obj.AllocateBaseImageMatricesGpuMem([Nufft.BaseMatrix Nufft.BaseMatrix Nufft.BaseMatrix]); 
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
            obj.LoadInvFiltGpuMem(KernHolder.InvFilt.V); 

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