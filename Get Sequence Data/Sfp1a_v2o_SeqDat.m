%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = Sfp1a_v2o_SeqDat(MrProt,DataInfo)

err.flag = 0;
err.msg = '';

%---------------------------------------------
% Read Trajectory
%---------------------------------------------    
sWipMemBlock = MrProt.sWipMemBlock;
test1 = sWipMemBlock.alFree;
test2 = sWipMemBlock.adFree;
fov = num2str(test1{3});
vox = num2str(round(test1{4}*test1{5}*test1{6}/1e8));
elip = num2str(100*test1{5}/test1{6},'%2.0f');            
tro = num2str(round(10*test2{4}));
nproj = num2str(test1{10});
p = num2str(test1{7});
id = num2str(test1{8});
ExpPars.TrajName = ['TPI_F',fov,'_V',vox,'_E',elip,'_T',tro,'_N',nproj,'_P',p,'_ID',id];
ExpPars.TrajImpName = ExpPars.TrajName;

%---------------------------------------------
% Sequence Info
%---------------------------------------------
ExpPars.scantime = MrProt.lTotalScanTimeSec;
for n = 1:length(MrProt.adFlipAngleDegree)    
    if (isempty(MrProt.adFlipAngleDegree{n}))
        break;
    else
        ExpPars.Sequence.flip(n) = MrProt.adFlipAngleDegree{n};
        ExpPars.Sequence.rfpulselen(n) = test1{12+n};
        ExpPars.Sequence.tr(n) = MrProt.alTR{n}/1e3; 
        ExpPars.Sequence.te(n) = MrProt.alTE{n}/1e3; 
    end
end
ExpPars.Sequence.NumImages = length(ExpPars.Sequence.flip);
ExpPars.rcvrs = DataInfo.NCha;
%--
ExpPars.FirstSampDelay = '';                       
%--

%---------------------------------------------
% Other Info
%---------------------------------------------
ExpPars.Sequence.rdwn = 40;     % hard-coded
ExpPars.Sequence.trbuf = 200;    % hard-coded
ProtDefName = test1{12};
ExpPars.Sequence.GradDur = test1{23};
ExpPars.Sequence.GradMag = test1{24};
ExpPars.Sequence.GradSlewRate = test1{25};
ExpPars.Sequence.Dummies = test1{26};

%---------------------------------------------
% Testing Info
%---------------------------------------------
%ExpPars.Sequence.flamplitude = MrProt.sTXSPEC.aRFPULSE{1}.flAmplitude;
ExpPars.Sequence.RefVolt = MrProt.sTXSPEC.asNucleusInfo{1}.flReferenceAmplitude;

%---------------------------------------------
% Position Info
%---------------------------------------------
if isfield(MrProt.sAAInitialOffset,'SliceInformation')
    SliceInformation = MrProt.sAAInitialOffset.SliceInformation;
    ExpPars.shift = zeros(1,3);
    if isfield(SliceInformation,'sPosition')
        if isfield(SliceInformation.sPosition,'dSag')
            ExpPars.shift(1) = SliceInformation.sPosition.dSag;
        else
            ExpPars.shift(1) = 0;
        end
        if isfield(SliceInformation.sPosition,'dCor')
            ExpPars.shift(2) = SliceInformation.sPosition.dCor;
        else
            ExpPars.shift(2) = 0;
        end
        if isfield(SliceInformation.sPosition,'dTra')
            ExpPars.shift(3) = SliceInformation.sPosition.dTra;
        else
            ExpPars.shift(3) = 0;
        end
    else
        ExpPars.shift(1) = 0;
        ExpPars.shift(3) = 0;
        ExpPars.shift(2) = 0; 
    end
else
    ExpPars.shift(1) = 0;
    ExpPars.shift(3) = 0;
    ExpPars.shift(2) = 0; 
end

%---------------------------------------------
% FOR SPECIAL BRAIN CASE!
%---------------------------------------------
% ExpPars.shift(3) = -10; 
%---------------------------------------------
% ExpPars.shift(1) = 0;
% ExpPars.shift(2) = 0;
% ExpPars.shift(3) = 0; 

