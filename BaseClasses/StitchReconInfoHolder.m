%==================================================================
% (v2a)
%   - Convert to Object
%==================================================================

classdef StitchReconInfoHolder < handle

properties (SetAccess = private)                   
    name
    kStep
    Dummies
    NumTraj
    NumCol
    SampStart
    SampStartTime
    SamplingTimeOnTrajectory
    SamplingPtAtCentre
    SampEnd
    Fov
    Vox
    kMaxRad
    ReconInfoMat
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function STCH = StitchReconInfoHolder               
end

%==================================================================
% Set
%==================================================================  
function SetName(STCH,name)     
    STCH.name = name;
end
function SetkStep(STCH,kStep)     
    STCH.kStep = kStep;
end
function SetDummies(STCH,Dummies)     
    STCH.Dummies = Dummies;
end
function SetNumTraj(STCH,NumTraj)     
    STCH.NumTraj = NumTraj;
end
function SetNumCol(STCH,NumCol)     
    STCH.NumCol = NumCol;
end
function SetSampStart(STCH,SampStart)     
    STCH.SampStart = SampStart;
end
function SetSampStartTime(STCH,SampStartTime)     
    STCH.SampStartTime = SampStartTime;
end
function SetSamplingPtAtCentre(STCH,SamplingPtAtCentre)     
    STCH.SamplingPtAtCentre = SamplingPtAtCentre;
end
function SetSamplingTimeOnTrajectory(STCH,SamplingTimeOnTrajectory)     
    STCH.SamplingTimeOnTrajectory = SamplingTimeOnTrajectory;
end
function SetSampEnd(STCH,SampEnd)     
    STCH.SampEnd = SampEnd;
end
function SetFov(STCH,Fov)     
    STCH.Fov = Fov;
end
function SetVox(STCH,Vox)     
    STCH.Vox = Vox;
end
function SetkMaxRad(STCH,kMaxRad)     
    STCH.kMaxRad = kMaxRad;
end
function SetReconInfoMat(STCH,ReconInfoMat)     
    STCH.ReconInfoMat = ReconInfoMat;
end


end
end