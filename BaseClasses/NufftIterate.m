%================================================================
% NufftIterate
%   
%================================================================

classdef NufftIterate < handle

    properties (SetAccess = private)                                     
        NufftFuncs
        RxChannels
        RxProfs
        BaseMatrix
        GridMatrix
        TempMatrix
        ChanPerGpu
        NumGpuUsed
        ReconRxBatches
        ReconRxBatchLen
        TestTime
        ImageMemPin
        DataMemPin
        ImageMemPinBool = 0
        DataMemPinBool = 0
        NumRunsInverse
        NumRunsForward
        SimulationScale = 0
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftIterate()
            obj.NufftFuncs = NufftFunctions();
        end                        

%==================================================================
% SetSimulationScale
%==================================================================           
        function SetSimulationScale(obj)
            obj.SimulationScale = 1;
        end

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Stitch,KernHolder,AcqInfo,RxChannels,RxProfs)
            obj.NumGpuUsed = Stitch.Gpus2Use;
            obj.BaseMatrix = Stitch.BaseMatrix;
            obj.GridMatrix = Stitch.GridMatrix;
            obj.TempMatrix = Stitch.BaseMatrix;
            obj.RxChannels = RxChannels;
            
            %--------------------------------------
            % Receive Batching
            %   - for limited memory GPUs (and/or many RxChannels)
            %--------------------------------------             
            GridMemory = (obj.GridMatrix^3)*16;          % k-space + image (complex & single)
            BaseImageMemory = (obj.BaseMatrix^3)*20;     % image + temp + invfilt (complex & single)
            DataKspaceMemory = AcqInfo.NumTraj*AcqInfo.NumCol*16;
            TotalMemory = GridMemory + BaseImageMemory + DataKspaceMemory;
            AvailableMemory = obj.NufftFuncs.GpuParams.AvailableMemory;
            for n = 1:20
                obj.ReconRxBatches = n;
                obj.ChanPerGpu = ceil(obj.RxChannels/(obj.NumGpuUsed*obj.ReconRxBatches));
                MemoryNeededTotal = TotalMemory + BaseImageMemory * obj.ChanPerGpu;
                if MemoryNeededTotal*1.15 < AvailableMemory
                    break
                else
                    if obj.ChanPerGpu == 1
                        error('Not enough space on graphics card');
                    end
                end
            end
            if obj.ReconRxBatches == 20
                error('Not enough GPU memory');
            end
            obj.ReconRxBatchLen = obj.ChanPerGpu * obj.NumGpuUsed;
            
            %--------------------------------------
            % Nufft Initialize
            %--------------------------------------
            obj.NufftFuncs.Initialize(obj,KernHolder,AcqInfo);

            %--------------------------------------
            % Load RxProfs
            %--------------------------------------   
            obj.NufftFuncs.AllocateRcvrProfMatricesGpuMem;   
            if obj.ReconRxBatches == 1
                obj.NufftFuncs.LoadRcvrProfMatricesGpuMum(RxProfs);
            else
                obj.RxProfs = RxProfs;
            end 
            obj.NumRunsInverse = 0;
            obj.NumRunsForward = 0;               
        end      

%==================================================================
% Inverse
%================================================================== 
        function Image = Inverse(obj,Data)
            if obj.RxChannels > 1
                obj.NufftFuncs.RegisterHostComplexMemCuda(Data);
                obj.DataMemPinBool = 1;
            end
            if obj.NumRunsInverse == 0 
                obj.ImageMemPin = complex(zeros([obj.BaseMatrix obj.BaseMatrix obj.BaseMatrix,obj.ReconRxBatches*obj.NumGpuUsed],'single'),0);
                obj.NufftFuncs.RegisterHostComplexMemCuda(obj.ImageMemPin);
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
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end
                        obj.NufftFuncs.LoadSampDatGpuMemAsyncCidx(GpuNum,Data,ChanNum);
                    end 
                    obj.NufftFuncs.InitializeGridMatricesGpuMem;
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end    
                        obj.NufftFuncs.GridSampDat(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end  
                        obj.NufftFuncs.KspaceFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.InverseFourierTransform(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.ImageFourierTransformShiftReduceToTemp(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.AccumBaseImagesWithRcvrs(GpuNum,p);
                    end
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    obj.NufftFuncs.MultInvFiltBase(GpuNum);
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    obj.NufftFuncs.CudaDeviceWait(GpuNum);
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    ReturnNum = (q-1)*obj.ReconRxBatchLen + m;
                    obj.NufftFuncs.ReturnBaseImageCidx(GpuNum,obj.ImageMemPin,ReturnNum);
                end
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            Image = sum(obj.ImageMemPin,4);
            Scale = 1/obj.NufftFuncs.ConvScaleVal * single(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5 / single(obj.NufftFuncs.GridImageMatrixMemDims(1))^3;
            Image = Image*Scale;
            obj.NufftFuncs.UnRegisterHostMemCuda(Data);
        end           

%==================================================================
% Forward
%==================================================================         
        function Data = Forward(obj,Image)
            obj.NufftFuncs.RegisterHostComplexMemCuda(Image);
            if obj.NumRunsForward == 0
                obj.DataMemPin = complex(zeros([obj.NufftFuncs.SampDatMemDims obj.RxChannels],'single'),0);
                if obj.RxChannels > 1
                    obj.NufftFuncs.RegisterHostComplexMemCuda(obj.DataMemPin);
                    obj.DataMemPinBool = 1;
                end
            end
            obj.NumRunsForward = obj.NumRunsForward+1;
            obj.NufftFuncs.LoadImageMatrixGpuMem(Image);
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.MultInvFiltBase(GpuNum);
            end
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
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.RcvrWgtBaseImage(GpuNum,p);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.ImageFourierTransformShiftExpandFromTemp(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.FourierTransform(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end  
                        obj.NufftFuncs.KspaceFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end    
                        obj.NufftFuncs.ReverseGrid(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        obj.NufftFuncs.CudaDeviceWait(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.ReturnSampDatCidx(GpuNum,obj.DataMemPin,ChanNum);
                    end
                end
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            if obj.SimulationScale
                Scale = single(1/(obj.NufftFuncs.ConvScaleVal * obj.NufftFuncs.SubSamp.^3));
            else
                Scale = single(1/(obj.NufftFuncs.ConvScaleVal * obj.NufftFuncs.SubSamp.^3 * double(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5));
            end
            Data = obj.DataMemPin*Scale;
            obj.NufftFuncs.UnRegisterHostMemCuda(Image);
%             obj.NufftFuncs.CudaDeviceWait(1);
%             obj.TestTime = [obj.TestTime toc];
%             TestTotalTime = sum(obj.TestTime)
        end
        
%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            if not(isempty(obj.DataMemPin))
                if obj.DataMemPinBool
                    obj.NufftFuncs.UnRegisterHostMemCuda(obj.DataMemPin);
                end
            end
            if not(isempty(obj.ImageMemPin))
                obj.NufftFuncs.UnRegisterHostMemCuda(obj.ImageMemPin);
            end
            obj.NufftFuncs.FreeGpuMem;
        end        
        
    end
end