%---------------------------------------------
% Slab Direction
%---------------------------------------------
ExpPars.Sequence.slabdir = 'z';

%--------------------------------------------
% Other Parameters
%--------------------------------------------
ShimVals = zeros(1,9);
ShimVals(1) = MrProt.sGRADSPEC.asGPAData{1}.lOffsetX;
ShimVals(2) = MrProt.sGRADSPEC.asGPAData{1}.lOffsetY;
ShimVals(3) = MrProt.sGRADSPEC.asGPAData{1}.lOffsetZ;
ShimVals0 = [];
if isfield(MrProt.sGRADSPEC,'alShimCurrent')
    ShimVals0 = MrProt.sGRADSPEC.alShimCurrent;
end
for n = 1:length(ShimVals0)
    ShimVals(3+n) = ShimVals0{n};
end
ShimValsUI(1) = ShimVals(1)/6.2503;
ShimValsUI(2) = ShimVals(2)/6.2552;
ShimValsUI(3) = ShimVals(3)/6.0847;
ShimValsUI(4) = ShimVals(4)/2.0159;
ShimValsUI(5) = ShimVals(5)/2.8153;
ShimValsUI(6) = ShimVals(6)/2.8534;
ShimValsUI(7) = ShimVals(7)/2.8150;
ShimValsUI(8) = ShimVals(8)/2.8667;
ShimNames = {'x','y','z','z2','zx','zy','x2y2','xy','tof'};
Freq = MrProt.sTXSPEC.asNucleusInfo{1}.lFrequency;

ExpPars.Shims = ShimValsUI;

%--------------------------------------------
% Panel
%--------------------------------------------
m = 1;
Panel(1,:) = {'','','Output'};
m = m+1;
Panel(2,:) = {'Trajectory',ExpPars.TrajName,'Output'};
m = m+1;
Panel(3,:) = {'Receivers',ExpPars.rcvrs,'Output'};
m = m+1;
Panel(4,:) = {'Scan Time (seconds)',ExpPars.scantime,'Output'};
m = m+1;
Panel(5,:) = {'TR (ms)',ExpPars.Sequence.tr,'Output'};
m = m+1;
Panel(6,:) = {'TE (ms)',ExpPars.Sequence.te,'Output'};
m = m+1;
Panel(7,:) = {'Flip (degrees)',ExpPars.Sequence.flip,'Output'};
m = m+1;
Panel(m,:) = {'RfDur (us)',ExpPars.Sequence.rfpulselen,'Output'};
m = m+1;
Panel(m,:) = {'','','Output'};
m = m+1;
Panel(m,:) = {'GradDur (us)',ExpPars.Sequence.GradDur,'Output'};
m = m+1;
Panel(m,:) = {'GradMag (mT/m)',ExpPars.Sequence.GradMag,'Output'};
m = m+1;
Panel(m,:) = {'GradSlewRate (mT/m/ms)',ExpPars.Sequence.GradSlewRate,'Output'};
m = m+1;
Panel(m,:) = {'RingDown (us)',ExpPars.Sequence.rdwn,'Output'};
m = m+1;
Panel(m,:) = {'TrBuf (us)',ExpPars.Sequence.trbuf,'Output'};
m = m+1;
Panel(m,:) = {'Dummies',ExpPars.Sequence.Dummies,'Output'};
m = m+1;
Panel(m,:) = {'RefVolt',ExpPars.Sequence.RefVolt,'Output'};
m = m+1;
Panel(m,:) = {'','','Output'};
m = m+1;
Panel(m,:) = {'Frequency',Freq,'Output'};
for n = 1:8
    if isempty(ShimValsUI(n))
        ShimValsUI(n) = 0;
    end
    Panel(m+n,:) = {['Shim_',ShimNames{n}],round(ShimValsUI(n)),'Output'};
end

% Panel(24,:) = {'','','Output'};
% Panel(25,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
% Panel(26,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
% Panel(27,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};

PanelOutput = cell2struct(Panel,{'label','value','type'},2);

