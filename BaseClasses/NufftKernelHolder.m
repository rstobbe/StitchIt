 %==================================================================
% 
%==================================================================

classdef NufftKernelHolder < handle

properties (SetAccess = private)                   
    KernelFile = 'KBCw2b5p5ss1p6'
    Kernel
    InvFiltFile
    InvFilt
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function obj = NufftKernelHolder             
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
        end                 
        
%==================================================================
% Initialize
%==================================================================   
        function Initialize(obj,AcqInfo,StitchIt)   
            
            %------------------------------------------------------
            % Load Kernel
            %------------------------------------------------------
            if isempty(StitchIt.StitchSupportingPath)
                loc = mfilename('fullpath');
                ind = strfind(loc,'StitchIt');
                StitchIt.SetStitchSupportingPath([loc(1:ind-1),'StitchSupporting',filesep]); 
            end
            load([StitchIt.StitchSupportingPath,'Kernels',filesep,'Kern_',obj.KernelFile,'.mat']);
            obj.Kernel = saveData.KRNprms;

            %------------------------------------------------------
            % Test/Load InvFilt
            %------------------------------------------------------            
            Matrix = AcqInfo.Fov/AcqInfo.Vox;
            SubSamp = obj.Kernel.DesforSS;
            SubSampMatrix = SubSamp * Matrix + 4;
            PossibleZeroFill = obj.Kernel.PossibleZeroFill;
            if ~isempty(StitchIt.BaseMatrix)
                StitchIt.SetGridMatrix(StitchIt.BaseMatrix*SubSamp);
            end
            if isempty(StitchIt.GridMatrix)
                ind = find(PossibleZeroFill > SubSampMatrix,1,'first');
                StitchIt.SetGridMatrix(PossibleZeroFill(ind));
            end
            if StitchIt.GridMatrix < SubSampMatrix
                error(['Specified GridMatrix is too small. Min: ',num2str(round(SubSampMatrix))]);
            end
            if isempty(obj.InvFiltFile)
                if StitchIt.TestFov2ReturnGridMatrix
                    obj.InvFiltFile = [obj.KernelFile,'zf',num2str(StitchIt.GridMatrix),'S'];
                else
                    obj.InvFiltFile = [obj.KernelFile,'zf',num2str(StitchIt.GridMatrix),'SB'];
                end
                load([StitchIt.StitchSupportingPath,'InverseFilters',filesep,'IF_',obj.InvFiltFile,'.mat']);              
                obj.InvFilt = saveData.IFprms;
            end
            StitchIt.SetBaseMatrix(StitchIt.GridMatrix/SubSamp);
            
        end            
    end
end