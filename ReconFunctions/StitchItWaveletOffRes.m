%================================================================
% StitchIt
%   
%================================================================

classdef StitchItWaveletOffRes < handle

    properties (SetAccess = private)                                     
        StitchSupportingPath
        AcqInfo
        KernHolder
        GridMatrix
        BaseMatrix
        Gpus2Use
        RxChannels
        Fov2Return = 'BaseMatrix'
        LevelsPerDim = [1 1 1]
        NumIterations = 50
        MaxEig
        Lambda
        ItNum
        Nufft
        DisplayResult = 0
        DisplayIterationStep = 1
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItWaveletOffRes()
            obj.KernHolder = NufftKernelHolder();
        end       

%==================================================================
% Setup
%==================================================================   
        function Initialize(obj,AcqInfo,RxChannels) 
            DisplayStatusCompass('Initialize',3);
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
            sz = size(AcqInfo.ReconInfoMat);
            if ~strcmp(AcqInfo.DataDims,'Pt2Pt') || sz(1)~=4
                error('YB_ file not specified properly - probably old version');
            end
        end    
        
%==================================================================
% CreateImage
%==================================================================         
        function Image = CreateImage(obj,Data,RxProfs,OffResMap,OffResTimeArr,Image0)          
            DisplayStatusCompass('Create Iterative Image',3);            
            ReconInfoMat = obj.AcqInfo.ReconInfoMat;
            ReconInfoMat(4,:,:) = 1;                            % set sampling density compensation to '1'. 
            obj.AcqInfo.SetReconInfoMat(ReconInfoMat); 
            obj.Nufft = NufftOffResIterate();
            obj.Nufft.Initialize(obj,obj.KernHolder,obj.AcqInfo,obj.RxChannels,RxProfs,OffResMap,OffResTimeArr);
            isDec = 0;                                          % Non-decimated to avoid blocky edges
            Wave = dwt(obj.LevelsPerDim,size(Image0),isDec);  
            Func = @(x,transp) obj.IterateFunc(x,transp);
            Opt = [];
            Opt.maxEig = obj.MaxEig;
            obj.ItNum = 1;
            %--
            %[Image,resSqAll,RxAll,mseAll] = bfista(Func,Data,Wave,obj.Lambda,Image0,obj.NumIterations,Opt);
            Image = bfista_rws(Func,Data,Wave,obj.Lambda,Image0,obj.NumIterations,Opt,obj);
            %Image = bfista(Func,Data,Wave,obj.Lambda,Image0,obj.NumIterations,Opt);
            %--
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
            DisplayStatusCompass(['Compressed Sensing ' num2str(obj.ItNum)],3); 
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
% SetMaxEig
%==================================================================   
        function SetMaxEig(obj,val)
            obj.MaxEig = val;
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
% SetDisplayResultOn
%==================================================================         
        function SetDisplayResultOn(obj)
            obj.DisplayResult = 1;
        end         

%==================================================================
% SetDisplayIterationStep
%==================================================================         
        function SetDisplayIterationStep(obj,val)
            obj.DisplayIterationStep = val;
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

%==================================================================
% IterationAnalysis
%==================================================================            
        function IterationAnalysis(obj,Image,nit) 
            if obj.DisplayResult
                if rem(nit,obj.DisplayIterationStep) == 0
                    totgblnum = ImportImageCompass(Image,['CsIt',num2str(nit)]);
                    Gbl2ImageOrtho('IM3',totgblnum);
                end
            end
        end

end
end

