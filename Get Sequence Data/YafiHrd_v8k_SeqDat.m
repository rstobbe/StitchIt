%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = YafiHrd_v8k_SeqDat(MrProt,DataInfo)

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
if isfield(MrProt,'lTotalScanTimeSec')
    ExpPars.scantime = MrProt.lTotalScanTimeSec;                
else
    ExpPars.scantime = 'did not save';
end
ExpPars.Sequence.flip = MrProt.adFlipAngleDegree{1};             % in degrees
ExpPars.Sequence.TrRatio = test1{26};
ExpPars.Sequence.tr1 = MrProt.alTR{1}/1e3;                       % in ms
ExpPars.Sequence.tr2 = ExpPars.Sequence.tr1 * ExpPars.Sequence.TrRatio;
ExpPars.Sequence.tr = ExpPars.Sequence.tr1 + ExpPars.Sequence.tr2;
ExpPars.Sequence.te = MrProt.alTE{1}/1e3;                        % in ms
ExpPars.rcvrs = DataInfo.NCha;
%--
ExpPars.FirstSampDelay = ExpPars.Sequence.te;                       % te might actually be associated with a later sampling point
%--

%---------------------------------------------
% Other Info
%---------------------------------------------
ExpPars.Sequence.rfpulselen = test1{12};
ExpPars.Sequence.rdwn = test1{13};
if isempty(ExpPars.Sequence.rdwn)
    ExpPars.Sequence.rdwn = 0;
end
ExpPars.Sequence.trbuf = test1{14};
if isempty(ExpPars.Sequence.trbuf)
    ExpPars.Sequence.trbuf = 0;
end
ExpPars.Sequence.Grad1Dur = test1{16};
ExpPars.Sequence.Grad2Dur = test1{17};
ExpPars.Sequence.Grad1Mag = test1{18};
ExpPars.Sequence.Grad2Mag = test1{19};
ExpPars.Sequence.RandRelWid = test1{22}/100;
ExpPars.Sequence.GradSlewRate = test1{24};
ExpPars.Sequence.GradRandSeed = test1{25};
ExpPars.Sequence.AfiRatio = test1{26};

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
Panel(5,:) = {'TR1 (ms)',ExpPars.Sequence.tr1,'Output'};
Panel(6,:) = {'TR2 (ms)',ExpPars.Sequence.tr2,'Output'};
Panel(7,:) = {'TE (ms)',ExpPars.Sequence.te,'Output'};
Panel(8,:) = {'Flip (degrees)',ExpPars.Sequence.flip,'Output'};
Panel(9,:) = {'','','Output'};
Panel(10,:) = {'RfDur (us)',ExpPars.Sequence.rfpulselen,'Output'};
Panel(11,:) = {'TrBuf (us)',ExpPars.Sequence.trbuf,'Output'};
Panel(12,:) = {'','','Output'};
Panel(13,:) = {'Grad1Dur (us)',ExpPars.Sequence.Grad1Dur,'Output'};
Panel(14,:) = {'Grad2Dur (us)',ExpPars.Sequence.Grad2Dur,'Output'};
Panel(15,:) = {'Grad1Mag (mT/m)',ExpPars.Sequence.Grad1Mag,'Output'};
Panel(16,:) = {'Grad2Mag (mT/m)',ExpPars.Sequence.Grad2Mag,'Output'};
Panel(17,:) = {'RandRelWid',ExpPars.Sequence.RandRelWid,'Output'};
Panel(18,:) = {'GradSlewRate (mT/m/ms)',ExpPars.Sequence.GradSlewRate,'Output'};
Panel(19,:) = {'GradRandSeed',ExpPars.Sequence.GradRandSeed,'Output'};
Panel(20,:) = {'AfiRatio',ExpPars.Sequence.AfiRatio,'Output'};
% Panel(21,:) = {'','','Output'};
% Panel(22,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
% Panel(23,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
% Panel(24,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};

PanelOutput = cell2struct(Panel,{'label','value','type'},2);


