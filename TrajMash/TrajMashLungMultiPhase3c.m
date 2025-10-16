%==================================================================
% (3c)
%   - Info set using functions
%==================================================================

classdef TrajMashLungMultiPhase3c < matlab.mixin.Copyable

properties (SetAccess = private)                   
    Method = 'TrajMashLungMultiPhase3c'
    % Selectable
    StartSkip = 2000            % Trajectories to skip (steady-state)
    DispFigs = 1                % 0 = no figures; 1 = basic; 2 = verbose
    PeakFindSensitivity = 5
    AcceptanceLevel = 1
    Flip = 0
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
    NumPeaks
    ExpInds
    PeriExpInds
    SumWeightOut
    ShiftPct
    PeriShiftPct
    RiseFallDur
    FilterTime
    Phases
    TrajMashNum
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function TrajMashObj = TrajMashLungMultiPhase3c()              
    TrajMashObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateNavigatorWaveform
%==================================================================  
function CreateNavigatorWaveform(TrajMashObj,k0)
    
    %------------------------------------------------
    % Info
    %------------------------------------------------
    TrajMashObj.NumCoils = size(k0,2);

    %------------------------------------------------
    % Test
    %------------------------------------------------
    if length(k0) ~= TrajMashObj.NumAcqs
        error('array length does not match metadata info');
    end

    %------------------------------------------------
    % Start
    %------------------------------------------------
    TrajMashObj.k0 = abs(k0);

    %------------------------------------------------
    % Starting Figure
    %------------------------------------------------
    if TrajMashObj.DispFigs > 1
        figure(1000 + TrajMashObj.TrajMashNum); clf; hold on; 
        plot(TrajMashObj.StartSkip:length(k0),TrajMashObj.k0(TrajMashObj.StartSkip:end,:)); 
        title('Centre of k-Space Data')
    end
    
    %------------------------------------------------
    % Initial Navigator
    %------------------------------------------------
    TrajMashObj.FilterTime = 1000;          % starting filter time
    TrajMashObj.Filter;
    TrajMashObj.PeakFinder;
    if TrajMashObj.DispFigs > 1
        TrajMashObj.PlotNavigator(2000 + TrajMashObj.TrajMashNum);
        title('Starting Navigator');
    end

    %------------------------------------------------
    % Update Filter - Redo Navigator
    %------------------------------------------------
    PeaksDiff = diff(TrajMashObj.Peaks);
    TrajMashObj.MedianPeaksDiff = median(PeaksDiff);
    TrajMashObj.FilterTime = TrajMashObj.MedianPeaksDiff*TrajMashObj.TR/2;
    TrajMashObj.Filter;
    TrajMashObj.PeakFinder;
    if TrajMashObj.DispFigs > 0
        TrajMashObj.PlotNavigator(3000 + TrajMashObj.TrajMashNum);
        title('Navigator');
    end  

    %------------------------------------------------
    % Determine Weightings
    %------------------------------------------------    
    TrajMashObj.DetermineTraj2Use;
    if TrajMashObj.DispFigs > 0
        TrajMashObj.PlotUsedTrajs(3000 + TrajMashObj.TrajMashNum);
        title('Navigator + UsedTrajs');
    end
    TrajMashObj.WeightTrajectories;
    if TrajMashObj.DispFigs > 1
        figure(3000 + TrajMashObj.TrajMashNum); clf; hold on; 
        plot(TrajMashObj.SumWeightOut);
        ylim([0 TrajMashObj.NumAverages]);
        title('Averages Used Per Trajectory')
    end
    %TestTraj1 = TrajMashObj.WeightArr(1,:)
end

