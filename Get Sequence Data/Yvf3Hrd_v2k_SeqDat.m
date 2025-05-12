%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = Yvf3Hrd_v2k_SeqDat(MrProt,DataInfo)

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
ExpPars.Sequence.numflips = 3;
ExpPars.Sequence.flip(1) = MrProt.adFlipAngleDegree{1};             % in degrees
ExpPars.Sequence.flip(2) = MrProt.adFlipAngleDegree{2};             % in degrees
ExpPars.Sequence.flip(3) = MrProt.adFlipAngleDegree{3};             % in degrees
ExpPars.Sequence.tr = MrProt.alTR{1}/1e3;                       % in ms
ExpPars.Sequence.te = MrProt.alTE{1}/1e3;                        % in ms
ExpPars.rcvrs = DataInfo.NCha;
%--
ExpPars.FirstSampDelay = ExpPars.Sequence.te;                       % te might actually be associated with a later sampling point
%--

%---------------------------------------------
% Other Info
%---------------------------------------------
ExpPars.Sequence.rfpulselen(1) = test1{12};
ExpPars.Sequence.rfpulselen(2) = test1{13};
ExpPars.Sequence.rfpulselen(3) = test1{14};
ExpPars.Sequence.rdwn = test1{15};
if isempty(ExpPars.Sequence.rdwn)
    ExpPars.Sequence.rdwn = 0;
end
ExpPars.Sequence.trbuf = test1{16};
if isempty(ExpPars.Sequence.trbuf)
    ExpPars.Sequence.trbuf = 0;
end
ProtDefName = test1{17};
ExpPars.Sequence.GradDur = test1{18};
ExpPars.Sequence.GradMag = test1{19};
if isempty(test1{20})
    test1{20} = 0;
end
if test1{20} == 0
    ExpPars.Sequence.RandGradSpoil = 'No';
    ExpPars.Sequence.RandRelWid = 'N/A';
    ExpPars.Sequence.GradRandSeed = 'N/A';
else
    ExpPars.Sequence.RandGradSpoil = 'Yes';
    ExpPars.Sequence.RandRelWid = test1{21}/100;
    ExpPars.Sequence.GradRandSeed = test1{24};
end
if isempty(test1{22})
    test1{22} = 0;
end
if test1{22} == 0
    ExpPars.Sequence.MultiAxisGradSpoil = 'No';
else
    ExpPars.Sequence.MultiAxisGradSpoil = 'Yes';
end
ExpPars.Sequence.GradSlewRate = test1{23};
if isempty(test1{25})
    test1{25} = 0;
end
if test1{25} == 0
    ExpPars.Sequence.RfSpoil = 'Inc50';
else
    ExpPars.Sequence.RfSpoil = 'Rand';
end
if isempty(test1{26})
    test1{26} = 0;
end
if test1{26} == 0
    ExpPars.Sequence.Gain = 'Low';
else
    ExpPars.Sequence.Gain = 'High';
end

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
Panel(7,:) = {'Flip1 (degrees)',ExpPars.Sequence.flip(1),'Output'};
Panel(8,:) = {'Flip2 (degrees)',ExpPars.Sequence.flip(2),'Output'};
Panel(9,:) = {'Flip3 (degrees)',ExpPars.Sequence.flip(3),'Output'};
Panel(10,:) = {'','','Output'};
Panel(11,:) = {'RfDur1 (us)',ExpPars.Sequence.rfpulselen(1),'Output'};
Panel(12,:) = {'RfDur2 (us)',ExpPars.Sequence.rfpulselen(2),'Output'};
Panel(13,:) = {'RfDur3 (us)',ExpPars.Sequence.rfpulselen(3),'Output'};
Panel(14,:) = {'RingDown (us)',ExpPars.Sequence.rdwn,'Output'};
Panel(15,:) = {'TrBuf (us)',ExpPars.Sequence.trbuf,'Output'};
Panel(16,:) = {'','','Output'};
Panel(17,:) = {'GradDur (us)',ExpPars.Sequence.GradDur,'Output'};
Panel(18,:) = {'GradMag (mT/m)',ExpPars.Sequence.GradMag,'Output'};
Panel(19,:) = {'RandGradSpoil',ExpPars.Sequence.RandGradSpoil,'Output'};
Panel(20,:) = {'RandGradRelWid',ExpPars.Sequence.RandRelWid,'Output'};
Panel(21,:) = {'RandGradSeed',ExpPars.Sequence.GradRandSeed,'Output'};
Panel(22,:) = {'GradSlewRate (mT/m/ms)',ExpPars.Sequence.GradSlewRate,'Output'};
Panel(23,:) = {'MultiAxisSGradSpoil',ExpPars.Sequence.MultiAxisGradSpoil,'Output'};
Panel(24,:) = {'RfSpoil',ExpPars.Sequence.RfSpoil,'Output'};
Panel(25,:) = {'Gain',ExpPars.Sequence.Gain,'Output'};
% Panel(24,:) = {'','','Output'};
% Panel(25,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
% Panel(26,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
% Panel(27,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};

PanelOutput = cell2struct(Panel,{'label','value','type'},2);

