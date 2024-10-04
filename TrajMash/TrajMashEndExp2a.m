%==================================================================
% (V2a)
%   - 
%==================================================================

classdef TrajMashEndExp2a < handle

properties (SetAccess = private)                   
    Method = 'TrajMashEndExp2a'
    % Selectable
    StartSkip = 2000            % Trajectories to skip (steady-state)
    DispFigs = 0                % 0 = no figures; 1 = basic; 2 = verbose
    FilterTime = 1000           % The span of the filter in ms
    AtExpirationFrac = 0.25     % The 'fraction of the respiration cycle' included as expiration  
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
    end
    
    %------------------------------------------------
    % Filter
    %------------------------------------------------
    TrajMashObj.NumCoils = size(k0,2);
    TrajMashObj.FilterSpan = round(TrajMashObj.FilterTime/TrajMashObj.TR);
    for n = 1:TrajMashObj.NumCoils
        SmthK0(:,n) = abs(smooth(k0(:,n),TrajMashObj.FilterSpan,'lowess'));
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
    TrajMashObj.NavSig = -T2;                           % inspiration = peak
    TrajMashObj.NavSig(1:TrajMashObj.StartSkip-1) = 0;
    TrajMashObj.NavSig = single(TrajMashObj.NavSig);
    if TrajMashObj.DispFigs > 0
        figure(2001); hold on; 
        plot(TrajMashObj.StartSkip:length(TrajMashObj.NavSig),TrajMashObj.NavSig(TrajMashObj.StartSkip:end));
    end
end

%==================================================================
% WeightTrajectories
%==================================================================  
function WeightTrajectories(TrajMashObj)

    %------------------------------------------------
    % Determine Trajs to Use
    %------------------------------------------------
    Sel = (max(TrajMashObj.NavSig)-min(TrajMashObj.NavSig))/4;
    Peaks = peakfinder(TrajMashObj.NavSig,Sel);
    if TrajMashObj.DispFigs > 0
        figure(2001); hold on; 
        plot(Peaks,TrajMashObj.NavSig(Peaks),'o')
    end
    PeaksDiff = diff(Peaks);
    HalfRespPts = median(PeaksDiff)/2;
    RiseFallRespPts = round(HalfRespPts*(1-TrajMashObj.AtExpirationFrac));
    PeriRiseFallRespPts = round(RiseFallRespPts/1.5);
    
    ExpInds = zeros(TrajMashObj.NumAcqs,1);
    PeriExpInds = zeros(TrajMashObj.NumAcqs,1);
    for n = 2:length(Peaks)
        ExpInds(Peaks(n-1)+RiseFallRespPts:Peaks(n)-RiseFallRespPts) = 1;
        PeriExpInds(Peaks(n-1)+PeriRiseFallRespPts:Peaks(n-1)+RiseFallRespPts-1) = 1;
        PeriExpInds(Peaks(n)-RiseFallRespPts+1:Peaks(n)-PeriRiseFallRespPts) = 1;
    end
    AcqsArr = 1:TrajMashObj.NumAcqs;
    if TrajMashObj.DispFigs > 0
        figure(2001); hold on; 
        plot(AcqsArr(logical(ExpInds)),TrajMashObj.NavSig(logical(ExpInds)),'r*')
        plot(AcqsArr(logical(PeriExpInds)),TrajMashObj.NavSig(logical(PeriExpInds)),'g*')
    end
    
    %------------------------------------------------
    % Weighting
    %------------------------------------------------
    Holes = 0;
    PeriVals = 0;
    for n = 1:TrajMashObj.NumTraj
        if TrajMashObj.DispFigs > 0
            if n == 1
                figure(2001); hold on; 
                plot(TrajMashObj.TrajLocAllAcq(n,:),TrajMashObj.NavSig(TrajMashObj.TrajLocAllAcq(n,:)),'k*');
            end
        end
        Weight(n,:) = ExpInds(TrajMashObj.TrajLocAllAcq(n,:));
        SumWeight(n) = sum(Weight(n,:),2);
        if SumWeight(n) == 0
            PeriVals = PeriVals + 1;
            Weight(n,:) = PeriExpInds(TrajMashObj.TrajLocAllAcq(n,:));
            SumWeight(n) = sum(Weight(n,:),2);
        end
        if SumWeight(n) == 0
            Holes = Holes + 1;
            Weight(n,:) = ones(1,TrajMashObj.NumAverages);
            SumWeight(n) = sum(Weight(n,:),2);
        end
        NormWeight(n,:) = Weight(n,:)/SumWeight(n);
    end
    if TrajMashObj.DispFigs > 1
        figure(3001); hold on; 
        plot(SumWeight);
        ylim([0 TrajMashObj.NumAverages]);
    end
    TrajMashObj.PeriValsFraction = PeriVals/TrajMashObj.NumTraj;
    TrajMashObj.HoleFraction = Holes/TrajMashObj.NumTraj;
    TrajMashObj.MeanTrajsUsed = mean(SumWeight);

    TrajMashObj.WeightArr = single(NormWeight);
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
function SetFilterTime(TrajMashObj,val)
    TrajMashObj.FilterTime = val;
end
function SetAtExpirationFrac(TrajMashObj,val)
    TrajMashObj.AtExpirationFrac = val;
end



end
end