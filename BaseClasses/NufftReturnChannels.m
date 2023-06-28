%================================================================
% NufftReturnChannels
%   
%================================================================

classdef NufftReturnChannels < handle

    properties (SetAccess = private)                                     
        NufftFuncs
        RxChannels
        BaseMatrix
        GridMatrix
        ChanPerGpu
        NumGpuUsed
        ReconRxBatches
        ReconRxBatchLen
        TestTime
        ImageMemPin
        DataMemPin
        NumRunsInverse
        NumRunsForward
        RegisterDataMemory = 1
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftReturnChannels()
            obj.NufftFuncs = NufftFunctions();
        end                        
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Stitch,KernHolder,AcqInfo,RxChannels)
            obj.NumGpuUsed = Stitch.Gpus2Use;
            obj.BaseMatrix = Stitch.BaseMatrix;
            obj.GridMatrix = Stitch.GridMatrix;
            obj.RxChannels = RxChannels;
            
            %--------------------------------------
            % Receive Batching
            %   - for limited memory GPUs (and/or many RxChannels)
            %--------------------------------------             
            GridMemory = (obj.GridMatrix^3)*20;          % k-space + image + invfilt (complex & single)
            BaseImageMemory = (obj.BaseMatrix^3)*8;
            DataKspaceMemory = AcqInfo.NumTraj*AcqInfo.NumCol*16;
            TotalMemory = GridMemory + BaseImageMemory + DataKspaceMemory;
            AvailableMemory = obj.NufftFuncs.GpuParams.AvailableMemory;
            for n = 1:20
                obj.ReconRxBatches = n;
                obj.ChanPerGpu = ceil(obj.RxChannels/(obj.NumGpuUsed*obj.ReconRxBatches));
                MemoryNeededTotal = TotalMemory + BaseImageMemory * obj.ChanPerGpu;
                if MemoryNeededTotal*1.2 < AvailableMemory
                    break
                end
            end
            obj.ReconRxBatchLen = obj.ChanPerGpu * obj.NumGpuUsed;              
            
            %--------------------------------------
            % Nufft Initialize
            %--------------------------------------
            obj.NufftFuncs.Initialize(obj,KernHolder,AcqInfo);
            obj.NumRunsInverse = 0;
        end      

%==================================================================
% Inverse
%================================================================== 
        function Image = Inverse(obj,Stitch,Data)
%             tic
            if ndims(Data) == 2
                obj.RegisterDataMemory = 0;
            end
            if obj.RegisterDataMemory
                Error = RegisterHostComplexMemCuda61(Data);
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
            if obj.NumRunsInverse == 0 
                if Stitch.TestFov2ReturnGridMatrix
                    obj.ImageMemPin = complex(zeros([Stitch.GridMatrix Stitch.GridMatrix Stitch.GridMatrix,obj.RxChannels],'single'),0);
                else
                    obj.ImageMemPin = complex(zeros([Stitch.BaseMatrix Stitch.BaseMatrix Stitch.BaseMatrix,obj.RxChannels],'single'),0);
                end
                Error = RegisterHostComplexMemCuda61(obj.ImageMemPin);
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
            obj.NumRunsInverse = obj.NumRunsInverse+1;
            for q = 1:obj.ReconRxBatches 
                obj.NufftFuncs.InitializeBaseMatricesGpuMem;
                for p = 1:obj.ChanPerGpu
%---
%                     obj.NufftFuncs.CudaDeviceWait(1);
%                     tic
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end
                        obj.NufftFuncs.LoadSampDatGpuMemAsyncCidx(GpuNum,Data,ChanNum);
                    end 
%                     obj.NufftFuncs.CudaDeviceWait(1);
%                     toc
%---
                    obj.NufftFuncs.InitializeGridMatricesGpuMem;
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end    
                        obj.NufftFuncs.GridSampDat(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end  
                        obj.NufftFuncs.KspaceFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.InverseFourierTransform(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.ImageFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.MultInvFilt(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        obj.NufftFuncs.CudaDeviceWait(GpuNum);
                    end
                    if Stitch.TestFov2ReturnGridMatrix
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end 
                            obj.NufftFuncs.ReturnGridImageCidx(GpuNum,obj.ImageMemPin,ChanNum);
                        end
                    else
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end 
                            obj.NufftFuncs.Grid2BaseImage(GpuNum);
                        end
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end 
                            obj.NufftFuncs.ReturnBaseImageCidx(GpuNum,obj.ImageMemPin,ChanNum);
                        end
                    end
                end
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            Scale = 1/obj.NufftFuncs.ConvScaleVal * single(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5 / single(obj.NufftFuncs.GridImageMatrixMemDims(1))^3;
            Image = obj.ImageMemPin*Scale;
            if obj.RegisterDataMemory
                Error = UnRegisterHostMemCuda61(Data);
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
        end           
        
%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            if obj.RegisterDataMemory
                if not(isempty(obj.DataMemPin))
                    Error = UnRegisterHostMemCuda61(obj.DataMemPin);
                    if not(strcmp(Error,'no error'))
                        error(Error);
                    end
                end
            end
            if not(isempty(obj.ImageMemPin))
                Error = UnRegisterHostMemCuda61(obj.ImageMemPin);
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
            obj.NufftFuncs.FreeGpuMem;
        end        
        
    end
end
