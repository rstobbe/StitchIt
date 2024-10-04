%=================================================================================
% WeightArr = [Traj1_Ave1 Traj1_Ave2 ... TrajN_AveN 
%  - sum of weights over averages for each trajectory must equal 1.
%=================================================================================

function TrajMashInfo = TrajMash20RespPhasesGaussian_RandAcq1a(k0,DataObj,ReconObj)

%------------------------------------------------
% Info
%------------------------------------------------
NumTraj = ReconObj.NumTraj;
NumAverages = ReconObj.NumAverages;
NumAcqs = NumTraj*NumAverages;
TrajLocAllAcq = ReconObj.TrajLocAllAcq;
TR = DataObj.DataInfo.ExpPars.Sequence.tr;

%------------------------------------------------
% Test
%------------------------------------------------
if length(k0) ~= NumAcqs
    error('array length does not match metadata info');
end

%------------------------------------------------
% Input
%------------------------------------------------
StartSkip = 2000; 
DispFigs = 1;

%------------------------------------------------
% Starting Figure
%------------------------------------------------
if DispFigs > 1
    figure(1001); hold on; 
    plot(StartSkip:length(k0),abs(k0(StartSkip:end,1))); 
    % figure(1002); hold on; 
    % plot(StartSkip:length(k0),abs(k0(StartSkip:end,2))); 
end

%------------------------------------------------
% Filter
%------------------------------------------------
NumCoils = size(k0,2);
Span = round(1000/TR);
for n = 1:NumCoils
    SmthK0(:,n) = abs(smooth(k0(:,n),Span,'lowess'));
end
if DispFigs > 1
    figure(1001); hold on; 
    plot(StartSkip:length(SmthK0),abs(SmthK0(StartSkip:end,1)),'LineWidth',1);
    % figure(1002); hold on; 
    % plot(StartSkip:length(SmthK0),abs(SmthK0(StartSkip:end,2)),'LineWidth',1);
end

%------------------------------------------------
% Drop irrelevant channels
%------------------------------------------------
skip = 5*NumAverages;                                         
cc = zeros(NumCoils,NumCoils);
if(NumCoils>2)
    for j = 1:NumCoils
        for k = 1:NumCoils
            ttt = corrcoef(SmthK0(5000:skip:end,j),SmthK0(5000:skip:end,k));
            cc(j,k) = ttt(1,2);
        end
    end
    for j = 1:NumCoils
        inds(j) = length(find(abs(cc(:,j))>0.80));
    end
    indsToUse=find(inds>(NumCoils/4));
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
NavSig = -T2;                           % inspiration = peak
NavSig(1:StartSkip-1) = 0;
if DispFigs > 0
    figure(2001); hold on; 
    plot(StartSkip:length(NavSig),NavSig(StartSkip:end));
end

%------------------------------------------------
% Determine Trajs to Use
%------------------------------------------------
AtExpirationFrac = 0.25;
Sel = (max(NavSig)-min(NavSig))/4;
Peaks = peakfinder(NavSig,Sel);
if DispFigs > 0
    figure(2001); hold on; 
    plot(Peaks,NavSig(Peaks),'o')
end
PeaksDiff = diff(Peaks);
HalfRespPts = median(PeaksDiff)/2;
RiseFallRespPts = round(HalfRespPts*(1-AtExpirationFrac));
PeriRiseFallRespPts = round(RiseFallRespPts/1.5);

ExpInds = zeros(NumAcqs,1);
PeriExpInds = zeros(NumAcqs,1);
for n = 2:length(Peaks)
    ExpInds(Peaks(n-1)+RiseFallRespPts:Peaks(n)-RiseFallRespPts) = 1;
    PeriExpInds(Peaks(n-1)+PeriRiseFallRespPts:Peaks(n-1)+RiseFallRespPts-1) = 1;
    PeriExpInds(Peaks(n)-RiseFallRespPts+1:Peaks(n)-PeriRiseFallRespPts) = 1;
end
AcqsArr = 1:NumAcqs;
if DispFigs > 0
    figure(2001); hold on; 
    plot(AcqsArr(logical(ExpInds)),NavSig(logical(ExpInds)),'r*')
    plot(AcqsArr(logical(PeriExpInds)),NavSig(logical(PeriExpInds)),'g*')
end

%------------------------------------------------
% Weighting
%------------------------------------------------
Holes = 0;
PeriVals = 0;
for n = 1:NumTraj
    if DispFigs > 0
        if n == 1
            figure(2001); hold on; 
            plot(TrajLocAllAcq(n,:),NavSig(TrajLocAllAcq(n,:)),'k*');
        end
    end
    Weight(n,:) = ExpInds(TrajLocAllAcq(n,:));
    SumWeight(n) = sum(Weight(n,:),2);
    if SumWeight(n) == 0
        PeriVals = PeriVals + 1;
        Weight(n,:) = PeriExpInds(TrajLocAllAcq(n,:));
        SumWeight(n) = sum(Weight(n,:),2);
    end
    if SumWeight(n) == 0
        Holes = Holes + 1;
        Weight(n,:) = ones(1,NumAverages);
        SumWeight(n) = sum(Weight(n,:),2);
    end
    NormWeight(n,:) = Weight(n,:)/SumWeight(n);
end
if DispFigs > 1
    figure(3001); hold on; 
    plot(SumWeight);
    ylim([0 NumAverages]);
end
PeriValsFraction = PeriVals/NumTraj
HoleFraction = Holes/NumTraj

TrajMashInfo.WeightArr = NormWeight;
TrajMashInfo.NumImages = 1;