%==================================================================
% (V2a)
%   - 
%==================================================================

classdef TrajMashEndExp2a < handle

properties (SetAccess = private)                   
    Method = 'TrajMashEndExp2a'
    % Selectable
    StartSkip = 2000            % Trajectories to skip (steady-state)
    DispFigs = 1                % 0 = no figures; 1 = basic; 2 = verbose
    AtExpirationFrac = 0.25     % The 'fraction of the respiration cycle' included as expiration  
    Polarity = 1                % Polarity of Navigator
    PeakFindSensitivity = 3
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
function TrajMashObj = TrajMashEndExp2a()              
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
    TrajMashObj.k0 = k0;

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
        plot(TrajMashObj.StartSkip:length(k0),abs(k0(TrajMashObj.StartSkip:end,1))); 
        % figure(1002); hold on; 
        % plot(TrajMashObj.StartSkip:length(k0),abs(k0(TrajMashObj.StartSkip:end,2))); 
        title('Centre of k-Space Data')
    end
    
    %------------------------------------------------
    % Initial Navigator
    %------------------------------------------------
    TrajMashObj.FilterTime = 1000;          % starting filter time
    TrajMashObj.FilterCombine;
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
    TrajMashObj.FilterCombine;
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
% FilterCombine
%================================================================== 
function FilterCombine(TrajMashObj)

    %------------------------------------------------
    % Filter
    %------------------------------------------------
    TrajMashObj.NumCoils = size(TrajMashObj.k0,2);
    TrajMashObj.FilterSpan = round(TrajMashObj.FilterTime/TrajMashObj.TR);
    for n = 1:TrajMashObj.NumCoils
        SmthK0(:,n) = abs(smooth(TrajMashObj.k0(:,n),TrajMashObj.FilterSpan,'lowess'));
    end
    if TrajMashObj.DispFigs > 1
        figure(1001); hold on; 
        plot(TrajMashObj.StartSkip:length(SmthK0),abs(SmthK0(TrajMashObj.StartSkip:end,1)),'LineWidth',1);
        % figure(1002); hold on; 
        % plot(TrajMashObj.StartSkip:length(SmthK0),abs(SmthK0(TrajMashObj.StartSkip:end,2)),'LineWidth',1);
    end
    
    %------------------------------------------------
    % Drop irrelevant channels
    %------------------------------------------------
    skip = 5*TrajMashObj.NumAverages;                                         
    cc = zeros(TrajMashObj.NumCoils,TrajMashObj.NumCoils);
    if(TrajMashObj.NumCoils>2)
        for j = 1:TrajMashObj.NumCoils
            for k = 1:TrajMashObj.NumCoils
                ttt = corrcoef(SmthK0(5000:skip:end,j),SmthK0(5000:skip:end,k));
                cc(j,k) = ttt(1,2);
            end
        end
        for j = 1:TrajMashObj.NumCoils
            inds(j) = length(find(abs(cc(:,j))>0.80));
        end
        indsToUse=find(inds>(TrajMashObj.NumCoils/4));
        if(isempty(indsToUse))
            indsToUse=find(inds>(0.5*max(inds)));
        end
    else
        indsToUse=[1,2];
    end
    RespData = SmthK0(:,indsToUse);
    
    %------------------------------------------------
    % PCA covariance method
    %------------------------------------------------
    X = RespData;
    u = mean(X,1);
    h = ones(length(X),1);
    B = X-h*u;
    C = cov(B);
    [V,D] = eig(C);
    [d,ind] = sort(diag(D));
    W = V(:,ind(end));                      % weight the most correlated one the most (and get signs right)
    %----
    Z1 = zscore(X,[],2);                    % across coils       
    T1 = Z1*W;
    [a b] = sort(abs(T1));
    T1 = T1' / mean(a(end-20:end));
    %----
    Z2 = zscore(X,[],1);                    % across acquisitions      
    T2 = Z2*W;
    [a b] = sort(abs(T2));
    T2 = T2' / mean(a(end-20:end));
    if TrajMashObj.Polarity == -1
        TrajMashObj.NavSig = -T2;                           % inspiration = peak
    else
        TrajMashObj.NavSig = T2;
    end
    TrajMashObj.NavSig(1:TrajMashObj.StartSkip-1) = 0;
    TrajMashObj.NavSig = single(TrajMashObj.NavSig);
end

%==================================================================
% PeakFinder
%================================================================== 
function PeakFinder(TrajMashObj)
    if TrajMashObj.PeakFindSensitivity == 1
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/3;
    elseif TrajMashObj.PeakFindSensitivity == 2 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/4;
    elseif TrajMashObj.PeakFindSensitivity == 3 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/5;
    elseif TrajMashObj.PeakFindSensitivity == 4 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/7;
    elseif TrajMashObj.PeakFindSensitivity == 5 
        Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/10;
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
function SetPolarity(TrajMashObj,val)
    TrajMashObj.Polarity = val;
end
function SetPeakFindSensitivity(TrajMashObj,val)
    TrajMashObj.PeakFindSensitivity = val;
end


end
end