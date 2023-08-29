%================================================================
% NufftIterateOffRes
%   
%================================================================

classdef NufftIterateOffRes < handle

    properties (SetAccess = private)                                     
        NufftFuncs
        RxChannels
        RxProfs
        BaseMatrix
        GridMatrix
        NumTraj
        NumCol
        ChanPerGpu
        NumGpuUsed
        ReconRxBatches
        ReconRxBatchLen
        TestTime
        ImageMemPin
        DataMemPin
        NumRunsInverse
        NumRunsForward
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftIterateOffRes()
            obj.NufftFuncs = NufftFunctions();
        end                        
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Stitch,KernHolder,AcqInfo,RxChannels,RxProfs,OffResMap)
            obj.NumGpuUsed = Stitch.Gpus2Use;
            obj.BaseMatrix = Stitch.BaseMatrix;
            obj.GridMatrix = Stitch.GridMatrix;
            obj.RxChannels = RxChannels;
            obj.NumTraj = AcqInfo.NumTraj;
            obj.NumCol = AcqInfo.NumCol;
            
            %--------------------------------------
            % Receive Batching
            %   - for limited memory GPUs (and/or many RxChannels)
            %--------------------------------------             
            GridMemory = (obj.GridMatrix^3)*20;          % k-space + image + invfilt (complex & single)
            BaseImageMemory = (obj.BaseMatrix^3)*8;
            DataKspaceMemory = obj.NumTraj*obj.NumCol*16;
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

            %--------------------------------------
            % Load RxProfs
            %--------------------------------------   
            if obj.ReconRxBatches == 1
                obj.NufftFuncs.LoadRcvrProfMatricesGpuMum(RxProfs);
            else
                obj.RxProfs = RxProfs;
            end 
            
            %--------------------------------------
            % Load OffResMap
            %--------------------------------------             
            
            obj.NumRunsInverse = 0;
            obj.NumRunsForward = 0;               
        end      

%==================================================================
% Inverse
%================================================================== 
        function Image = Inverse(obj,Data)
%             tic
            Error = RegisterHostComplexMemCuda61(Data);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            if obj.NumRunsInverse == 0 
                obj.ImageMemPin = complex(zeros([obj.BaseMatrix obj.BaseMatrix obj.BaseMatrix,obj.ReconRxBatches*obj.NumGpuUsed],'single'),0);
                Error = RegisterHostComplexMemCuda61(obj.ImageMemPin);
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
            obj.NumRunsInverse = obj.NumRunsInverse+1;
            for q = 1:obj.ReconRxBatches 
                RbStart = (q-1)*obj.ReconRxBatchLen + 1;
                RbStop = q*obj.ReconRxBatchLen;
                if RbStop > obj.RxChannels
                    RbStop = obj.RxChannels;
                end
                Rcvrs = RbStart:RbStop;
                if obj.ReconRxBatches ~= 1
                    obj.NufftFuncs.LoadRcvrProfMatricesGpuMum(obj.RxProfs(:,:,:,Rcvrs));
                end
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
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.AccumulateImage(GpuNum,p);
                    end
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    obj.NufftFuncs.CudaDeviceWait(GpuNum);
                end
%---
%                 obj.NufftFuncs.CudaDeviceWait(1);
%                 tic
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    ReturnNum = (q-1)*obj.ReconRxBatches + m;
                    obj.NufftFuncs.ReturnBaseImageCidx(GpuNum,obj.ImageMemPin,ReturnNum);
                end
%                 obj.NufftFuncs.CudaDeviceWait(1);
%                 toc
%---
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            Image = sum(obj.ImageMemPin,4);
            Scale = 1/obj.NufftFuncs.ConvScaleVal * single(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5 / single(obj.NufftFuncs.GridImageMatrixMemDims(1))^3;
            Image = Image*Scale;
            Error = UnRegisterHostMemCuda61(Data);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end           

%==================================================================
% Forward
%==================================================================         
        function Data = Forward(obj,Image)
%             tic
            Error = RegisterHostComplexMemCuda61(Image);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            if obj.NumRunsForward == 0 
                obj.DataMemPin = complex(zeros([obj.NumCol,obj.NumTraj,obj.RxChannels],'single'),0);
                Error = RegisterHostComplexMemCuda61(obj.DataMemPin);
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
            obj.NumRunsForward = obj.NumRunsForward+1;
%---
%             obj.NufftFuncs.CudaDeviceWait(1);
%             tic
            obj.NufftFuncs.LoadImageMatrixGpuMem(Image);
%             obj.NufftFuncs.CudaDeviceWait(1);
%             toc
%---
            for q = 1:obj.ReconRxBatches 
                RbStart = (q-1)*obj.ReconRxBatchLen + 1;
                RbStop = q*obj.ReconRxBatchLen;
                if RbStop > obj.RxChannels
                    RbStop = obj.RxChannels;
                end
                Rcvrs = RbStart:RbStop;
                if obj.ReconRxBatches ~= 1
                    obj.NufftFuncs.LoadRcvrProfMatricesGpuMum(obj.RxProfs(:,:,:,Rcvrs));
                end
                for p = 1:obj.ChanPerGpu 
                    obj.NufftFuncs.InitializeGridMatricesGpuMem;
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.RcvrWgtExpandImage(GpuNum,p);
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
                        obj.NufftFuncs.FourierTransform(GpuNum);
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
                        obj.NufftFuncs.ReverseGrid(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        obj.NufftFuncs.CudaDeviceWait(GpuNum);
                    end
%---
%                     obj.NufftFuncs.CudaDeviceWait(1);
%                     tic 
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.ReturnSampDatCidx(GpuNum,obj.DataMemPin,ChanNum);
                    end
%                     obj.NufftFuncs.CudaDeviceWait(1);
%                     toc
%---
                end
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            Scale = single(1/(obj.NufftFuncs.ConvScaleVal * obj.NufftFuncs.SubSamp.^3 * double(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5));
            Data = obj.DataMemPin*Scale;
            Error = UnRegisterHostMemCuda61(Image);
            if not(strcmp(Error,'no error'))
                error(Error);
            end 
%             obj.NufftFuncs.CudaDeviceWait(1);
%             obj.TestTime = [obj.TestTime toc];
%             TestTotalTime = sum(obj.TestTime)
        end
        
%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            if not(isempty(obj.DataMemPin))
                Error = UnRegisterHostMemCuda61(obj.DataMemPin);
                if not(strcmp(Error,'no error'))
                    error(Error);
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
