%==================================================================
% (3e)
%   - same as 3d (Cps wrapper has no flip)
%==================================================================

classdef TrajMashLungEndExp3e < matlab.mixin.Copyable

properties (SetAccess = private)                   
    Method = 'TrajMashLungEndExp3e'
    % Selectable
    StartSkip = 1            % Trajectories to skip (steady-state)
    DispFigs = 1                % 0 = no figures; 1 = basic; 2 = verbose
    AtExpirationFrac = 0.25     % The 'fraction of the respiration cycle' included as expiration  
    PeakFindSensitivity = 2
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
    ExpInds
    PeriExpInds
    SumWeightOut
    ShiftPct
    PeriShiftPct
    RiseFallDur
    FilterTime
    AtExpirationPeriFrac
    TrajMashNum
    Empty
end

methods 
   
%==================================================================
% Constructor
%==================================================================  
function TrajMashObj = TrajMashLungEndExp3e()              
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
        plot(TrajMashObj.StartSkip:length(k0),TrajMashObj.k0(TrajMashObj.StartSkip:end,1)); 
        title('Centre of k-Space Data')
    end
    
    %------------------------------------------------
    % Initial Navigator
    %------------------------------------------------
    TrajMashObj.FilterTime = 1000;          % starting filter time
    TrajMashObj.Filter;
    PeakFindSensitivityInit = TrajMashObj.PeakFindSensitivity - 3;
    if PeakFindSensitivityInit < 1
        PeakFindSensitivityInit = 1;
    end
    TrajMashObj.PeakFinder(PeakFindSensitivityInit);
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
    %
    TrajMashObj.FilterTime = TrajMashObj.FilterTime*0.75;
    %
    TrajMashObj.Filter;
    TrajMashObj.PeakFinder(TrajMashObj.PeakFindSensitivity);
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
    if TrajMashObj.DispFigs > 2
        figure(4000 + TrajMashObj.TrajMashNum); clf; hold on; 
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
    DoFlip = TrajMashObj.Flip;
    PcaNavSig = pca(TrajMashObj.NavSig.');
    if size(PcaNavSig,2) == 1
        TrajMashObj.NavSig = single(PcaNavSig);
    else
        for n = 1:6
            PcaNavSig(:,n) = PcaNavSig(:,n) - mean(PcaNavSig(:,n));
            %figure(10000); subplot(2,3,n); plot(PcaNavSig(:,n));
        end
        for n = 1:6
            Test = pwelch(PcaNavSig(:,n));
            %figure(20000); subplot(2,3,n); plot(Test(6:40));
            Pxx(n) = max(Test(6:end));
        end
        ind = find(Pxx == max(Pxx));
        TrajMashObj.NavSig = single(PcaNavSig(:,ind));
    end
    if DoFlip
        TrajMashObj.NavSig = max(TrajMashObj.NavSig)*10 - TrajMashObj.NavSig;
    end
end

%==================================================================
% PeakFinder
%================================================================== 
function PeakFinder(TrajMashObj,PeakFindSensitivityVal)
    UsedNavSig = TrajMashObj.NavSig(TrajMashObj.StartSkip:end);
    if PeakFindSensitivityVal == 1
        Sel = (max(UsedNavSig)-min(UsedNavSig))/3.5;
    elseif PeakFindSensitivityVal == 2 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/5;
    elseif PeakFindSensitivityVal == 3 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/7;
    elseif PeakFindSensitivityVal == 4 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/10;
    elseif PeakFindSensitivityVal == 5 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/14;
    elseif PeakFindSensitivityVal == 6 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/20;
    elseif PeakFindSensitivityVal == 7 
        Sel = (max(UsedNavSig)-min(UsedNavSig))/28;
    elseif PeakFindSensitivityVal == 8 
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
    RespPts = median(PeaksDiff);

    %------------------------------------------------
    % Determine RiseFall Duration
    %------------------------------------------------
    TrajMashObj.RiseFallDur = 4000;
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
        Test = [];
        for m = 1:length(ShiftPctArr)
            Shift(m) = round(RespPts * ShiftPctArr(m));
            TrajMashObj.ExpInds = zeros(TrajMashObj.NumAcqs,1);
            TrajMashObj.ExpInds(Shift(m)+(TrajMashObj.Peaks(n-1)+RiseFallRespPts:TrajMashObj.Peaks(n)-RiseFallRespPts)) = 1;
            if length(TrajMashObj.ExpInds) > length(TrajMashObj.NavSig)
                TrajMashObj.ExpInds = TrajMashObj.ExpInds(1:length(TrajMashObj.NavSig));
                Test(m) = 1e9;
                break
            end
            Test(m) = sum(TrajMashObj.NavSig(logical(TrajMashObj.ExpInds)));
        end
        if sum(Test) == 0
            TrajMashObj.ShiftPct(n) = 0;
            TrajMashObj.Empty(n) = 1;
        else
            ind = find(Test == min(Test),1);
            TrajMashObj.ShiftPct(n) = ShiftPctArr(ind);
            TrajMashObj.Empty(n) = 0;
        end
    end

    %------------------------------------------------
    % Determine optimum peri-expiration
    %------------------------------------------------
    ShiftPctArr = -0.3:0.001:0.3;
    for n = 2:length(TrajMashObj.Peaks)
        if TrajMashObj.Empty(n)
            Test = [];
            for m = 1:length(ShiftPctArr)
                Shift = round(RespPts * ShiftPctArr(m));
                TrajMashObj.ExpInds = zeros(TrajMashObj.NumAcqs,1);
                TrajMashObj.ExpInds(Shift+(TrajMashObj.Peaks(n-1)+PeriRiseFallRespPts:TrajMashObj.Peaks(n)-PeriRiseFallRespPts)) = 1;
                if length(TrajMashObj.ExpInds) > length(TrajMashObj.NavSig)
                    TrajMashObj.ExpInds = TrajMashObj.ExpInds(1:length(TrajMashObj.NavSig));
                    Test(m) = 1e9;
                    break
                end
                Test(m) = sum(TrajMashObj.NavSig(logical(TrajMashObj.ExpInds)));
            end
            if sum(Test) == 0
                TrajMashObj.PeriShiftPct(n) = 0;
            else
                ind = find(Test == min(Test),1);
                TrajMashObj.PeriShiftPct(n) = ShiftPctArr(ind);
            end
        else
            Test = NaN*ones(length(ShiftPctArr),1);
            Shift = round(RespPts * TrajMashObj.ShiftPct(n));
            StartOfRed = Shift+TrajMashObj.Peaks(n-1)+RiseFallRespPts-1;
            EndOfRed = Shift+TrajMashObj.Peaks(n)-RiseFallRespPts+1;
            for m = 1:length(ShiftPctArr)
                PeriShift = round(RespPts * ShiftPctArr(m));
                StartOfGreen = PeriShift+TrajMashObj.Peaks(n-1)+PeriRiseFallRespPts;
                EndOfGreen = PeriShift+TrajMashObj.Peaks(n)-PeriRiseFallRespPts;
                if StartOfGreen > StartOfRed
                    continue
                end
                if EndOfGreen < EndOfRed
                    continue
                end
                TrajMashObj.PeriExpInds = zeros(TrajMashObj.NumAcqs,1);
                TrajMashObj.PeriExpInds(StartOfGreen:StartOfRed) = 1;
                TrajMashObj.PeriExpInds(EndOfRed:EndOfGreen) = 1;
                if length(TrajMashObj.PeriExpInds) > TrajMashObj.NumAcqs
                    TrajMashObj.PeriExpInds = ones(1,TrajMashObj.NumAcqs);
                end
                Test(m) = sum(TrajMashObj.NavSig(logical(TrajMashObj.PeriExpInds))+1);                      % make sure positive
            end
            if isnan(min(Test))
                TrajMashObj.PeriShiftPct(n) = 0;
            else
                ind = find(Test == min(Test),1);
                TrajMashObj.PeriShiftPct(n) = ShiftPctArr(ind);
            end
        end
    end

    TrajMashObj.ExpInds = zeros(TrajMashObj.NumAcqs,1);
    TrajMashObj.PeriExpInds = zeros(TrajMashObj.NumAcqs,1);
    for n = 2:length(TrajMashObj.Peaks)
        Shift = round(RespPts * TrajMashObj.ShiftPct(n));
        TrajMashObj.ExpInds(Shift+(TrajMashObj.Peaks(n-1)+RiseFallRespPts:TrajMashObj.Peaks(n)-RiseFallRespPts)) = 1;
        PeriShift = round(RespPts * TrajMashObj.PeriShiftPct(n));
        if TrajMashObj.Empty(n)
            TrajMashObj.PeriExpInds(PeriShift+(TrajMashObj.Peaks(n-1)+PeriRiseFallRespPts:TrajMashObj.Peaks(n)-PeriRiseFallRespPts)) = 1;
        else
            TrajMashObj.PeriExpInds(PeriShift+TrajMashObj.Peaks(n-1)+PeriRiseFallRespPts:Shift+TrajMashObj.Peaks(n-1)+RiseFallRespPts-1) = 1;
            TrajMashObj.PeriExpInds(Shift+TrajMashObj.Peaks(n)-RiseFallRespPts+1:PeriShift+TrajMashObj.Peaks(n)-PeriRiseFallRespPts) = 1;
        end
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
function SetFlip(TrajMashObj,val)
    TrajMashObj.Flip = val;
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