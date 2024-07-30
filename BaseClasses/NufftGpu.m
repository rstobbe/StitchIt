classdef NufftGpu < handle

    properties (SetAccess = private)                    
        GpuParams; CompCap; NumGpuUsed; ChanPerGpu;       
        HSampDat; SampDatMemDims;
        HReconInfo; ReconInfoMemDims;
        HKernel; iKern; KernHw; KernelMemDims; ConvScaleVal; SubSamp;
        HKspaceMatrix; HGridImageMatrix; HTempMatrix; GridImageMatrixMemDims;
        HBaseImageMatrix; BaseImageMatrixMemDims; TempImageMatrixMemDims;
        HRcvrProfMatrix;
        HFourierTransformPlan;
        HInvFilt;  
    end
    methods 

%==================================================================
% Constructor
%==================================================================   
        function obj = NufftGpu()           
            obj.GpuParams = gpuDevice; 
        end        
        
%==================================================================
% GpuInit
%==================================================================   
        function GpuInit(obj,Gpus2Use)
            obj.NumGpuUsed = uint64(Gpus2Use);
            obj.CompCap = num2str(round(str2double(obj.GpuParams.ComputeCapability)*10));
        end

%==================================================================
% SetChanPerGpu
%==================================================================           
        function SetChanPerGpu(obj,ChanPerGpu)
            obj.ChanPerGpu = ChanPerGpu;
        end
        
