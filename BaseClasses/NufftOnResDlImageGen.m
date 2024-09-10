%================================================================
% NufftOnResDlImageGen
%   
%================================================================

classdef NufftOnResDlImageGen < handle

    properties (SetAccess = private)                                     
        NufftFuncs
        NumImages
        BaseMatrix
        GridMatrix
        TempMatrix
        ChanPerGpu = 1
        NumGpuUsed
        TestTime
        ImageMemPin
        DataMemPin
        ImageMemPinBool = 0
        DataMemPinBool = 0
        UseSdc = 1
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftOnResDlImageGen()
            obj.NufftFuncs = NufftFunctions();
        end

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,KernHolder,AcqInfo)
            
            obj.NumGpuUsed = KernHolder.Gpus2Use;
            obj.BaseMatrix = KernHolder.BaseMatrix;
            obj.GridMatrix = KernHolder.GridMatrix;
            obj.TempMatrix = KernHolder.BaseMatrix;
            obj.NumImages = KernHolder.NumImages;
            
            %--------------------------------------
            % Receive Batching
            %   - for limited memory GPUs (and/or many NumImages)
            %--------------------------------------             
            GridMemory = (obj.GridMatrix^3)*16;                         % k-space + image (complex & single)
            BaseImageMemory = (obj.BaseMatrix^3)*32;                    % image + temp (complex & single) + offresmap + invfilt 
            DataKspaceMemory = AcqInfo.NumTraj*AcqInfo.NumCol*8;        % (complex & single) 
            MemoryNeededTotal = GridMemory + BaseImageMemory + DataKspaceMemory;
            AvailableMemory = obj.NufftFuncs.GpuParams.AvailableMemory;
            if MemoryNeededTotal*1.1 > AvailableMemory
                error('Not enough space on graphics card');
            end         
            
            %--------------------------------------
            % Nufft Initialize
            %--------------------------------------
            obj.NufftFuncs.Initialize(obj,KernHolder,AcqInfo);  

            %--------------------------------------
            % Pin DataMemory
            %--------------------------------------
            obj.ImageMemPin = complex(zeros([obj.BaseMatrix obj.BaseMatrix obj.BaseMatrix,obj.NumImages],'single'),0);
            obj.NufftFuncs.RegisterHostComplexMemCuda(obj.ImageMemPin);
            obj.ImageMemPinBool = 1;
        end      

%==================================================================
% Inverse
%================================================================== 
        function Image = Inverse(obj,Data)

            obj.NufftFuncs.RegisterHostComplexMemCuda(Data);
            obj.DataMemPinBool = 1;
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.LoadSampDatGpuMemAsyncCidx(GpuNum,Data,m);
            end
            
            obj.NufftFuncs.InitializeGridMatricesGpuMem;
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.GridSampDat(GpuNum);
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.KspaceFourierTransformShift(GpuNum); 
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.InverseFourierTransform(GpuNum);
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.ImageFourierTransformShiftReduce(GpuNum); 
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
                obj.NufftFuncs.ReturnBaseImageCidx(GpuNum,obj.ImageMemPin,m);
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end

            Scale = 1/obj.NufftFuncs.ConvScaleVal * single(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5 / single(obj.NufftFuncs.GridImageMatrixMemDims(1))^3;
            Image = obj.ImageMemPin*Scale;

            if obj.DataMemPinBool
                obj.NufftFuncs.UnRegisterHostMemCuda(Data);         % always unregister 'Data'
                obj.DataMemPinBool = 0;
            end

        end  
        
%==================================================================
% Destructor
%================================================================== 
        function delete(obj)
            if obj.DataMemPinBool
                obj.NufftFuncs.UnRegisterHostMemCuda(obj.DataMemPin);
            end
            if obj.ImageMemPinBool
                obj.NufftFuncs.UnRegisterHostMemCuda(obj.ImageMemPin);
            end
            obj.NufftFuncs.FreeGpuMem;
        end        
        
    end
end
