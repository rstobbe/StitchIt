%================================================================
% NufftOffResDlDataGen
%   
%================================================================

classdef NufftOnResDlDataGen < handle

    properties (SetAccess = private)                                     
        NufftFuncs
        NumImages
        BaseMatrix
        GridMatrix
        ChanPerGpu = 1
        NumGpuUsed
        TestTime
        ImageMemPin
        DataMemPin
        ImageMemPinBool = 0
        DataMemPinBool = 0
        OffResGridArr
        OffResGridBlockSize
        OffResLastGridBlockSize
        UseSdc = 0
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = NufftOnResDlDataGen()
            obj.NufftFuncs = NufftFunctions();
        end

%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,KernHolder,AcqInfo)
            
            obj.NumGpuUsed = KernHolder.Gpus2Use;
            obj.BaseMatrix = KernHolder.BaseMatrix;
            obj.GridMatrix = KernHolder.GridMatrix;
            obj.NumImages = KernHolder.NumImages;
            
            %--------------------------------------
            % Receive Batching
            %   - for limited memory GPUs (and/or many NumImages)
            %--------------------------------------             
            GridMemory = (obj.GridMatrix^3)*16;                         % k-space + image (complex & single)
            BaseImageMemory = (obj.BaseMatrix^3)*16;                    % image + invfilt (complex & single)
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
            obj.DataMemPin = complex(zeros([obj.NufftFuncs.SampDatMemDims obj.NumImages],'single'),0);
            obj.NufftFuncs.RegisterHostComplexMemCuda(obj.DataMemPin);
            obj.DataMemPinBool = 1;
        end      

%==================================================================
% LoadImage
%==================================================================        
        function LoadDiffImageEachGpu(obj,Image)
            sz = size(Image);
            if length(sz) == 3
                sz(4) = 1;
            end
            if sz(4) ~= obj.NumImages
                error('Image array should be same as number of gpus')
            end
            % obj.NufftFuncs.RegisterHostComplexMemCuda(Image);                         % I think need to make 4D (not sure it there is value)
            % obj.ImageMemPinBool = 1;
            obj.NufftFuncs.LoadBaseDiffImageMatricesGpuMem(Image);
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.MultInvFiltBase(GpuNum);
            end
            % obj.NufftFuncs.UnRegisterHostMemCuda(Image);                
            % obj.ImageMemPinBool = 0;
        end

%==================================================================
% Forward
%==================================================================         
        function Data = Forward(obj)
            
            obj.NufftFuncs.InitializeGridImageMatricesGpuMem;                              
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.ImageFourierTransformShiftExpandFromBase(GpuNum); 
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1; 
                obj.NufftFuncs.FourierTransform(GpuNum);                                   
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.KspaceFourierTransformShift(GpuNum);                                           
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.ReverseGrid(GpuNum);
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.ReturnSampDatCidx(GpuNum,obj.DataMemPin,m);
            end
            for m = 1:obj.NumGpuUsed
                GpuNum = m-1;
                obj.NufftFuncs.CudaDeviceWait(GpuNum);
            end
            %Scale = single(1/(obj.NufftFuncs.ConvScaleVal * obj.NufftFuncs.SubSamp.^3));
            Scale = single(1/(obj.NufftFuncs.ConvScaleVal * obj.NufftFuncs.SubSamp.^3 * double(obj.NufftFuncs.BaseImageMatrixMemDims(1)).^1.5));
            Data = obj.DataMemPin*Scale;

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
