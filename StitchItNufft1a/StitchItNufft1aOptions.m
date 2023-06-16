%==================================================================
% 
%==================================================================

classdef StitchItNufft1aOptions < handle

properties (SetAccess = private)                   
    StitchSupportingPath = 'D:\StitchSupportingExtended\'
    KernelFile = 'KBCw2b5p5ss1p6'
    Kernel
    InvFiltFile
    InvFilt
    ZeroFill
    BaseMatrix
    Gpus2Use
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function obj = StitchItNufft1aOptions             
end

%==================================================================
% SetStitchSupportingPath
%==================================================================         
        function SetStitchSupportingPath(obj,val)
            obj.StitchSupportingPath = val;
        end      

%==================================================================
% SetGpus2Use
%==================================================================         
        function SetGpus2Use(obj,val)
            obj.Gpus2Use = val;
        end         
        
%==================================================================
% SetKernelFile
%==================================================================   
        function SetKernelFile(obj,val)
            obj.KernelFile = val;
        end          

%==================================================================
% SetInvFiltFile
%==================================================================   
        function SetInvFiltFile(obj,val)
            obj.InvFiltFile = val;
            load([obj.StitchSupportingPath,'InverseFilters',filesep,'IF_',obj.InvFiltFile,'.mat']);              
            obj.InvFilt = saveData.IFprms;
            obj.ZeroFill = obj.InvFilt.ZF;
        end           

%==================================================================
% SetDummyInvFilt
%==================================================================   
        function SetDummyInvFilt(obj)         
            obj.InvFilt.V = ones([obj.ZeroFill,obj.ZeroFill,obj.ZeroFill],'single');
            obj.InvFiltFile = 'Dummy';
        end         
        
%==================================================================
% SetZeroFill
%==================================================================   
        function SetZeroFill(obj,val)
            obj.InvFiltFile = [];
            obj.ZeroFill = val;
        end              

%==================================================================
% SetBaseMatrix
%==================================================================   
        function SetBaseMatrix(obj,val)
            obj.InvFiltFile = [];
            obj.BaseMatrix = val;
        end           
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,AcqInfo)   
            
            %------------------------------------------------------
            % Load Kernel
            %------------------------------------------------------
            if isempty(obj.StitchSupportingPath)
                loc = mfilename('fullpath');
                ind = strfind(loc,'Base');
                obj.StitchSupportingPath = [loc(1:ind+4),'Supporting',filesep]; 
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
                obj.ZeroFill = obj.BaseMatrix*SubSamp;
            end
            if isempty(obj.ZeroFill)
                ind = find(PossibleZeroFill > SubSampMatrix,1,'first');
                obj.ZeroFill = PossibleZeroFill(ind);
            end
            if obj.ZeroFill < SubSampMatrix
                error(['Specified ZeroFill is too small. Min: ',num2str(round(SubSampMatrix))]);
            end
            if isempty(obj.InvFiltFile)
                obj.InvFiltFile = [obj.KernelFile,'zf',num2str(obj.ZeroFill),'S'];
                load([obj.StitchSupportingPath,'InverseFilters',filesep,'IF_',obj.InvFiltFile,'.mat']);              
                obj.InvFilt = saveData.IFprms;
            end
            obj.BaseMatrix = obj.ZeroFill/SubSamp;
            
            %------------------------------------------------------
            % Test Gpus
            %------------------------------------------------------  
            GpuTot = gpuDeviceCount;
            if isempty(obj.Gpus2Use)
                obj.Gpus2Use = GpuTot;
            end
            if obj.Gpus2Use > GpuTot
                error('More Gpus than available have been specified');
            end
        end            
    end
end