%% Allocate Memory
%==================================================================
% AllocateKspaceGridImageMatricesGpuMem
%==================================================================                      
        function AllocateKspaceGridImageMatricesGpuMem(obj,GridImageMatrixMemDims)
            if size(GridImageMatrixMemDims) ~= 3
                error('Specify 3D ');
            end
            obj.GridImageMatrixMemDims = uint64(GridImageMatrixMemDims);
            obj.HKspaceMatrix = zeros([1,obj.NumGpuUsed],'uint64');
            obj.HGridImageMatrix = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateInitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [obj.HKspaceMatrix(1,:),Error] = func(obj.NumGpuUsed,obj.GridImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            [obj.HGridImageMatrix(1,:),Error] = func(obj.NumGpuUsed,obj.GridImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          

%==================================================================
% AllocateTempMatrixGpuMem
%==================================================================                      
        function AllocateTempMatrixGpuMem(obj,TempMatrixMemDims)
            if isempty(TempMatrixMemDims)
                return
            end
            if size(TempMatrixMemDims) ~= 3
                error('Specify 3D ');
            end
            obj.TempImageMatrixMemDims = uint64(TempMatrixMemDims);
            obj.HTempMatrix = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateInitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [obj.HTempMatrix(1,:),Error] = func(obj.NumGpuUsed,obj.TempImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%==================================================================
% AllocateBaseImageMatricesGpuMem
%==================================================================                      
        function AllocateBaseImageMatricesGpuMem(obj,BaseImageMatrixMemDims)
            if isempty(BaseImageMatrixMemDims)
                return
            end
            if size(BaseImageMatrixMemDims) ~= 3
                error('Specify 3D ');
            end
            obj.BaseImageMatrixMemDims = uint64(BaseImageMatrixMemDims);
            obj.HBaseImageMatrix = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateInitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [obj.HBaseImageMatrix(1,:),Error] = func(obj.NumGpuUsed,obj.BaseImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end      

%==================================================================
% AllocateRcvrProfMatricesGpuMem
%==================================================================                      
        function AllocateRcvrProfMatricesGpuMem(obj)
            if isempty(obj.BaseImageMatrixMemDims)
                error('AllocateBaseImageMatricesGpuMem first');
            end
            obj.HRcvrProfMatrix = zeros([obj.ChanPerGpu,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateInitializeComplexMatrixAllGpuMem',obj.CompCap]);
            for n = 1:obj.ChanPerGpu
                [obj.HRcvrProfMatrix(n,:),Error] = func(obj.NumGpuUsed,obj.BaseImageMatrixMemDims);
                if not(strcmp(Error,'no error'))
                    MaxChanPerGpu = n
                    error(Error);
                end
            end
        end          
                       
%==================================================================
% AllocateReconInfoGpuMem
%   - ReconInfoMemDims: array of 3 (4 x proj x read [x,y,z,sdc])
%   - function allocates ReconInfo space on all GPUs
%================================================================== 
        function AllocateReconInfoGpuMem(obj,ReconInfoMemDims)    
            if ReconInfoMemDims(1) ~= 4
                error('ReconInfo dimensionality problem');  
            end
            obj.ReconInfoMemDims = uint64(ReconInfoMemDims);
            func = str2func(['AllocateReconInfoGpuMem',obj.CompCap]);
            [obj.HReconInfo,Error] = func(obj.NumGpuUsed,obj.ReconInfoMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end            
        
%==================================================================
% AllocateSampDatGpuMem
%   - SampDatMemDims: array of 2 (proj x read)
%   - function allocates SampDat space on all GPUs
%================================================================== 
        function AllocateSampDatGpuMem(obj,SampDatMemDims)    
            for n = 1:length(SampDatMemDims)
                if isempty(obj.ReconInfoMemDims)
                    error('AllocateReconInfoGpuMem first');
                end
                if SampDatMemDims(n) ~= obj.ReconInfoMemDims(n+1)
                    error('SampDat dimensionality problem');  
                end
            end
            obj.SampDatMemDims = uint64(SampDatMemDims);
            obj.HSampDat = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateSampDatGpuMem',obj.CompCap]);
            [obj.HSampDat(1,:),Error] = func(obj.NumGpuUsed,obj.SampDatMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
        
%% Initialize Matrices
               
%==================================================================
% InitializeGridMatricesGpuMem
%==================================================================                      
        function InitializeGridMatricesGpuMem(obj)
            func = str2func(['InitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HKspaceMatrix(1,:),obj.GridImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            [Error] = func(obj.NumGpuUsed,obj.HGridImageMatrix(1,:),obj.GridImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end           

%==================================================================
% InitializeBaseMatricesGpuMem
%==================================================================                      
        function InitializeBaseMatricesGpuMem(obj)
            func = str2func(['InitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HBaseImageMatrix(1,:),obj.BaseImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          
        
        
%% Load Matrices        
        
%==================================================================
% LoadKernelGpuMem
%   - All GPUs
%================================================================== 
        function LoadKernelGpuMem(obj,Kernel,iKern,KernHw,ConvScaleVal,SubSamp)
            if ~isa(Kernel,'single')
                error('Kernel must be in single format');
            end
            if ~isreal(Kernel)
                error('Kernel must be real');
            end  
            obj.ConvScaleVal = ConvScaleVal;
            obj.SubSamp = SubSamp;
            obj.iKern = uint64(iKern);
            obj.KernHw = uint64(KernHw);
            sz = size(Kernel);
            obj.KernelMemDims = uint64(sz);
            func = str2func(['AllocateLoadRealMatrixAllGpuMem',obj.CompCap]);
            [obj.HKernel,Error] = func(obj.NumGpuUsed,Kernel);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end    
        
%==================================================================
% LoadInvFiltGpuMem
%   - All GPUs
%================================================================== 
        function LoadInvFiltGpuMem(obj,InvFilt)
            if ~isa(InvFilt,'single')
                error('InvFilt must be in single format');
            end 
            func = str2func(['AllocateLoadRealMatrixAllGpuMem',obj.CompCap]);
            [obj.HInvFilt,Error] = func(obj.NumGpuUsed,InvFilt);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end  

%==================================================================
% LoadReconInfoGpuMem
%   - kMat -> already normalized
%   - ReconInfo: read x proj x 4 [x,y,z,sdc]
%   - function loads ReconInfo on all GPUs
%================================================================== 
        function LoadReconInfoGpuMem(obj,ReconInfo)
            if ~isa(ReconInfo,'single')
                error('ReconInfo must be in single format');
            end       
            sz = size(ReconInfo);
            for n = 1:length(sz)
                if sz(n) ~= obj.ReconInfoMemDims(n)
                    error('ReconInfo dimensionality problem');  
                end
            end
            func = str2func(['LoadReconInfoGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HReconInfo,ReconInfo);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         

%==================================================================
% LoadReconInfoGpuMemAsync
%   - kMat -> already normalized
%   - ReconInfo: 4 x proj x read [x,y,z,sdc]
%   - function loads ReconInfo on all GPUs
%================================================================== 
        function LoadReconInfoGpuMemAsync(obj,ReconInfo)
            if ~isa(ReconInfo,'single')
                error('ReconInfo must be in single format');
            end       
            sz = size(ReconInfo);
            for n = 1:length(sz)
                if sz(n) ~= obj.ReconInfoMemDims(n)
                    error('ReconInfo dimensionality problem');  
                end
            end
            func = str2func(['LoadReconInfoGpuMemAsync',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HReconInfo,ReconInfo);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end            

%==================================================================
% LoadSampDatGpuMemAsyncCidx
%   - SampDat: proj x read
%   - function loads SampDat on one GPU asynchronously
%   - Index in C
%================================================================== 
        function LoadSampDatGpuMemAsyncCidx(obj,LoadGpuNum,SampDat,ChanNum)
            if LoadGpuNum > obj.NumGpuUsed-1
                error('Specified ''LoadGpuNum'' beyond number of GPUs used');
            end
            LoadGpuNum = uint64(LoadGpuNum);
            if ~isa(SampDat,'single')
                error('SampDat must be in single format');
            end
            ChanNum = uint64(ChanNum);
            func = str2func(['LoadSampDatGpuMemAsyncCidx',obj.CompCap]);
            [Error] = func(LoadGpuNum,obj.HSampDat(1,:),SampDat,ChanNum);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%==================================================================
% LoadRcvrProfMatricesGpuMem
%================================================================== 
        function LoadRcvrProfMatricesGpuMem(obj,RcvrProfs)
            sz = size(RcvrProfs);
            if sum(sz(1:3)) ~= sum(obj.BaseImageMatrixMemDims)
                error('RcvrProfs dimensionality problem');
            end
            if length(sz) == 3
                if obj.ChanPerGpu * obj.NumGpuUsed ~= 1
                    error('RcvrProfs dimensionality problem');
                end
                sz(4) = 1;
            else
                if sz(4) > (obj.ChanPerGpu * obj.NumGpuUsed)
                    error('RcvrProfs dimensionality problem');
                end
            end
            if ~isa(RcvrProfs,'single')
                error('RcvrProfs must be in single format');
            end
            if isreal(RcvrProfs)
                error('RcvrProfs must be complex');
            end            
            func = str2func(['LoadComplexMatrixSingleGpuMemAsync',obj.CompCap]);
            for p = 1:obj.ChanPerGpu
                for m = 1:obj.NumGpuUsed
                    GpuNum = uint64(m-1);
                    ChanNum = (p-1)*obj.NumGpuUsed+m;
                    if ChanNum > sz(4)
                        break
                    end
                    [Error] = func(GpuNum,obj.HRcvrProfMatrix(p,:),RcvrProfs(:,:,:,ChanNum));                  
                    if not(strcmp(Error,'no error'))
                        error(Error);
                    end
                end
            end
        end          
        
%==================================================================
% LoadImageMatrixGpuMem
%================================================================== 
        function LoadImageMatrixGpuMem(obj,Image)
            sz = size(Image);
%             if length(sz) ~= 3
%                 error('Image dimensionality problem');
%             end
            if sum(sz(1:3)) ~= sum(obj.BaseImageMatrixMemDims)
                error('Image dimensionality problem');
            end
            if ~isa(Image,'single')
                error('Image must be in single format');
            end
            if isreal(Image)
                error('Image must be complex');
            end            
            func = str2func(['LoadComplexMatrixSingleGpuMemAsync',obj.CompCap]);
            for m = 1:obj.NumGpuUsed
                GpuNum = uint64(m-1);
                [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),Image);                  
                if not(strcmp(Error,'no error'))
                    disp('LoadImageMatrixGpuMem');
                    error(Error);
                end
            end
        end 

%==================================================================
% LoadBaseDiffImageMatricesGpuMem
%================================================================== 
        function LoadBaseDiffImageMatricesGpuMem(obj,Image0)
            sz = size(Image0);
            if sum(sz(1:3)) ~= sum(obj.BaseImageMatrixMemDims)
                error('Image dimensionality problem');
            end
            if length(sz) == 3
                if obj.ChanPerGpu * obj.NumGpuUsed ~= 1
                    error('Image dimensionality problem');
                end
                sz(4) = 1;
            else
                if sz(4) > (obj.ChanPerGpu * obj.NumGpuUsed)
                    error('Image dimensionality problem');
                end
            end
            if ~isa(Image0,'single')
                error('Image must be in single format');
            end         
            func = str2func(['LoadComplexMatrixSingleGpuMemAsync',obj.CompCap]);
            for m = 1:obj.NumGpuUsed
                GpuNum = uint64(m-1);
                Image = Image0(:,:,:,m);
                if isreal(Image)
                    Image = complex(single(Image),0);
                end   
                [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),Image);                  
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
        end           

        
%% Setup        
        
%==================================================================
% SetupFourierTransform
%   - All GPUs
%==================================================================         
        function SetupFourierTransform(obj)
            if isempty(obj.GridImageMatrixMemDims)
                error('AllocateKspaceImageMatricesGpuMem first');
            end
            func = str2func(['CreateFourierTransformPlanAllGpu',obj.CompCap]);
            [obj.HFourierTransformPlan,Error] = func(obj.NumGpuUsed,obj.GridImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end
            
%% Functions

%==================================================================
% GridSampDat
%==================================================================                      
        function GridSampDat(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['GridSampDat',obj.CompCap]);
            [Error] = func(GpuNum,obj.HSampDat(1,:),obj.HReconInfo,obj.HKernel,obj.HKspaceMatrix(1,:),...
                                    obj.SampDatMemDims,obj.KernelMemDims,obj.GridImageMatrixMemDims,obj.iKern,obj.KernHw);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end                   
 
%==================================================================
% ReverseGrid
%==================================================================                      
        function ReverseGrid(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['ReverseGrid',obj.CompCap]);
            [Error] = func(GpuNum,obj.HSampDat(1,:),obj.HReconInfo,obj.HKernel,obj.HKspaceMatrix(1,:),...
                                    obj.SampDatMemDims,obj.KernelMemDims,obj.GridImageMatrixMemDims,obj.iKern,obj.KernHw);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end           
        
%==================================================================
% KspaceFourierTransformShift
%==================================================================         
        function KspaceFourierTransformShift(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['FourierTransformShiftSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HKspaceMatrix(1,:),obj.HGridImageMatrix,obj.GridImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end     

%==================================================================
% ImageFourierTransformShift
%==================================================================         
        function ImageFourierTransformShift(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['FourierTransformShiftSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HTempMatrix,obj.GridImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end  

%==================================================================
% ImageFourierTransformShiftReduce
%==================================================================         
        function ImageFourierTransformShiftReduce(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);            
            GpuNum = uint64(GpuNum);
            func = str2func(['FourierTransformShiftReduceSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HBaseImageMatrix(1,:),obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          

%==================================================================
% ImageFourierTransformShiftReduceToTemp
%==================================================================         
        function ImageFourierTransformShiftReduceToTemp(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);            
            GpuNum = uint64(GpuNum);
            func = str2func(['FourierTransformShiftReduceSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HTempMatrix(1,:),obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         

%==================================================================
% ImageFourierTransformShiftExpandFromTemp
%==================================================================         
        function ImageFourierTransformShiftExpandFromTemp(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);            
            GpuNum = uint64(GpuNum);
            func = str2func(['FourierTransformShiftExpandSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HTempMatrix(1,:),obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end        

%==================================================================
% ImageFourierTransformShiftExpandFromBase
%==================================================================         
        function ImageFourierTransformShiftExpandFromBase(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);            
            GpuNum = uint64(GpuNum);
            func = str2func(['FourierTransformShiftExpandSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HBaseImageMatrix(1,:),obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end 

%==================================================================
% InverseFourierTransform
%==================================================================         
        function InverseFourierTransform(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            %func = str2func(['ExecuteInverseFourierTransformSingleGpu',obj.CompCap]);
            func = str2func(['ExecuteInverseFourierTransformSingleGpuNoScale',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HKspaceMatrix(1,:),obj.HFourierTransformPlan,obj.GridImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end   

%==================================================================
% FourierTransform
%==================================================================         
        function FourierTransform(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['ExecuteFourierTransformSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HKspaceMatrix(1,:),obj.HFourierTransformPlan);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end   
        
%==================================================================
% MultInvFilt
%==================================================================         
        function MultInvFilt(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['DivideComplexMatrixRealMatrixSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HInvFilt,obj.GridImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end              

%==================================================================
% MultInvFiltBase
%==================================================================         
        function MultInvFiltBase(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['DivideComplexMatrixRealMatrixSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),obj.HInvFilt,obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         

%==================================================================
% MultInvFiltBaseTemp
%==================================================================         
        function MultInvFiltBaseTemp(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['DivideComplexMatrixRealMatrixSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HTempMatrix(1,:),obj.HInvFilt,obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%==================================================================
% InverseKspaceScaleCorrect
%   **  Do not use. Excessively slow
%==================================================================         
%         function InverseKspaceScaleCorrect(obj,GpuNum)
%             if GpuNum > obj.NumGpuUsed-1
%                 error('Specified ''GpuNum'' beyond number of GPUs used');
%             end
%             GpuNum = uint64(GpuNum);
%             Scale = single((1/obj.ConvScaleVal) * double(obj.BaseImageMatrixMemDims(1)).^1.5);
%             func = str2func(['ScaleComplexMatrixSingleGpu',obj.CompCap]);
%             [Error] = func(GpuNum,obj.HKspaceMatrix(1,:),Scale,obj.GridImageMatrixMemDims);  
%             if not(strcmp(Error,'no error'))
%                 error(Error);
%             end
%         end           

%==================================================================
% ForwardKspaceScaleCorrect
%   **  Do not use. Excessively slow
%==================================================================         
%         function ForwardKspaceScaleCorrect(obj,GpuNum)
%             if GpuNum > obj.NumGpuUsed-1
%                 error('Specified ''GpuNum'' beyond number of GPUs used');
%             end
%             GpuNum = uint64(GpuNum);
%             Scale = single(1/(obj.ConvScaleVal * obj.SubSamp.^3 * double(obj.BaseImageMatrixMemDims(1)).^1.5));
%             func = str2func(['ScaleComplexMatrixSingleGpu',obj.CompCap]);
%             [Error] = func(GpuNum,obj.HKspaceMatrix(1,:),Scale,obj.GridImageMatrixMemDims);  
%             if not(strcmp(Error,'no error'))
%                 error(Error);
%             end
%         end        
        
%==================================================================
% AccumulateImage
%==================================================================         
        function AccumulateImage(obj,GpuNum,GpuChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            if GpuChanNum > obj.ChanPerGpu
                error('Specified ''GpuChanNum'' beyond number of GPU channels used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);
            GpuNum = uint64(GpuNum);
            func = str2func(['AccumulateImageSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HRcvrProfMatrix(GpuChanNum,:),obj.HBaseImageMatrix(1,:),...
                                obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          

%==================================================================
% AccumBaseImagesWithRcvrs
%==================================================================         
        function AccumBaseImagesWithRcvrs(obj,GpuNum,GpuChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            if GpuChanNum > obj.ChanPerGpu
                error('Specified ''GpuChanNum'' beyond number of GPU channels used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['AccumBaseImagesWithRcvrsSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),obj.HRcvrProfMatrix(GpuChanNum,:),obj.HTempMatrix(1,:),obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%==================================================================
% RcvrWgtExpandImage
%==================================================================         
        function RcvrWgtExpandImage(obj,GpuNum,GpuChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            if GpuChanNum > obj.ChanPerGpu
                error('Specified ''GpuChanNum'' beyond number of GPU channels used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);
            GpuNum = uint64(GpuNum);
            func = str2func(['RcvrWgtExpandImageSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HRcvrProfMatrix(GpuChanNum,:),obj.HBaseImageMatrix(1,:),...
                                obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end        
        
%==================================================================
% RcvrWgtBaseImage
%==================================================================         
        function RcvrWgtBaseImage(obj,GpuNum,GpuChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            if GpuChanNum > obj.ChanPerGpu
                error('Specified ''GpuChanNum'' beyond number of GPU channels used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['RcvrWgtBaseImageSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HTempMatrix(1,:),obj.HRcvrProfMatrix(GpuChanNum,:),obj.HBaseImageMatrix(1,:),obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end  
        
        
%% Utilities           

%==================================================================
% ReturnKspace (old) - make Cidx version
%================================================================== 
%         function KspaceMatrix = ReturnKspace(obj,GpuNum)
%             if GpuNum > obj.NumGpuUsed-1
%                 error('Specified ''GpuNum'' beyond number of GPUs used');
%             end
%             GpuNum = uint64(GpuNum);
%             func = str2func(['ReturnComplexMatrixSingleGpu',obj.CompCap]);
%             [KspaceMatrix,Error] = func(GpuNum,obj.HKspaceMatrix(1,:),obj.GridImageMatrixMemDims);
%             if not(strcmp(Error,'no error'))
%                 error(Error);
%             end
%         end  

%==================================================================
% ReturnGridImage (old)
%================================================================== 
%         function ImageMatrix = ReturnGridImage(obj,GpuNum)
%             if GpuNum > obj.NumGpuUsed-1
%                 error('Specified ''GpuNum'' beyond number of GPUs used');
%             end
%             GpuNum = uint64(GpuNum);
%             func = str2func(['ReturnComplexMatrixSingleGpu',obj.CompCap]);
%             [ImageMatrix,Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.GridImageMatrixMemDims);
%             if not(strcmp(Error,'no error'))
%                 error(Error);
%             end
%         end 

%==================================================================
% ReturnGridImageCidx
%================================================================== 
        function ReturnGridImageCidx(obj,GpuNum,ImageMatrix,ChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            ChanNum = uint64(ChanNum);
            func = str2func(['ReturnComplexMatrixSingleGpuCidx',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),ImageMatrix,ChanNum);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%==================================================================
% ReturnBaseImage (old)
%================================================================== 
        function ImageMatrix = ReturnBaseImage(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['ReturnComplexMatrixSingleGpu',obj.CompCap]);
            [ImageMatrix,Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),obj.BaseImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         

%==================================================================
% ReturnBaseImageCidx
%================================================================== 
        function ReturnBaseImageCidx(obj,GpuNum,ImageMatrix,ChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            ChanNum = uint64(ChanNum);
            func = str2func(['ReturnComplexMatrixSingleGpuCidx',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),ImageMatrix,ChanNum);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%==================================================================
% ReturnSampDat (old)
%================================================================== 
%         function SampDat = ReturnSampDat(obj,GpuNum)
%             if GpuNum > obj.NumGpuUsed-1
%                 error('Specified ''GpuNum'' beyond number of GPUs used');
%             end
%             GpuNum = uint64(GpuNum);
%             %func = str2func(['ReturnSampDatSingleGpuRI',obj.CompCap]);                 % old
%             func = str2func(['ReturnSampDatSingleGpu',obj.CompCap]);
%             [SampDat,Error] = func(GpuNum,obj.HSampDat(1,:),obj.SampDatMemDims);
%             if not(strcmp(Error,'no error'))
%                 error(Error);
%             end
%         end         
 
%==================================================================
% ReturnSampDatCidx
%================================================================== 
        function ReturnSampDatCidx(obj,GpuNum,SampDat,ChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            ChanNum = uint64(ChanNum);
            func = str2func(['ReturnSampDatSingleGpuCidx',obj.CompCap]);
            [Error] = func(GpuNum,obj.HSampDat(1,:),SampDat,ChanNum);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end       
        
%==================================================================
% Grid2BaseImage
%==================================================================         
        function Grid2BaseImage(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);
            GpuNum = uint64(GpuNum);
            func = str2func(['ReturnFovSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HBaseImageMatrix(1,:),obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end            

%==================================================================
% Base2GridImage
%==================================================================         
        function Base2GridImage(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            Inset = uint64((obj.GridImageMatrixMemDims(1) - obj.BaseImageMatrixMemDims(1))/2);
            GpuNum = uint64(GpuNum);
            func = str2func(['ExpandFovSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HGridImageMatrix(1,:),obj.HBaseImageMatrix(1,:),obj.GridImageMatrixMemDims,obj.BaseImageMatrixMemDims,Inset);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end   

%==================================================================
% RegisterHostMemCuda
%==================================================================         
        function RegisterHostMemCuda(obj,Mem)
            func = str2func(['RegisterHostMemCuda',obj.CompCap]);
            [Error] = func(Mem);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end           
        
%==================================================================
% RegisterHostComplexMemCuda
%==================================================================         
        function RegisterHostComplexMemCuda(obj,Mem)
            func = str2func(['RegisterHostComplexMemCuda',obj.CompCap]);
            [Error] = func(Mem);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          

%==================================================================
% UnRegisterHostMemCuda
%==================================================================         
        function UnRegisterHostMemCuda(obj,Mem)
            func = str2func(['UnRegisterHostMemCuda',obj.CompCap]);
            [Error] = func(Mem);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end        
        
%% TakeDown       
           
%==================================================================
% FreeKernelGpuMem
%================================================================== 
        function FreeKernelGpuMem(obj)    
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HKernel);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HKernel = [];
        end          
        
%==================================================================
% FreeInvFiltGpuMem
%================================================================== 
        function FreeInvFiltGpuMem(obj)    
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HInvFilt);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HInvFilt = [];
        end                     
        
%==================================================================
% FreeReconInfoGpuMem
%================================================================== 
        function FreeReconInfoGpuMem(obj)    
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HReconInfo);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HReconInfo = [];
        end          
              
%==================================================================
% FreeSampDatGpuMem
%================================================================== 
        function FreeSampDatGpuMem(obj)    
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HSampDat(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HSampDat = [];
        end       
       
%==================================================================
% FreeKspaceMatricesGpuMem
%==================================================================                      
        function FreeKspaceMatricesGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HKspaceMatrix(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HKspaceMatrix = [];
        end    
        
%==================================================================
% FreeGridImageMatricesGpuMem
%==================================================================                      
        function FreeGridImageMatricesGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HGridImageMatrix(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HGridImageMatrix = [];
        end                       

%==================================================================
% FreeTempMatricesGpuMem
%==================================================================                      
        function FreeTempMatricesGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HTempMatrix(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HTempMatrix = [];
        end         
        
%==================================================================
% FreeBaseImageMatricesGpuMem
%==================================================================                      
        function FreeBaseImageMatricesGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HBaseImageMatrix(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HBaseImageMatrix = [];
        end         

%==================================================================
% FreeRcvrProfImageMatricesGpuMem
%==================================================================                      
        function FreeRcvrProfMatricesGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            for n = 1:obj.ChanPerGpu
                [Error] = func(obj.NumGpuUsed,obj.HRcvrProfMatrix(n,:));
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end            
            obj.HRcvrProfMatrix = [];
        end         
        
%==================================================================
% ReleaseFourierTransform
%   - All GPUs
%==================================================================         
        function ReleaseFourierTransform(obj)
            func = str2func(['TeardownFourierTransformPlanAllGpu',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HFourierTransformPlan);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HFourierTransformPlan = [];
        end         
               
%==================================================================
% CudaDeviceWait
%================================================================== 
        function CudaDeviceWait(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['CudaDeviceWait',obj.CompCap]);
            [Error] = func(GpuNum);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end
                
    end
end

        