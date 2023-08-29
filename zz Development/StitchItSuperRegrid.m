%================================================================
% StitchIt
%   
%================================================================

classdef StitchItSuperRegrid < handle

    properties (SetAccess = private)                                     
        StitchSupportingPath
        AcqInfoRxProf
        AcqInfoImage
        KernHolder
        GridMatrix
        BaseMatrix
        Gpus2Use
        RxChannels
        Fov2Return = 'BaseMatrix'
        BeneficiallyOrderDataForGpu = 1
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItSuperRegrid()
            obj.KernHolder = NufftKernelHolder();
        end       

%==================================================================
% Setup
%==================================================================   
        function Initialize(obj,AcqInfoRxProf,AcqInfoImage,RxChannels) 
            DisplayStatusCompass('Initialize',3);
            obj.AcqInfoRxProf = AcqInfoRxProf;
            obj.AcqInfoImage = AcqInfoImage;
            obj.KernHolder.Initialize(obj.AcqInfoImage,obj);
            obj.RxChannels = RxChannels;
            GpuTot = gpuDeviceCount;
            if isempty(obj.Gpus2Use)
                obj.Gpus2Use = GpuTot;
            end
            if obj.Gpus2Use > GpuTot
                error('More Gpus than available have been specified');
            end
            if obj.BeneficiallyOrderDataForGpu
                if not(AcqInfoRxProf.Reordered)
                    sz = size(obj.AcqInfoRxProf.ReconInfoMat);
                    ReconInfoMatArr = reshape(obj.AcqInfoRxProf.ReconInfoMat,sz(1)*sz(2),4);
                    ReconInfoMatArr = ReconInfoMatArr(obj.AcqInfoRxProf.DataOrder,:);
                    ReconInfoMat = reshape(ReconInfoMatArr,sz(1),sz(2),4);
                    obj.AcqInfoRxProf.SetReconInfoMat(ReconInfoMat);
                end
                if not(AcqInfoImage.Reordered)
                    sz = size(obj.AcqInfoImage.ReconInfoMat);
                    ReconInfoMatArr = reshape(obj.AcqInfoImage.ReconInfoMat,sz(1)*sz(2),4);
                    ReconInfoMatArr = ReconInfoMatArr(obj.AcqInfoImage.DataOrder,:);
                    ReconInfoMat = reshape(ReconInfoMatArr,sz(1),sz(2),4);
                    obj.AcqInfoImage.SetReconInfoMat(ReconInfoMat);
                end
            end
        end    
        
%==================================================================
% CreateImage
%==================================================================         
        function Image = CreateImage(obj,Data)
            %% Estimate Receiver Profiles
            DisplayStatusCompass('Estimate Receiver Profiles',3);        
            DataRxProf = Data(1:obj.AcqInfoRxProf.NumCol,:,:);
            if obj.BeneficiallyOrderDataForGpu
                sz = size(DataRxProf);
                if length(sz) == 2
                    sz(3) = 1;
                end
                if obj.BeneficiallyOrderDataForGpu
                    DataArr = reshape(DataRxProf,sz(1)*sz(2),sz(3));
                    DataArrReorder = DataArr(obj.AcqInfoRxProf.DataOrder,:);
                    DataRxProf = reshape(DataArrReorder,sz(1),sz(2),sz(3));
                end
            end
            Nufft = NufftReturnChannels();
            Nufft.Initialize(obj,obj.KernHolder,obj.AcqInfoRxProf,obj.RxChannels);
            LowResImages = Nufft.Inverse(obj,DataRxProf);
            LowResSos = sum(abs(LowResImages).^2,4);
            RxProfs = LowResImages./sqrt(LowResSos);
            clear LowResImages
            clear LowResSos
            clear Nufft
            
            %% Create Image
            DisplayStatusCompass('Create Image',3); 
            if obj.BeneficiallyOrderDataForGpu
                sz = size(Data);
                if length(sz) == 2
                    sz(3) = 1;
                end
                if obj.BeneficiallyOrderDataForGpu
                    DataArr = reshape(Data,sz(1)*sz(2),sz(3));
                    DataArrReorder = DataArr(obj.AcqInfoImage.DataOrder,:);
                    Data = reshape(DataArrReorder,sz(1),sz(2),sz(3));
                end
            end 
            Nufft = NufftReturnChannels();
            Nufft.Initialize(obj,obj.KernHolder,obj.AcqInfoImage,obj.RxChannels);
            Images = Nufft.Inverse(obj,Data);
            Image = sum(Images.*conj(RxProfs),4);
        end

%==================================================================
% SetStitchSupportingPath
%==================================================================         
        function SetStitchSupportingPath(obj,val)
            obj.StitchSupportingPath = val;
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


