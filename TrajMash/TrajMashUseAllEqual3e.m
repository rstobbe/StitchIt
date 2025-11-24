%==================================================================
% (V3e)
%   - Match TrajMashLungEndExp3e
%==================================================================

classdef TrajMashUseAllEqual3e < matlab.mixin.Copyable

properties (SetAccess = private)                   
    Method = 'TrajMashUseAllEqual3e'
    % Selectable
    StartSkip = 2000            % Trajectories to skip (steady-state)
    DispFigs = 1                % 0 = no figures; 1 = basic; 2 = verbose
    AtExpirationFrac = 0.25     % The 'fraction of the respiration cycle' included as expiration  
    PeakFindSensitivity = 5
    UseCoil = 1
    Flip = 0
    FindBestCoil = 0
    % ----------
    DispStatObj
    NumTraj
    NumAverages
    NumAcqs
    NumCoils
    TrajLocAllAcq
    TR
    FilterSpan
    NavSig
    HoleFraction
    PeriValsFraction
    WeightArr
    NumImages
    MeanTrajsUsed
    MedianPeaksDiff
    k0
    Peaks
    ExpInds
    PeriExpInds
    SumWeightOut
    ShiftPct
    PeriShiftPct
    RiseFallDur
    FilterTime
    AtExpirationPeriFrac
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function TrajMashObj = TrajMashUseAllEqual3e()              
    TrajMashObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateNavigatorWaveform
%==================================================================  
function CreateNavigatorWaveform(TrajMashObj,k0)
end

%==================================================================
% WeightTrajectories
%==================================================================  
function WeightTrajectories(TrajMashObj)
    TrajMashObj.WeightArr = single(ones(TrajMashObj.NumTraj,TrajMashObj.NumAverages)/TrajMashObj.NumAverages);
    TrajMashObj.NumImages = 1;
end

%==================================================================
% DoTrajMash
%==================================================================  
function DataMash = DoTrajMash(TrajMashObj,Data,nim)
    if nim > 1
        error('This TrajMash only makes one image');
    end
    DataMash = DoTrajMashV2(Data,TrajMashObj.WeightArr,TrajMashObj.TrajLocAllAcq);
end

%==================================================================
% Set
%==================================================================  
function SetStartSkip(TrajMashObj,val)
    TrajMashObj.StartSkip = val;
end
function SetDispFigs(TrajMashObj,val)
    TrajMashObj.DispFigs = val;
end
function SetAtExpirationFrac(TrajMashObj,val)
    TrajMashObj.AtExpirationFrac = val;
end
function SetPeakFindSensitivity(TrajMashObj,val)
    TrajMashObj.PeakFindSensitivity = val;
end
function SetUseCoil(TrajMashObj,val)
    TrajMashObj.UseCoil = val;
end
function SetFlip(TrajMashObj,val)
    TrajMashObj.Flip = val;
end
function SetNumAverages(TrajMashObj,val)
    TrajMashObj.NumAverages = val;
    TrajMashObj.NumAcqs = TrajMashObj.NumTraj*TrajMashObj.NumAverages;
end
function SetNumAcqs(TrajMashObj,val)
    TrajMashObj.NumAcqs = val;
end
function SetNumTraj(TrajMashObj,val)
    TrajMashObj.NumTraj = val;
    TrajMashObj.NumAcqs = TrajMashObj.NumTraj*TrajMashObj.NumAverages;
end
function SetTrajLocAllAcq(TrajMashObj,val)
    TrajMashObj.TrajLocAllAcq = single(val);
end

end
end