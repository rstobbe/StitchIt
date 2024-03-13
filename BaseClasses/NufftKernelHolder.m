 %==================================================================
% 
%==================================================================

classdef NufftKernelHolder < handle

properties (SetAccess = private)                   
    StitchSupportingPath = []
    KernelFile = 'KBCw2b5p5ss1p6'
    Kernel
    InvFiltFile
    InvFilt
    Fov2Return = 'BaseMatrix'
    BaseMatrix
    GridMatrix
    Gpus2Use
    RxChannels
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function obj = NufftKernelHolder             
end

%==================================================================
% SetStitchSupportingPath
%==================================================================         
        function SetStitchSupportingPath(obj,val)
            obj.StitchSupportingPath = val;
        end  

%==================================================================
% SetKernelFile
%==================================================================   
        function SetKernelFile(obj,val)
            obj.KernelFile = val;
        end          

%==================================================================
% SetReducedSubSamp
%==================================================================         
        function SetReducedSubSamp(obj)                  
            obj.SetSubSample(1.25);
        end         
        
%==================================================================
% SetSubSample
%==================================================================          
        function SetSubSample(obj,val)
            if val == 1.25
                obj.KernHolder.SetKernelFile('KBCw5b11ss1p25');  
            elseif val == 1.6
                obj.KernHolder.SetKernelFile('KBCw2b5p5ss1p6');             % this is the default
            end
        end               
        
%==================================================================
% SetInvFiltFile
%==================================================================   
        function SetInvFiltFile(obj,val)
            obj.InvFiltFile = val;
            load([obj.StitchSupportingPath,'InverseFilters',filesep,'IF_',obj.InvFiltFile,'.mat']);              
            obj.InvFilt = saveData.IFprms;
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
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,AcqInfo,RxChannels)   
            
            %------------------------------------------------------
            % RxChannels
            %------------------------------------------------------
            obj.RxChannels = RxChannels;
            
            %------------------------------------------------------
            % Gpus
            %------------------------------------------------------
            GpuTot = gpuDeviceCount;
            if isempty(obj.Gpus2Use)
                if RxChannels == 1
                    obj.Gpus2Use = 1;
                else
                    obj.Gpus2Use = GpuTot;
                end
            end
            if obj.Gpus2Use > GpuTot
                error('More Gpus than available have been specified');
            end
            
            %------------------------------------------------------
            % Load Kernel
            %------------------------------------------------------
            if isempty(obj.StitchSupportingPath)
                loc = mfilename('fullpath');
                ind = strfind(loc,'obj');
                obj.StitchSupportingPath = [loc(1:ind-1),'StitchSupporting',filesep]; 
            end
            load([obj.StitchSupportingPath,'Kernels',filesep,'Kern_',obj.KernelFile,'.mat']);
            obj.Kernel = saveData.KRNprms;

            %------------------------------------------------------
            % Test/Load InvFilt
            %------------------------------------------------------            
            Matrix = AcqInfo.Fov/AcqInfo.Vox;
            SubSamp = obj.Kernel.DesforSS;
            SubSampMatrix = SubSamp * Matrix + 4;
            PossibleZeroFill = obj.Kernel.PossibleZeroFill;
            if ~isempty(obj.BaseMatrix)
                obj.GridMatrix = obj.BaseMatrix*SubSamp;
            end
            if isempty(obj.GridMatrix)
                ind = find(PossibleZeroFill > SubSampMatrix,1,'first');
                obj.GridMatrix = PossibleZeroFill(ind);
            end
            if obj.GridMatrix < SubSampMatrix
                error(['Specified BaseMatrix is too small. Min: ',num2str(10*ceil((SubSampMatrix/SubSamp)/10))]);
            end
            if isempty(obj.InvFiltFile)
                if obj.TestFov2ReturnGridMatrix
                    obj.InvFiltFile = [obj.KernelFile,'zf',num2str(obj.GridMatrix),'S'];
                else
                    obj.InvFiltFile = [obj.KernelFile,'zf',num2str(obj.GridMatrix),'SB'];
                end
                load([obj.StitchSupportingPath,'InverseFilters',filesep,'IF_',obj.InvFiltFile,'.mat']);              
                obj.InvFilt = saveData.IFprms;
            end
            obj.BaseMatrix = obj.GridMatrix/SubSamp;
        end            
    end
end