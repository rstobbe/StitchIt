%================================================================
% StitchIt
%   
%================================================================

classdef StitchItReturnRxProfs < handle

    properties (SetAccess = private)                                     
        StitchSupportingPath
        AcqInfo
        KernHolder
        GridMatrix
        BaseMatrix
        Gpus2Use
        RxChannels
        Fov2Return = 'BaseMatrix'
        BeneficiallyOrderDataForGpu = 1
        UnallocateRamOnFinish = 0
        DataDims
        Nufft
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItReturnRxProfs()
            obj.KernHolder = NufftKernelHolder();
        end       

%==================================================================
% Setup
%==================================================================   
        function Initialize(obj,AcqInfo,RxChannels) 
            obj.AcqInfo = AcqInfo;
            obj.KernHolder.Initialize(AcqInfo,obj);
            obj.RxChannels = RxChannels;
            GpuTot = gpuDeviceCount;
            if isempty(obj.Gpus2Use)
                if obj.RxChannels == 1
                    obj.Gpus2Use = 1;
                else
                    obj.Gpus2Use = GpuTot;
                end
            end
            if obj.Gpus2Use > GpuTot
                error('More Gpus than available have been specified');
            end
            if isempty(AcqInfo.DataDims)
                obj.DataDims = 'Traj2Traj';
            else
            	obj.DataDims = AcqInfo.DataDims;
            end
            if isempty(AcqInfo.DataOrder)
                obj.BeneficiallyOrderDataForGpu = 0;
            end
            if obj.BeneficiallyOrderDataForGpu
                if not(AcqInfo.Reordered)
                    sz = size(AcqInfo.ReconInfoMat);
                    ReconInfoMatArr = reshape(AcqInfo.ReconInfoMat,sz(1)*sz(2),4);
                    ReconInfoMatArr = ReconInfoMatArr(AcqInfo.DataOrder,:);
                    ReconInfoMat = reshape(ReconInfoMatArr,sz(1),sz(2),4);
                    AcqInfo.SetReconInfoMat(ReconInfoMat);
                    AcqInfo.SetReordered;
                end
            end
            obj.Nufft = NufftReturnChannels();
            obj.Nufft.SetDoMemRegister(~obj.UnallocateRamOnFinish);
            obj.Nufft.Initialize(obj,obj.KernHolder,obj.AcqInfo,obj.RxChannels);
        end    

%==================================================================
% SetUnallocateRamOnFinish
%==================================================================         
        function SetUnallocateRamOnFinish(obj,val)                  
            obj.UnallocateRamOnFinish = val;
        end              
        
%==================================================================
% CreateImage
%==================================================================         
        function RxProfs = CreateImage(obj,Data) 
            if strcmp(obj.DataDims,'Traj2Traj')
                Data = Data(1:obj.AcqInfo.NumCol,:,:);
            elseif strcmp(obj.DataDims,'Pt2Pt')
                Data = Data(:,1:obj.AcqInfo.NumCol,:);
            end
            if obj.BeneficiallyOrderDataForGpu
                sz = size(Data);
                if length(sz) == 2
                    sz(3) = 1;
                end
                if obj.BeneficiallyOrderDataForGpu
                    DataArr = reshape(Data,sz(1)*sz(2),sz(3));
                    DataArrReorder = DataArr(obj.AcqInfo.DataOrder,:);
                    Data = reshape(DataArrReorder,sz(1),sz(2),sz(3));
                end
            end
            LowResImages = obj.Nufft.Inverse(obj,Data);
            LowResSos = sum(abs(LowResImages).^2,4);
            RxProfs = LowResImages./sqrt(LowResSos);
        end

%==================================================================
% SetStitchSupportingPath
%==================================================================         
        function SetStitchSupportingPath(obj,val)
            obj.StitchSupportingPath = val;
        end
        
%==================================================================
% SetDoMemRegister
%==================================================================           
        function SetDoMemRegister(obj,val)
            obj.DoMemRegister = val;
        end        
        
%==================================================================
% SetAcqInfo
%==================================================================         
        function SetAcqInfo(obj,val)
            obj.AcqInfo = val;
        end               
        
%==================================================================
% SetGpus2Use
%==================================================================         
        function SetGpus2Use(obj,val)
            obj.Gpus2Use = val;
        end
        
%==================================================================
% SetGridMatrix
%==================================================================   
        function SetGridMatrix(obj,val)
            obj.GridMatrix = val;
        end              

%==================================================================
% SetBaseMatrix
%==================================================================   
        function SetBaseMatrix(obj,val)
            obj.BaseMatrix = val;
        end           
                
%==================================================================
% SetFov2ReturnBaseMatrix
%==================================================================         
        function SetFov2ReturnBaseMatrix(obj)
            obj.Fov2Return = 'BaseMatrix';
        end          

%==================================================================
% SetFov2ReturnGridMatrix
%==================================================================         
        function SetFov2ReturnGridMatrix(obj)
            obj.Fov2Return = 'GridMatrix';
        end          

%==================================================================
% TestFov2ReturnGridMatrix
%==================================================================         
        function bool = TestFov2ReturnGridMatrix(obj)
            bool = 0;
            if strcmp(obj.Fov2Return,'GridMatrix')
                bool = 1;
            end
        end            
                     

        
    end
end


