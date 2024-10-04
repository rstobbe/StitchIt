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
    DataDims 
    DataOrder
    Reordered = 0
    OffResGridArr
    OffResTimeArr
    OffResGridBlockSize
    OffResLastGridBlockSize
    TrajsInSet
    Type                        % 1 = scan / 2 = offresmap
    NumAverages = 1
    TrajLocInAve
    TrajLocAllAcq
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
function SetDataDimsTraj2Traj(STCH)     
    STCH.DataDims = 'Traj2Traj';
end
function SetDataDimsPt2Pt(STCH)
    STCH.DataDims = 'Pt2Pt';
end
function SetDataOrder(STCH,DataOrder)     
    STCH.DataOrder = DataOrder;
end
function SetReordered(STCH)     
    STCH.Reordered = 1;
end
function SetOffResGridArr(STCH,val)     
    STCH.OffResGridArr = single(val);
end
function SetOffResTimeArr(STCH,val)     
    STCH.OffResTimeArr = single(val);
end
function SetOffResGridBlockSize(STCH,val)     
    STCH.OffResGridBlockSize = single(val);
end
function SetOffResLastGridBlockSize(STCH,val)     
    STCH.OffResLastGridBlockSize = single(val);
end
function SetTrajsInSet(STCH,val)     
    STCH.TrajsInSet = val;
end
function SetTypeOffResMap(STCH)     
    STCH.Type = 2;
end
function SetNumAverages(STCH,val)     
    STCH.NumAverages = val;
end
function SetTrajLocInAve(STCH,val)     
    STCH.TrajLocInAve = val;
end
function SetTrajLocAllAcq(STCH,val)     
    STCH.TrajLocAllAcq = val;
end

end
end