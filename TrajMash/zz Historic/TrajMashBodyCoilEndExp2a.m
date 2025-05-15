%==================================================================
% (V2a)
%   - 
%==================================================================

classdef TrajMashBodyCoilEndExp2a < handle

properties (SetAccess = private)                   
    Method = 'TrajMashBodyCoilEndExp2a'
    % Selectable
    StartSkip = 2000            % Trajectories to skip (steady-state)
    DispFigs = 1                % 0 = no figures; 1 = basic; 2 = verbose
    AtExpirationFrac = 0.25     % The 'fraction of the respiration cycle' included as expiration  
    PeakFindSensitivity = 5
    UseCoil = 1
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
function TrajMashObj = TrajMashBodyCoilEndExp2a()              
    TrajMashObj.DispStatObj = DisplayStatusObject();
end

%==================================================================
% CreateNavigatorWaveform
%==================================================================  
function CreateNavigatorWaveform(TrajMashObj,k0,DataObj,ReconObj)
    
    %------------------------------------------------
    % Info
    %------------------------------------------------
    TrajMashObj.NumTraj = ReconObj.NumTraj;
    TrajMashObj.NumAverages = ReconObj.NumAverages;
    TrajMashObj.NumAcqs = TrajMashObj.NumTraj*TrajMashObj.NumAverages;
    TrajMashObj.TrajLocAllAcq = single(ReconObj.TrajLocAllAcq);
    TrajMashObj.TR = DataObj.DataInfo.ExpPars.Sequence.tr;
    TrajMashObj.k0 = abs(k0(:,TrajMashObj.UseCoil));

    %------------------------------------------------
    % Test
    %------------------------------------------------
    if length(k0) ~= TrajMashObj.NumAcqs
        error('array length does not match metadata info');
    end
    
    %------------------------------------------------
    % Starting Figure
    %------------------------------------------------
    if TrajMashObj.DispFigs > 1
        figure(1001); hold on; 
        plot(TrajMashObj.StartSkip:length(k0),TrajMashObj.k0(TrajMashObj.StartSkip:end,1)); 
        title('Centre of k-Space Data')
    end
    
    %------------------------------------------------
    % Initial Navigator
    %------------------------------------------------
    TrajMashObj.FilterTime = 1000;          % starting filter time
    TrajMashObj.Filter;
    TrajMashObj.PeakFinder;
    if TrajMashObj.DispFigs > 1
        TrajMashObj.PlotNavigator(10001);
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
        TrajMashObj.PlotNavigator(2001);
        title('Navigator');
    end  

    %------------------------------------------------
    % Determine Weightings
    %------------------------------------------------    
    TrajMashObj.DetermineTraj2Use;
    if TrajMashObj.DispFigs > 0
        TrajMashObj.PlotUsedTrajs(2001);
        title('Navigator + UsedTrajs');
    end
    TrajMashObj.WeightTrajectories;
    if TrajMashObj.DispFigs > 1
        figure(3001); hold on; 
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
    TrajMashObj.NavSig = abs(smooth(TrajMashObj.k0,TrajMashObj.FilterSpan,'lowess'));
    TrajMashObj.NavSig(1:TrajMashObj.StartSkip-1) = 0;
    TrajMashObj.NavSig = single(TrajMashObj.NavSig);
end

%==================================================================
% PeakFinder
%================================================================== 
function PeakFinder(TrajMashObj)
    if TrajMashObj.PeakFindSensitivity == 1
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/100;
    elseif TrajMashObj.PeakFindSensitivity == 2 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/140;
    elseif TrajMashObj.PeakFindSensitivity == 3 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/200;
    elseif TrajMashObj.PeakFindSensitivity == 4 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/280;
    elseif TrajMashObj.PeakFindSensitivity == 5 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/400;
    end
    TrajMashObj.Peaks = peakfinder(TrajMashObj.NavSig,Sel);
    if TrajMashObj.Peaks(1) < TrajMashObj.StartSkip
        TrajMashObj.Peaks = TrajMashObj.Peaks(2:end);
    end
