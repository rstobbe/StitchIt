%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = YessWe_v1k_SeqDat(MrProt,DataInfo)

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
ExpPars.Sequence.flip = MrProt.adFlipAngleDegree{1};             % in degrees
ExpPars.Sequence.tr = MrProt.alTR{1}/1e3;                        % in ms
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
ExpPars.Sequence.relslab = test2{9};
ExpPars.Sequence.tbw = test2{10};
Recon = test1{15};
ExpPars.Sequence.wedelay = test1{16};

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
ExpPars.shift(3) = -10; 
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
Panel(8,:) = {'','','Output'};
Panel(9,:) = {'rfdur (us)',ExpPars.Sequence.rfpulselen,'Output'};
Panel(10,:) = {'rdwn (us)',ExpPars.Sequence.rdwn,'Output'};
Panel(11,:) = {'trbuf (us)',ExpPars.Sequence.trbuf,'Output'};
Panel(12,:) = {'relslab',ExpPars.Sequence.relslab,'Output'};
Panel(13,:) = {'tbw',ExpPars.Sequence.tbw,'Output'};
Panel(14,:) = {'wedelay (us)',ExpPars.Sequence.wedelay,'Output'};
Panel(15,:) = {'','','Output'};
Panel(16,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
Panel(17,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
Panel(18,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};

PanelOutput = cell2struct(Panel,{'label','value','type'},2);


