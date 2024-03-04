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
        TempMatrix
        ChanPerGpu
        NumGpuUsed
        ReconRxBatches
        ReconRxBatchLen
        TestTime
        ImageMemPin
        ImageMemPinBool = 0
        DataMemPinBool = 0
        DoMemRegister = 1
        AvailableMemory
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftReturnChannels()
            obj.NufftFuncs = NufftFunctions();
        end                        

%==================================================================
% SetDoMemRegister
%==================================================================           
        function SetDoMemRegister(obj,val)
            obj.DoMemRegister = val;
        end        
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Stitch,KernHolder,AcqInfo,RxChannels)
            obj.NumGpuUsed = Stitch.Gpus2Use;
            obj.GridMatrix = Stitch.GridMatrix;
            if Stitch.TestFov2ReturnGridMatrix
                obj.TempMatrix = Stitch.GridMatrix;
                GridMemory = (obj.GridMatrix^3)*28;          % k-space + image + temp + invfilt (complex & single)
                BaseImageMemory = 0;
            else
                obj.BaseMatrix = Stitch.BaseMatrix;
                GridMemory = (obj.GridMatrix^3)*16;          % k-space + image (complex & single)
                BaseImageMemory = (obj.BaseMatrix^3)*12;     % image + invfilt (complex & single)
            end    
            obj.RxChannels = RxChannels;
            
            %--------------------------------------
            % Receive Batching
            %   - There is no batching in this case...
            %--------------------------------------             
            DataKspaceMemory = AcqInfo.NumTraj*AcqInfo.NumCol*16;
            TotalMemory = GridMemory + BaseImageMemory + DataKspaceMemory;
            obj.AvailableMemory = obj.NufftFuncs.GpuParams.AvailableMemory;
            obj.ReconRxBatches = 1;
            obj.ChanPerGpu = ceil(obj.RxChannels/(obj.NumGpuUsed));
            if TotalMemory*1.2 > obj.AvailableMemory
                error('Not enough space on graphics card');
            end
            obj.ReconRxBatchLen = obj.ChanPerGpu * obj.NumGpuUsed;              
            
            %--------------------------------------
            % Nufft Initialize
            %--------------------------------------
            obj.NufftFuncs.Initialize(obj,KernHolder,AcqInfo);
        end      

%==================================================================
% Inverse
%================================================================== 
        function Image = Inverse(obj,Stitch,Data)
            if obj.RxChannels > 1
                obj.NufftFuncs.RegisterHostComplexMemCuda(Data);
                obj.DataMemPinBool = 1;
            end
            if obj.ImageMemPinBool == 0 
                if Stitch.TestFov2ReturnGridMatrix
                    obj.ImageMemPin = complex(zeros([Stitch.GridMatrix Stitch.GridMatrix Stitch.GridMatrix,obj.RxChannels],'single'),0);
                else
                    obj.ImageMemPin = complex(zeros([Stitch.BaseMatrix Stitch.BaseMatrix Stitch.BaseMatrix,obj.RxChannels],'single'),0);
                end
                if obj.DoMemRegister
                    obj.NufftFuncs.RegisterHostComplexMemCuda(obj.ImageMemPin);
                    obj.ImageMemPinBool = 1;
                end
            end
            for q = 1:obj.ReconRxBatches 
                for p = 1:obj.ChanPerGpu
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end
                        obj.NufftFuncs.LoadSampDatGpuMemAsyncCidx(GpuNum,Data,ChanNum);
                    end 
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
                    if Stitch.TestFov2ReturnGridMatrix
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
                            obj.NufftFuncs.ImageFourierTransformShiftReduce(GpuNum); 
                        end
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                            if ChanNum > obj.RxChannels
                                break
                            end 
                            obj.NufftFuncs.MultInvFiltBase(GpuNum);
                        end
                        for m = 1:obj.NumGpuUsed
                            GpuNum = m-1;
                            obj.NufftFuncs.CudaDeviceWait(GpuNum);
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
            Scale = 1/obj.NufftFuncs.ConvScaleVal * single(Stitch.BaseMatrix).^1.5 / single(Stitch.GridMatrix)^3;
            Image = obj.ImageMemPin*Scale;
            
            if obj.DataMemPinBool
                obj.NufftFuncs.UnRegisterHostMemCuda(Data);     % always unregister 'Data'
            end
            if ~obj.DoMemRegister
                obj.ImageMemPin = [];                               % if no MemRegister, free up this memory space
            end
        end           
        
%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            if obj.DoMemRegister
                if not(isempty(obj.ImageMemPin))
                    obj.NufftFuncs.UnRegisterHostMemCuda(obj.ImageMemPin);
                end
            end
            obj.NufftFuncs.FreeGpuMem;
        end        
        
    end
end