%==================================================================
% Filter
%================================================================== 
function Filter(TrajMashObj)
    TrajMashObj.FilterSpan = round(TrajMashObj.FilterTime/TrajMashObj.TR);
    TrajMashObj.NavSig = zeros(size(TrajMashObj.k0));
    for n = 1:TrajMashObj.NumCoils
        TrajMashObj.NavSig(:,n) = abs(smooth(TrajMashObj.k0(:,n),TrajMashObj.FilterSpan,'lowess'));
        TrajMashObj.NavSig(1:TrajMashObj.StartSkip-1,n) = 0;
    end
    PcaNavSig = pca(TrajMashObj.NavSig.');
    TrajMashObj.NavSig = single(PcaNavSig(:,1));
    if TrajMashObj.Flip
        TrajMashObj.NavSig = max(TrajMashObj.NavSig)*10 - TrajMashObj.NavSig;
    end
end

%==================================================================
% PeakFinder
%================================================================== 
function PeakFinder(TrajMashObj)
    UsedNavSig = TrajMashObj.NavSig(TrajMashObj.StartSkip:end);
    if TrajMashObj.PeakFindSensitivity == 1
        Sel = (max(UsedNavSig)-min(UsedNavSig))/3.5;
    elseif TrajMashObj.PeakFindSensitivity == 2 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/5;
    elseif TrajMashObj.PeakFindSensitivity == 3 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/7;
    elseif TrajMashObj.PeakFindSensitivity == 4 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/10;
    elseif TrajMashObj.PeakFindSensitivity == 5 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/14;
    elseif TrajMashObj.PeakFindSensitivity == 6 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/20;
    elseif TrajMashObj.PeakFindSensitivity == 7 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/28;
    elseif TrajMashObj.PeakFindSensitivity == 8 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/40;
    end
    TrajMashObj.Peaks = peakfinder(TrajMashObj.NavSig,Sel);
    if TrajMashObj.Peaks(1) <= TrajMashObj.StartSkip
        TrajMashObj.Peaks = TrajMashObj.Peaks(2:end);
    end
end

%==================================================================
% DetermineTraj2Use
%==================================================================  
function DetermineTraj2Use(TrajMashObj)
    PeaksDiff = diff(TrajMashObj.Peaks);
    obj.NumPeaks = length(TrajMashObj.Peaks);

    V = TrajMashObj.AcceptanceLevel;

    TrajMashObj.ExpInds = zeros(TrajMashObj.NumAcqs,TrajMashObj.Phases);
    TrajMashObj.PeriExpInds = zeros(TrajMashObj.NumAcqs,TrajMashObj.Phases);
    for p = 1:TrajMashObj.Phases
        for n = 1:(obj.NumPeaks-1)
            TrajMashObj.ExpInds(TrajMashObj.Peaks(n) + ((round((p-1)*PeaksDiff(n)/TrajMashObj.Phases)):round(p*PeaksDiff(n)/TrajMashObj.Phases)),p) = 1;
            if p == 1
                if n == 1
                    TrajMashObj.PeriExpInds(TrajMashObj.Peaks(n) + ((round((p-1-V)*PeaksDiff(n)/TrajMashObj.Phases)):round((p-1)*PeaksDiff(n)/TrajMashObj.Phases)),p) = 1;
                else
                    TrajMashObj.PeriExpInds(TrajMashObj.Peaks(n) + ((round((p-1-V)*PeaksDiff(n-1)/TrajMashObj.Phases)):round((p-1)*PeaksDiff(n-1)/TrajMashObj.Phases)),p) = 1;
                end
            else
                TrajMashObj.PeriExpInds(TrajMashObj.Peaks(n) + ((round((p-1-V)*PeaksDiff(n)/TrajMashObj.Phases)):round((p-1)*PeaksDiff(n)/TrajMashObj.Phases)),p) = 1;
            end
            TrajMashObj.PeriExpInds(TrajMashObj.Peaks(n) + ((round(p*PeaksDiff(n)/TrajMashObj.Phases)):round((p+V)*PeaksDiff(n)/TrajMashObj.Phases)),p) = 1;
        end
    end
end

%==================================================================
% WeightTrajectories
%==================================================================  
function WeightTrajectories(TrajMashObj)
    Holes = zeros(1,TrajMashObj.Phases);
    PeriVals = zeros(1,TrajMashObj.Phases);
    for p = 1:TrajMashObj.Phases
        for n = 1:TrajMashObj.NumTraj
            Weight(n,:,p) = TrajMashObj.ExpInds(TrajMashObj.TrajLocAllAcq(n,:),p);
            SumWeight(n,p) = sum(Weight(n,:,p),2);
            if SumWeight(n,p) == 0
                PeriVals(p) = PeriVals(p) + 1;
                Weight(n,:,p) = TrajMashObj.PeriExpInds(TrajMashObj.TrajLocAllAcq(n,:),p);
                SumWeight(n,p) = sum(Weight(n,:,p),2);
            end
            if SumWeight(n,p) == 0
                Holes(p) = Holes(p) + 1;
                Weight(n,:,p) = ones(1,TrajMashObj.NumAverages);
                SumWeight(n,p) = sum(Weight(n,:,p),2);
            end
            NormWeight(n,:,p) = Weight(n,:,p)/SumWeight(n,p);
        end
    end
    TrajMashObj.SumWeightOut = SumWeight;
    TrajMashObj.PeriValsFraction = PeriVals/TrajMashObj.NumTraj;
    TrajMashObj.HoleFraction = Holes/TrajMashObj.NumTraj;
    TrajMashObj.MeanTrajsUsed = mean(SumWeight,1);
    TrajMashObj.WeightArr = single(NormWeight);
    TrajMashObj.NumImages = TrajMashObj.Phases;
end

%==================================================================
% PlotNavigator
%================================================================== 
function PlotNavigator(TrajMashObj,FigureNumber)
    figure(FigureNumber); clf; hold on; 
    plot(TrajMashObj.StartSkip:length(TrajMashObj.NavSig),TrajMashObj.NavSig(TrajMashObj.StartSkip:end));
    plot(TrajMashObj.Peaks,TrajMashObj.NavSig(TrajMashObj.Peaks),'o')
    title('Navigator');
end

%==================================================================
% PlotUsedTrajs
%================================================================== 
function PlotUsedTrajs(TrajMashObj,FigureNumber)
    figure(FigureNumber); hold on; 
    AcqsArr = 1:TrajMashObj.NumAcqs;
    plot(AcqsArr(logical(TrajMashObj.ExpInds(:,1))),TrajMashObj.NavSig(logical(TrajMashObj.ExpInds(:,1))),'r*')
    plot(AcqsArr(logical(TrajMashObj.PeriExpInds(:,1))),TrajMashObj.NavSig(logical(TrajMashObj.PeriExpInds(:,1))),'g*')
    title('Navigator');
end

%==================================================================
% DoTrajMash
%==================================================================  
function DataMash = DoTrajMash(TrajMashObj,Data,nim)
    DataMash = DoTrajMashV2(Data,TrajMashObj.WeightArr(:,:,nim),TrajMashObj.TrajLocAllAcq);
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
function SetPeakFindSensitivity(TrajMashObj,val)
    TrajMashObj.PeakFindSensitivity = val;
end
function SetFlip(TrajMashObj,val)
    TrajMashObj.Flip = val;
end
function SetPhases(TrajMashObj,val)
    TrajMashObj.Phases = val;
end
function SetAcceptanceLevel(TrajMashObj,val)
    TrajMashObj.AcceptanceLevel = val;
end
function SetNumTraj(TrajMashObj,val)
    TrajMashObj.NumTraj = val;
    TrajMashObj.NumAcqs = TrajMashObj.NumTraj*TrajMashObj.NumAverages;
end
function SetNumAverages(TrajMashObj,val)
    TrajMashObj.NumAverages = val;
    TrajMashObj.NumAcqs = TrajMashObj.NumTraj*TrajMashObj.NumAverages;
end
function SetNumAcqs(TrajMashObj,val)
    TrajMashObj.NumAcqs = val;
end
function SetTrajLocAllAcq(TrajMashObj,val)
    TrajMashObj.TrajLocAllAcq = single(val);
end
function SetTr(TrajMashObj,val)
    TrajMashObj.TR = val;
end
function SetTrajMashNum(TrajMashObj,val)
    TrajMashObj.TrajMashNum = val;
end

end
end