%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = Yfp2e_v2o_SeqDat(MrProt,DataInfo)

err.flag = 0;
err.msg = '';

%---------------------------------------------
% Read Trajectory
%---------------------------------------------    
sWipMemBlock = MrProt.sWipMemBlock;
test1 = sWipMemBlock.alFree;
test2 = sWipMemBlock.adFree;
type = 'YB';
fov = num2str(test1{3});
vox = num2str(round(test1{4}*test1{5}*test1{6}/1e8));
elip = num2str(100*test1{5}/test1{6},'%2.0f');            
tro = num2str(round(10*test2{4}));
nproj = num2str(test1{11});
p = num2str(test1{7});
samptype = num2str(test1{8});
usamp = num2str(100*test2{6});
id = num2str(test1{9});
ExpPars.TrajName = [type,'_F',fov,'_V',vox,'_E',elip,'_T',tro,'_N',nproj,'_P',p,'_S',samptype,usamp,'_ID',id];
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
        ExpPars.Sequence.rfpulselen(n) = test1{11+n};
        ExpPars.Sequence.tr(n) = MrProt.alTR{n}/1e3; 
        ExpPars.Sequence.te(n) = MrProt.alTE{n}/1e3; 
    end
end
ExpPars.Sequence.NumImages = length(ExpPars.Sequence.flip);
ExpPars.rcvrs = DataInfo.NCha;

%---------------------------------------------
% Other Info
%---------------------------------------------
ExpPars.Sequence.rdwn = test1{16};
if isempty(ExpPars.Sequence.rdwn)
    ExpPars.Sequence.rdwn = 0;
end
ExpPars.Sequence.trbuf = test1{17};
if isempty(ExpPars.Sequence.trbuf)
    ExpPars.Sequence.trbuf = 0;
end
ProtDefName = test1{18};
ExpPars.Sequence.GradDur = test1{19};
ExpPars.Sequence.GradMag = test1{20};
ExpPars.Sequence.GradSlewRate = test1{21};
ExpPars.Sequence.RfSatRec = test1{22};
ExpPars.Sequence.RfSatIntv = test1{23};
ExpPars.Sequence.Dummies = test1{24};
ExpPars.Sequence.SarScale = test1{25};
ExpPars.Sequence.GradPreStart = test1{26};
ExpPars.Sequence.Seq(1) = test1{26};
ExpPars.Sequence.Seq(2) = test1{27};
ExpPars.Sequence.Seq(3) = test1{28};
ExpPars.Sequence.Seq(4) = test1{29};

%---------------------------------------------
% Testing Info
%---------------------------------------------
%ExpPars.Sequence.flamplitude = MrProt.sTXSPEC.aRFPULSE{1}.flAmplitude;
ExpPars.Sequence.flamplitude = 'N/A On XA30';

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
% Panel
%--------------------------------------------
Panel(1,:) = {'','','Output'};
Panel(2,:) = {'Trajectory',ExpPars.TrajName,'Output'};
Panel(3,:) = {'Receivers',ExpPars.rcvrs,'Output'};
Panel(4,:) = {'Scan Time (seconds)',ExpPars.scantime,'Output'};
Panel(5,:) = {'TR (ms)',ExpPars.Sequence.tr,'Output'};
Panel(6,:) = {'TE (ms)',ExpPars.Sequence.te,'Output'};
Panel(7,:) = {'Flip (degrees)',ExpPars.Sequence.flip,'Output'};
m = 8;
Panel(m,:) = {'','','Output'};
for n = 1:ExpPars.Sequence.NumImages
    m = m+1;
    Panel(m,:) = {'RfDur (us)',ExpPars.Sequence.rfpulselen(n),'Output'};
end 
m = m+1;
Panel(m,:) = {'RingDown (us)',ExpPars.Sequence.rdwn,'Output'};
m = m+1;
Panel(m,:) = {'TrBuf (us)',ExpPars.Sequence.trbuf,'Output'};
m = m+1;
Panel(m,:) = {'','','Output'};
m = m+1;
Panel(m,:) = {'GradDur (us)',ExpPars.Sequence.GradDur,'Output'};
m = m+1;
Panel(m,:) = {'GradMag (mT/m)',ExpPars.Sequence.GradMag,'Output'};
m = m+1;
Panel(m,:) = {'GradSlewRate (mT/m/ms)',ExpPars.Sequence.GradSlewRate,'Output'};
% m = m+1;
% Panel(m,:) = {'RfSatRecovery (us)',ExpPars.Sequence.RfSatRec,'Output'};
% m = m+1;
% Panel(m,:) = {'RfSatIntv (us)',ExpPars.Sequence.RfSatIntv,'Output'};
m = m+1;
Panel(m,:) = {'Dummies',ExpPars.Sequence.Dummies,'Output'};

% Panel(24,:) = {'','','Output'};
% Panel(25,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
% Panel(26,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
% Panel(27,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};

PanelOutput = cell2struct(Panel,{'label','value','type'},2);

