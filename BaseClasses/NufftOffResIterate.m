%================================================================
% NufftOffResIterate
%   
%================================================================

classdef NufftOffResIterate < handle

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
        OffResGridArr
        OffResGridBlockSize
        OffResLastGridBlockSize
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftOffResIterate()
            obj.NufftFuncs = NufftOffResFunctions();
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
        function Initialize(obj,Stitch,KernHolder,AcqInfo,RxChannels,RxProfs,OffResMap,OffResTimeArr,OtherGpuMemNeeded)
            
            if nargin < 9
                OtherGpuMemNeeded = 0;
            end
            
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
            BaseImageMemory = (obj.BaseMatrix^3)*36;     % basehold + image + temp + offresmap + invfilt (complex & single)
            DataKspaceMemory = AcqInfo.NumTraj*AcqInfo.NumCol*16;
            TotalMemory = GridMemory + BaseImageMemory + DataKspaceMemory + OtherGpuMemNeeded;
            AvailableMemory = obj.NufftFuncs.GpuParams.AvailableMemory;
            for n = 1:20
                obj.ReconRxBatches = n;
                obj.ChanPerGpu = ceil(obj.RxChannels/(obj.NumGpuUsed*obj.ReconRxBatches));
                MemoryNeededTotal = TotalMemory + BaseImageMemory * obj.ChanPerGpu;
                if MemoryNeededTotal*1.1 < AvailableMemory
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
            obj.NufftFuncs.Initialize(obj,KernHolder,AcqInfo,OffResMap,OffResTimeArr);

            %--------------------------------------
            % Off Resonance Stuff
            %--------------------------------------
            obj.OffResGridArr = AcqInfo.OffResGridArr;
            obj.OffResGridBlockSize = AcqInfo.OffResGridBlockSize;
            obj.OffResLastGridBlockSize = AcqInfo.OffResLastGridBlockSize;
            
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
                obj.NufftFuncs.InitializeBaseHoldMatricesGpuMem;
                for p = 1:obj.ChanPerGpu
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end
                        obj.NufftFuncs.LoadSampDatGpuMemAsyncCidx(GpuNum,Data,ChanNum);
                    end
                    obj.NufftFuncs.InitializeBaseMatricesGpuMem;
                    for r = 1:length(obj.OffResGridArr)
                        obj.NufftFuncs.InitializeGridMatricesGpuMem;
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end
                            if r < length(obj.OffResGridArr) 
                                obj.NufftFuncs.GridSampDatSubset(GpuNum,obj.OffResGridArr(r),obj.OffResGridBlockSize);      
                            elseif r == length(obj.OffResGridArr) 
                                obj.NufftFuncs.GridSampDatSubset(GpuNum,obj.OffResGridArr(r),obj.OffResLastGridBlockSize);
                            end
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
                            obj.NufftFuncs.AccumBaseImagesWithConjPhase(GpuNum,r);
                        end
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.AccumBaseHoldImagesWithRcvrs(GpuNum,p);
                    end
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    obj.NufftFuncs.MultInvFiltBaseHold(GpuNum);
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    obj.NufftFuncs.CudaDeviceWait(GpuNum);
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    ReturnNum = (q-1)*obj.NumGpuUsed + m;
                    obj.NufftFuncs.ReturnBaseHoldImageCidx(GpuNum,obj.ImageMemPin,ReturnNum);
                end
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            Image = sum(obj.ImageMemPin,4);
            Scale = 1/obj.NufftFuncs.ConvScaleVal * single(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5 / single(obj.NufftFuncs.GridImageMatrixMemDims(1))^3;
            Image = Image*Scale;
            if obj.DataMemPinBool
                obj.NufftFuncs.UnRegisterHostMemCuda(Data);
            end
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
            obj.NufftFuncs.LoadBaseHoldImageMatrixGpuMem(Image);
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.MultInvFiltBaseHold(GpuNum);
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
                obj.NufftFuncs.CudaDeviceWait(0);
                for p = 1:obj.ChanPerGpu 
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.RcvrWgtBaseHoldImage(GpuNum,p);
                    end
                    for r = 1:length(obj.OffResGridArr)
                        obj.NufftFuncs.InitializeGridImageMatricesGpuMem;                               % 0.25 ms
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end 
                            obj.NufftFuncs.PhaseAddOffResonance(GpuNum,r);                              % 0.55 ms
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
                            obj.NufftFuncs.FourierTransform(GpuNum);                                    % 1.9 ms
                        end
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end  
                            obj.NufftFuncs.KspaceFourierTransformShift(GpuNum);                         % 1.1 ms                       
                        end
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatchLen + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end
                            if r < length(obj.OffResGridArr) 
                                obj.NufftFuncs.ReverseGridSubset(GpuNum,obj.OffResGridArr(r),obj.OffResGridBlockSize);      % 0.1 ms
                            elseif r == length(obj.OffResGridArr) 
                                obj.NufftFuncs.ReverseGridSubset(GpuNum,obj.OffResGridArr(r),obj.OffResLastGridBlockSize);
                            end
                        end
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
