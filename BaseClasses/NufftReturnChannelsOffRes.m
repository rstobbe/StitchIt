%================================================================
% NufftReturnChannelsOffRes
%   
%================================================================

classdef NufftReturnChannelsOffRes < handle

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
        OffResGridArr
        OffResGridBlockSize
        OffResLastGridBlockSize
        UseSdc = 1
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftReturnChannelsOffRes()
            obj.NufftFuncs = NufftOffResFunctions();
        end                        

%==================================================================
% SetUseSdc
%==================================================================           
        function SetUseSdc(obj,val)
            obj.UseSdc = val;
        end         
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,Stitch,KernHolder,AcqInfo,RxChannels,OffResMap,OffResTimeArr)
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
            TotalMemory = GridMemory + BaseImageMemory + DataKspaceMemory;
            AvailableMemory = obj.NufftFuncs.GpuParams.AvailableMemory;
            obj.ReconRxBatches = 1;
            obj.ChanPerGpu = ceil(obj.RxChannels/(obj.NumGpuUsed));
            if TotalMemory*1.2 > AvailableMemory
                error('Not enough space on graphics card');
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
        end      

%==================================================================
% Inverse
%================================================================== 
        function Image = Inverse(obj,Data)
            if obj.RxChannels > 1
                obj.NufftFuncs.RegisterHostComplexMemCuda(Data);
                obj.DataMemPinBool = 1;
            end
            obj.ImageMemPin = complex(zeros([obj.BaseMatrix obj.BaseMatrix obj.BaseMatrix,obj.RxChannels],'single'),0);
            obj.NufftFuncs.RegisterHostComplexMemCuda(obj.ImageMemPin);

            for p = 1:obj.ChanPerGpu
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    ChanNum = (p-1)*obj.NumGpuUsed + m;
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
                        ChanNum = (p-1)*obj.NumGpuUsed + m;
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
                        ChanNum = (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end  
                        obj.NufftFuncs.KspaceFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.InverseFourierTransform(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.ImageFourierTransformShiftReduceToTemp(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.NufftFuncs.AccumBaseImagesWithConjPhase(GpuNum,r);
                    end
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    ChanNum = (p-1)*obj.NumGpuUsed + m;
                    if ChanNum > obj.RxChannels
                        break
                    end 
                    obj.NufftFuncs.MultInvFiltBase(GpuNum);
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    ChanNum = (p-1)*obj.NumGpuUsed + m;
                    if ChanNum > obj.RxChannels
                        break
                    end 
                    obj.NufftFuncs.CudaDeviceWait(GpuNum);
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                    ChanNum = (p-1)*obj.NumGpuUsed + m;
                    if ChanNum > obj.RxChannels
                        break
                    end 
                    obj.NufftFuncs.ReturnBaseImageCidx(GpuNum,obj.ImageMemPin,ChanNum);
                end
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            Scale = 1/obj.NufftFuncs.ConvScaleVal * single(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5 / single(obj.NufftFuncs.GridImageMatrixMemDims(1))^3;
            Image = obj.ImageMemPin*Scale;
            if obj.DataMemPinBool
                obj.NufftFuncs.UnRegisterHostMemCuda(Data);
            end
        end           
        
%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            if not(isempty(obj.ImageMemPin))
                obj.NufftFuncs.UnRegisterHostMemCuda(obj.ImageMemPin);
            end
            obj.NufftFuncs.FreeGpuMem;
        end        
        
    end
end
