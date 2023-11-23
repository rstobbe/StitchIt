%================================================================
% StitchIt
%   
%================================================================

classdef StitchItWaveletInputRxProf < handle

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
        LevelsPerDim = [1 1 1]
        NumIterations = 50
        Lambda
        ItNum
        Nufft
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItWaveletInputRxProf()
            obj.KernHolder = NufftKernelHolder();
        end       

%==================================================================
% Setup
%==================================================================   
        function Initialize(obj,AcqInfo,RxChannels) 
            DisplayStatusCompass('Initialize',3);
            obj.AcqInfo = AcqInfo;
            obj.KernHolder.Initialize(obj.AcqInfo,obj);
            obj.RxChannels = RxChannels;
            GpuTot = gpuDeviceCount;
            if isempty(obj.Gpus2Use)
                obj.Gpus2Use = GpuTot;
            end
            if obj.Gpus2Use > GpuTot
                error('More Gpus than available have been specified');
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
        end    
        
%==================================================================
% CreateImage
%==================================================================         
        function Image = CreateImage(obj,Data,RxProfs)
            DisplayStatusCompass('Create Estimation Image',3);
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
            NufftInv = NufftReturnChannels();
            NufftInv.Initialize(obj,obj.KernHolder,obj.AcqInfo,obj.RxChannels);
            Images = NufftInv.Inverse(obj,Data);
            Image0 = sum(Images.*conj(RxProfs),4);
            clear Images;
            clear NufftInv;
            
            DisplayStatusCompass('Create Iterative Image',3);            
            ReconInfoMat = obj.AcqInfo.ReconInfoMat;
            ReconInfoMat(:,:,4) = 1;                            % set sampling density compensation to '1'. 
            obj.AcqInfo.SetReconInfoMat(ReconInfoMat); 
            obj.Nufft = NufftIterate();
            obj.Nufft.Initialize(obj,obj.KernHolder,obj.AcqInfo,obj.RxChannels,RxProfs);
            isDec = 0;                                          % Non-decimated to avoid blocky edges
            Wave = dwt(obj.LevelsPerDim,size(Image0),isDec);  
            Func = @(x,transp) obj.IterateFunc(x,transp);
            Opt = [];
            obj.ItNum = 1;
            %[Image,resSqAll,RxAll,mseAll] = bfista(Func,Data,Wave,obj.Lambda,Image0,obj.NumIterations,Opt);
            Image = bfista(Func,Data,Wave,obj.Lambda,Image0,obj.NumIterations,Opt);
            clear Nufft
            DisplayClearStatusCompass();
        end

%==================================================================
% IterateFunc
%==================================================================           
        function Out = IterateFunc(obj,In,Transp)
            switch Transp
                case 'notransp'
                    Out = obj.Nufft.Forward(In);
                case 'transp'
                    Out = obj.Nufft.Inverse(In); 
                    obj.DisplayCount;
            end   
        end           

%==================================================================
% DisplayCount
%==================================================================           
        function DisplayCount(obj) 
            DisplayStatusCompass(['Create Iterative Image' num2str(obj.ItNum)],3); 
            obj.ItNum = obj.ItNum + 1;
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
% SetLevelsPerDim
%==================================================================   
        function SetLevelsPerDim(obj,val)
            obj.LevelsPerDim = val;
        end         
 
%==================================================================
% SetNumIterations
%==================================================================         
        function SetNumIterations(obj,val)
            obj.NumIterations = val;
        end        

%==================================================================
% SetLambda
%==================================================================         
        function SetLambda(obj,val)
            obj.Lambda = val;
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