end

%==================================================================
% DetermineTraj2Use
%==================================================================  
function DetermineTraj2Use(TrajMashObj)
    PeaksDiff = diff(TrajMashObj.Peaks);
    RespPts = median(PeaksDiff);

    %------------------------------------------------
    % Determine RiseFall Duration
    %------------------------------------------------
    TrajMashObj.RiseFallDur = 2500;
    while true
        RiseFallRespPts = round(TrajMashObj.RiseFallDur/TrajMashObj.TR);
        TrajMashObj.ExpInds = zeros(TrajMashObj.NumAcqs,1);
        for n = 2:length(TrajMashObj.Peaks)
            TrajMashObj.ExpInds(TrajMashObj.Peaks(n-1)+RiseFallRespPts:TrajMashObj.Peaks(n)-RiseFallRespPts) = 1;
        end
        TrajUsedFrac = sum(TrajMashObj.ExpInds)/TrajMashObj.NumAcqs;
        if TrajUsedFrac > TrajMashObj.AtExpirationFrac
            break
        end
        TrajMashObj.RiseFallDur = TrajMashObj.RiseFallDur - 25;
    end
    RiseFallRespPts = round(TrajMashObj.RiseFallDur/TrajMashObj.TR);
    PeriRiseFallRespPts = round(RiseFallRespPts/1.5);

    %------------------------------------------------
    % Determine location of end expiration
    %------------------------------------------------
    ShiftPctArr = -0.3:0.001:0.3;
    for n = 2:length(TrajMashObj.Peaks)
        for m = 1:length(ShiftPctArr)
            Shift(m) = round(RespPts * ShiftPctArr(m));
            TrajMashObj.ExpInds = zeros(TrajMashObj.NumAcqs,1);
            TrajMashObj.ExpInds(Shift(m)+(TrajMashObj.Peaks(n-1)+RiseFallRespPts:TrajMashObj.Peaks(n)-RiseFallRespPts)) = 1;
            Test(m) = sum(TrajMashObj.NavSig(logical(TrajMashObj.ExpInds)));
        end
        if Test(m) == 0
            TrajMashObj.ShiftPct(n) = 0;
        else
            ind = find(Test == min(Test),1);
            TrajMashObj.ShiftPct(n) = ShiftPctArr(ind);
        end
    end

    %------------------------------------------------
    % Determine optimum peri-expiration
    %------------------------------------------------
    ShiftPctArr = -0.3:0.001:0.3;
    for n = 2:length(TrajMashObj.Peaks)
        for m = 1:length(ShiftPctArr)
            PeriShift(m) = round(RespPts * ShiftPctArr(m));
            Shift = round(RespPts * TrajMashObj.ShiftPct(n));
            TrajMashObj.PeriExpInds = zeros(TrajMashObj.NumAcqs,1);
            TrajMashObj.PeriExpInds(PeriShift(m)+TrajMashObj.Peaks(n-1)+PeriRiseFallRespPts:Shift+TrajMashObj.Peaks(n-1)+RiseFallRespPts-1) = 1;
            TrajMashObj.PeriExpInds(Shift+TrajMashObj.Peaks(n)-RiseFallRespPts+1:PeriShift(m)+TrajMashObj.Peaks(n)-PeriRiseFallRespPts) = 1;
            if length(TrajMashObj.PeriExpInds) > TrajMashObj.NumAcqs
                TrajMashObj.PeriExpInds = TrajMashObj.PeriExpInds(1:TrajMashObj.NumAcqs);
            end
            Test(m) = sum(TrajMashObj.NavSig(logical(TrajMashObj.PeriExpInds)));
        end
        if Test(m) == 0
            TrajMashObj.PeriShiftPct(n) = 0;
        else
            ind = find(Test == min(Test),1);
            TrajMashObj.PeriShiftPct(n) = ShiftPctArr(ind);
        end
    end

    TrajMashObj.ExpInds = zeros(TrajMashObj.NumAcqs,1);
    TrajMashObj.PeriExpInds = zeros(TrajMashObj.NumAcqs,1);
    for n = 2:length(TrajMashObj.Peaks)
        Shift = round(RespPts * TrajMashObj.ShiftPct(n));
        TrajMashObj.ExpInds(Shift+(TrajMashObj.Peaks(n-1)+RiseFallRespPts:TrajMashObj.Peaks(n)-RiseFallRespPts)) = 1;
        PeriShift = round(RespPts * TrajMashObj.PeriShiftPct(n));
        TrajMashObj.PeriExpInds(PeriShift+TrajMashObj.Peaks(n-1)+PeriRiseFallRespPts:Shift+TrajMashObj.Peaks(n-1)+RiseFallRespPts-1) = 1;
        TrajMashObj.PeriExpInds(Shift+TrajMashObj.Peaks(n)-RiseFallRespPts+1:PeriShift+TrajMashObj.Peaks(n)-PeriRiseFallRespPts) = 1;
        if length(TrajMashObj.PeriExpInds) > TrajMashObj.NumAcqs
            TrajMashObj.PeriExpInds = TrajMashObj.PeriExpInds(1:TrajMashObj.NumAcqs);
        end
    end
    TrajMashObj.AtExpirationFrac = sum(TrajMashObj.ExpInds)/TrajMashObj.NumAcqs;
    TrajMashObj.AtExpirationPeriFrac = sum(TrajMashObj.PeriExpInds)/TrajMashObj.NumAcqs;
