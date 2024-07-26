classdef NufftOffResGpu < NufftGpu

    properties (SetAccess = private)                    
        HOffResMap;
        HBaseHoldImageMatrix;
        HOffResTimeArr;
    end
    methods 

%==================================================================
% Constructor
%==================================================================   
        function obj = NufftOffResGpu()           
        end        
        
%% Allocate/Load

%==================================================================
% AllocateOffResMapGpuMem
%==================================================================                      
        function AllocateOffResMapGpuMem(obj)
            if isempty(obj.BaseImageMatrixMemDims)
                error('AllocateBaseImageMatricesGpuMem First');
            end
            obj.HOffResMap = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateRealMatrixAllGpuMem',obj.CompCap]);
            [obj.HOffResMap(1,:),Error] = func(obj.NumGpuUsed,obj.BaseImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end 

%==================================================================
% LoadDiffOffResonanceMapEachGpu
%================================================================== 
        function LoadDiffOffResonanceMapEachGpu(obj,OffResMap)
            sz = size(OffResMap);
            if sum(sz(1:3)) ~= sum(obj.BaseImageMatrixMemDims)
                error('Image dimensionality problem');
            end
            if length(sz) == 3
                if obj.ChanPerGpu * obj.NumGpuUsed ~= 1
                    error('Image dimensionality problem');
                end
            else
                if sz(4) > (obj.ChanPerGpu * obj.NumGpuUsed)
                    error('Image dimensionality problem');
                end
            end
            if ~isa(OffResMap,'single')
                error('Image must be in single format');
            end         
            func = str2func(['LoadRealMatrixSingleGpuMemAsync',obj.CompCap]);
            for m = 1:obj.NumGpuUsed
                GpuNum = uint64(m-1);
                [Error] = func(GpuNum,obj.HOffResMap(1,:),OffResMap(:,:,:,m));                  
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
        end         

%==================================================================
% LoadOffResMapGpuMem
%==================================================================                      
        function LoadOffResMapGpuMem(obj,OffResMap)
            sz = size(OffResMap);
            if sum(sz(1:3)) ~= sum(obj.BaseImageMatrixMemDims)
                error('OffResMap dimensionality problem');
            end
            if ~isa(OffResMap,'single')
                error('OffResMap must be in single format');
            end
            if ~isreal(OffResMap)
                error('OffResMap must be real');
            end 
            obj.HOffResMap = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateLoadRealMatrixAllGpuMem',obj.CompCap]);
            [obj.HOffResMap(1,:),Error] = func(obj.NumGpuUsed,OffResMap);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          

%==================================================================
% LoadDiffOffResMapEachGpuMem
%================================================================== 
        function LoadDiffOffResMapEachGpuMem(obj,OffResMap)
            sz = size(OffResMap);
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
            if ~isa(OffResMap,'single')
                error('Image must be in single format');
            end 
            if ~isreal(OffResMap)
                error('OffResMap must be real');
            end 
            func = str2func(['LoadComplexMatrixSingleGpuMemAsync',obj.CompCap]);
            for m = 1:obj.NumGpuUsed
                GpuNum = uint64(m-1);
                Image = Image0(:,:,:,m);
                if isreal(Image)
                    Image = complex(single(Image),0);
                end   
                [Error] = func(GpuNum,obj.HBaseHoldImageMatrix(1,:),Image);                  
                if not(strcmp(Error,'no error'))
                    error(Error);
                end
            end
        end 

%==================================================================
% LoadOffResTimeArrGpuMem
%==================================================================                      
        function LoadOffResTimeArrGpuMem(obj,OffResTimeArr)
            if ~isa(OffResTimeArr,'single')
                error('OffResTimeArr must be in single format');
            end
            if ~isreal(OffResTimeArr)
                error('OffResTimeArr must be real');
            end 
            OffResTimeArr = reshape(OffResTimeArr,[1,1,length(OffResTimeArr)]);
            obj.HOffResTimeArr = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateLoadRealMatrixAllGpuMem',obj.CompCap]);
            [obj.HOffResTimeArr(1,:),Error] = func(obj.NumGpuUsed,OffResTimeArr);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end            
        
%==================================================================
% AllocateBaseHoldImageMatricesGpuMem
%==================================================================                      
        function AllocateBaseHoldImageMatricesGpuMem(obj)
            if isempty(obj.BaseImageMatrixMemDims)
                error('AllocateBaseImageMatricesGpuMem First');
            end
            obj.HBaseHoldImageMatrix = zeros([1,obj.NumGpuUsed],'uint64');
            func = str2func(['AllocateInitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [obj.HBaseHoldImageMatrix(1,:),Error] = func(obj.NumGpuUsed,obj.BaseImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end 

%==================================================================
% LoadBaseHoldImageMatrixGpuMem
%================================================================== 
        function LoadBaseHoldImageMatrixGpuMem(obj,Image)
            sz = size(Image);
            if sum(sz(1:3)) ~= sum(obj.BaseImageMatrixMemDims)
                error('Image dimensionality problem');
            end
            if ~isa(Image,'single')
                error('Image must be in single format');
            end
            if isreal(Image)
                error('Image must be complex');
            end            
            func = str2func(['LoadComplexMatrixAllGpuMemAsync',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HBaseHoldImageMatrix(1,:),Image);                  
            if not(strcmp(Error,'no error'))
                disp('LoadComplexMatrixAllGpuMemAsync');
                error(Error);
            end
        end 

%==================================================================
% LoadBaseHoldDiffImageMatricesGpuMem
%================================================================== 
        function LoadBaseHoldDiffImageMatricesGpuMem(obj,Image0)
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
                [Error] = func(GpuNum,obj.HBaseHoldImageMatrix(1,:),Image);                  
                if not(strcmp(Error,'no error'))
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

%% Initialize Matrices
               
%==================================================================
% InitializeGridImageMatricesGpuMem
%==================================================================                      
        function InitializeGridImageMatricesGpuMem(obj)
            func = str2func(['InitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HGridImageMatrix(1,:),obj.GridImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end                       
        
%==================================================================
% InitializeBaseHoldMatricesGpuMem
%==================================================================                      
        function InitializeBaseHoldMatricesGpuMem(obj)
            func = str2func(['InitializeComplexMatrixAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HBaseHoldImageMatrix(1,:),obj.BaseImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end  
        
%% Functions

%==================================================================
% AccumBaseImagesWithConjPhase
%==================================================================         
        function AccumBaseImagesWithConjPhase(obj,GpuNum,OffResTimNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            OffResTimNum = uint64(OffResTimNum-1);
            func = str2func(['AccumBaseImagesWithConjPhaseSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),obj.HOffResMap(1,:),obj.HTempMatrix(1,:),obj.HOffResTimeArr(1,:),OffResTimNum,obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end 

%==================================================================
% AccumBaseHoldImagesWithRcvrs
%==================================================================         
        function AccumBaseHoldImagesWithRcvrs(obj,GpuNum,GpuChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            if GpuChanNum > obj.ChanPerGpu
                error('Specified ''GpuChanNum'' beyond number of GPU channels used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['AccumBaseImagesWithRcvrsSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseHoldImageMatrix(1,:),obj.HRcvrProfMatrix(GpuChanNum,:),obj.HBaseImageMatrix(1,:),obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%==================================================================
% PhaseAddOffResonance
%==================================================================                      
        function PhaseAddOffResonance(obj,GpuNum,OffResTimNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            OffResTimNum = uint64(OffResTimNum-1);
            func = str2func(['PhaseAddOffResonance',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),obj.HOffResMap(1,:),obj.HTempMatrix(1,:),obj.HOffResTimeArr(1,:),...
                                    OffResTimNum,obj.BaseImageMatrixMemDims);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end                        

%==================================================================
% GridSampDatSubset
%==================================================================                      
        function GridSampDatSubset(obj,GpuNum,SampStart,SampBlock)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            SampBlock = uint64([1 SampBlock]);
            HSampDatTemp = obj.HSampDat(1,:) + uint64((SampStart-1)*2*4);        % complex/float
            HReconInfoTemp = obj.HReconInfo(1,:) + uint64((SampStart-1)*4*4);        % x,y,z,sdc/float
            func = str2func(['GridSampDat',obj.CompCap]);
            [Error] = func(GpuNum,HSampDatTemp,HReconInfoTemp,obj.HKernel,obj.HKspaceMatrix(1,:),...
                                    SampBlock,obj.KernelMemDims,obj.GridImageMatrixMemDims,obj.iKern,obj.KernHw);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          
        
%==================================================================
% ReverseGridSubset
%==================================================================                      
        function ReverseGridSubset(obj,GpuNum,SampStart,SampBlock)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            SampBlock = uint64([1 SampBlock]);
            HSampDatTemp = obj.HSampDat(1,:) + uint64((SampStart-1)*2*4);        % complex/float
            HReconInfoTemp = obj.HReconInfo(1,:) + uint64((SampStart-1)*4*4);        % x,y,z,sdc/float
            func = str2func(['ReverseGrid',obj.CompCap]);
            [Error] = func(GpuNum,HSampDatTemp,HReconInfoTemp,obj.HKernel,obj.HKspaceMatrix(1,:),...
                                    SampBlock,obj.KernelMemDims,obj.GridImageMatrixMemDims,obj.iKern,obj.KernHw);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end          
        
%==================================================================
% MultInvFiltBaseHold
%==================================================================         
        function MultInvFiltBaseHold(obj,GpuNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['DivideComplexMatrixRealMatrixSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseHoldImageMatrix(1,:),obj.HInvFilt,obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end 

%==================================================================
% ReturnBaseHoldImageCidx
%================================================================== 
        function ReturnBaseHoldImageCidx(obj,GpuNum,ImageMatrix,ChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            ChanNum = uint64(ChanNum);
            func = str2func(['ReturnComplexMatrixSingleGpuCidx',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseHoldImageMatrix(1,:),ImageMatrix,ChanNum);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         

%==================================================================
% ReturnTempImageCidx
%================================================================== 
        function ReturnTempImageCidx(obj,GpuNum,ImageMatrix,ChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            GpuNum = uint64(GpuNum);
            ChanNum = uint64(ChanNum);
            func = str2func(['ReturnComplexMatrixSingleGpuCidx',obj.CompCap]);
            [Error] = func(GpuNum,obj.HTempMatrix(1,:),ImageMatrix,ChanNum);
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end   

%==================================================================
% RcvrWgtBaseHoldImage
%==================================================================         
        function RcvrWgtBaseHoldImage(obj,GpuNum,GpuChanNum)
            if GpuNum > obj.NumGpuUsed-1
                error('Specified ''GpuNum'' beyond number of GPUs used');
            end
            if GpuChanNum > obj.ChanPerGpu
                error('Specified ''GpuChanNum'' beyond number of GPU channels used');
            end
            GpuNum = uint64(GpuNum);
            func = str2func(['RcvrWgtBaseImageSingleGpu',obj.CompCap]);
            [Error] = func(GpuNum,obj.HBaseImageMatrix(1,:),obj.HRcvrProfMatrix(GpuChanNum,:),obj.HBaseHoldImageMatrix(1,:),obj.BaseImageMatrixMemDims);  
            if not(strcmp(Error,'no error'))
                error(Error);
            end
        end         
        
%% TakeDown         
        
%==================================================================
% FreeBaseHoldImageMatricesGpuMem
%==================================================================                      
        function FreeBaseHoldImageMatricesGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HBaseHoldImageMatrix(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HBaseHoldImageMatrix = [];
        end         

%==================================================================
% FreeOffResMapGpuMem
%==================================================================                      
        function FreeOffResMapGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HOffResMap(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HOffResMap = [];
        end         
        
%==================================================================
% FreeOffResTimeArrGpuMem
%==================================================================                      
        function FreeOffResTimeArrGpuMem(obj)
            func = str2func(['FreeAllGpuMem',obj.CompCap]);
            [Error] = func(obj.NumGpuUsed,obj.HOffResTimeArr(1,:));
            if not(strcmp(Error,'no error'))
                error(Error);
            end
            obj.HOffResTimeArr = [];
        end 
        
        
    end
end

        