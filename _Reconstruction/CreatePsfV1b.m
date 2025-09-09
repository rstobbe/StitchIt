%==================================================================
% 
%  
%==================================================================

classdef CreatePsfV1b < handle

properties (SetAccess = private)                   
    Method = 'CreatePsfV1b'
    BaseMatrix
    AcqInfo
    SubSamp
    ReconNumber = 1
    ResetGpus = 1
    DispStatObj
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function ReconObj = CreatePsfV1b()              
    ReconObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateImage
%==================================================================  
function [Image,err] = CreateImage(ReconObj)         
    %% Reset GPUs
    err.flag = 0;
    if ReconObj.ResetGpus
        ReconObj.DispStatObj.Status('Reset GPUs',2);
        for n = 1:gpuDeviceCount
            gpuDevice(n);
        end
    end

    %% NufftKernel
    ReconObj.DispStatObj.Status('Load Nufft Kernel',2);
    KernHolder = NufftKernelHolder();
    if ReconObj.SubSamp == 2.0
        KernHolder.SetKernelFile('KBCw2p4b9ss2');  
    elseif ReconObj.SubSamp == 2.5
        KernHolder.SetKernelFile('KBCw2p4b12ss2p5');             % this is the default      
    elseif ReconObj.SubSamp == 3.2
        KernHolder.SetKernelFile('KBCw2p5b20ss3p2');           
    end
    KernHolder.SetBaseMatrix(ReconObj.BaseMatrix);
    KernHolder.SetFov2ReturnGridMatrix;
    RxChannels = 1;
    KernHolder.Initialize(ReconObj.AcqInfo{ReconObj.ReconNumber},RxChannels);    

    %% Create Psf
    ReconObj.DispStatObj.Status('Create Psf',2);
    StitchItPsf = StitchItNufftPsfV1b();                                          
    StitchItPsf.Initialize(KernHolder,ReconObj.AcqInfo{1}); 
    Data = ones([ReconObj.AcqInfo{1}.NumTraj,ReconObj.AcqInfo{1}.NumCol],'like',single(1+1i)); 
    Image = StitchItPsf.CreateImage(Data);
    Image = Image/max(abs(Image(:)));
end

%==================================================================
% Set
%==================================================================  
%% Set
function SetBaseMatrix(ReconObj,val)    
    ReconObj.BaseMatrix = val;
end
function SetAcqInfo(ReconObj,val)    
    ReconObj.AcqInfo = val;
end
function SetReconNumber(ReconObj,val)    
    ReconObj.ReconNumber = val;
end
function SetSubSamp(ReconObj,val)    
    ReconObj.SubSamp = val;
end



end
end