end

%==================================================================
% WeightTrajectories
%==================================================================  
function WeightTrajectories(TrajMashObj)
    Holes = 0;
    PeriVals = 0;
    for n = 1:TrajMashObj.NumTraj
        % -- TestTraj1
        % if n == 1                                             
        %     figure(2001); hold on; 
        %     plot(TrajMashObj.TrajLocAllAcq(n,:),TrajMashObj.NavSig(TrajMashObj.TrajLocAllAcq(n,:)),'k*');
        % end
        % --
        Weight(n,:) = TrajMashObj.ExpInds(TrajMashObj.TrajLocAllAcq(n,:));
        SumWeight(n) = sum(Weight(n,:),2);
        if SumWeight(n) == 0
            PeriVals = PeriVals + 1;
            Weight(n,:) = TrajMashObj.PeriExpInds(TrajMashObj.TrajLocAllAcq(n,:));
            SumWeight(n) = sum(Weight(n,:),2);
        end
        if SumWeight(n) == 0
            Holes = Holes + 1;
            Weight(n,:) = ones(1,TrajMashObj.NumAverages);
            SumWeight(n) = sum(Weight(n,:),2);
        end
        NormWeight(n,:) = Weight(n,:)/SumWeight(n);
    end
    TrajMashObj.SumWeightOut = SumWeight;
    TrajMashObj.PeriValsFraction = PeriVals/TrajMashObj.NumTraj;
    TrajMashObj.HoleFraction = Holes/TrajMashObj.NumTraj;
    TrajMashObj.MeanTrajsUsed = mean(SumWeight);
    TrajMashObj.WeightArr = single(NormWeight);
    TrajMashObj.NumImages = 1;
end

%==================================================================
% PlotNavigator
%================================================================== 
function PlotNavigator(TrajMashObj,FigureNumber)
    figure(FigureNumber); hold on; 
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
    plot(AcqsArr(logical(TrajMashObj.ExpInds)),TrajMashObj.NavSig(logical(TrajMashObj.ExpInds)),'r*')
    plot(AcqsArr(logical(TrajMashObj.PeriExpInds)),TrajMashObj.NavSig(logical(TrajMashObj.PeriExpInds)),'g*')
    title('Navigator');
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


end
end