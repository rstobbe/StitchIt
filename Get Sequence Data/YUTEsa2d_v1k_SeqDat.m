%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = YUTEsa2d_v1k_SeqDat(MrProt,DataInfo)

err.flag = 0;
err.msg = '';

% Status2('busy','Load ''YUTEsa2'' Sequence Info',2);

%---------------------------------------------
% Read Trajectory
%---------------------------------------------    
sWipMemBlock = MrProt.sWipMemBlock;
test1 = sWipMemBlock.alFree;
test2 = sWipMemBlock.adFree;
if test1{3} == 10
    type = 'YB';
end
fov = num2str(test1{21});
vox = num2str(round(test1{22}*test1{23}*test1{24}/1e8));
elip = num2str(100);            
tro = num2str(round(10*test2{5}));
nproj = num2str(test1{6});
p = num2str(test1{25});
samptype = num2str(test1{26});
usamp = num2str(100*test2{7});
id = num2str(test1{27});
ExpPars.TrajName = [type,'_F',fov,'_V',vox,'_E',elip,'_T',tro,'_N',nproj,'_P',p,'_S',samptype,usamp,'_ID',id];
vox = num2str(round(10*test2{5}*test2{6}*test2{7}),'%04.0f');
tro = num2str(round(10*test2{5}),'%03.0f');
if test1{26} == 10
    samptype = 'U';
end
ExpPars.TrajImpName = ['IMP_F',fov,'_V',vox,'_E',elip,'_T',tro,'_N',nproj,'_S',samptype,usamp,'_ID',id];

%---------------------------------------------
% Sequence Info
%---------------------------------------------
ExpPars.scantime = MrProt.lTotalScanTimeSec;
ExpPars.Sequence.flip = MrProt.adFlipAngleDegree{1};             % in degrees
ExpPars.Sequence.tr = MrProt.alTR{1}/1e3;                        % in ms
ExpPars.Sequence.te = MrProt.alTE{1}/1e3;                        % in ms
ExpPars.rcvrs = DataInfo.NCha;
ExpPars.averages = DataInfo.NAve;

%---------------------------------------------
% Other Info
%---------------------------------------------
ExpPars.Sequence.rfpulselen = test1{31};
ExpPars.Sequence.rdwn = test1{32};
if isempty(ExpPars.Sequence.rdwn)
    ExpPars.Sequence.rdwn = 0;
end
ExpPars.Sequence.trbuf = test1{33};
if isempty(ExpPars.Sequence.trbuf)
    ExpPars.Sequence.trbuf = 0;
end
ExpPars.Sequence.asymmreftwk = test2{9};
ExpPars.Sequence.relslab = test2{13};
ExpPars.Sequence.rfspoil = test2{10};

%---------------------------------------------
% Testing Info
%---------------------------------------------
ExpPars.Sequence.flamplitude = MrProt.sTXSPEC.aRFPULSE{1}.flAmplitude;

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
        ExpPars.shift(2) = 0;
        ExpPars.shift(3) = 0; 
    end
else
    ExpPars.shift(1) = 0;
    ExpPars.shift(2) = 0;
    ExpPars.shift(3) = 0; 
end

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
Panel(8,:) = {'Averages',ExpPars.averages,'Output'};
Panel(9,:) = {'','','Output'};
Panel(10,:) = {'rfdur (us)',ExpPars.Sequence.rfpulselen,'Output'};
Panel(11,:) = {'rdwn (us)',ExpPars.Sequence.rdwn,'Output'};
Panel(12,:) = {'flamplitude',ExpPars.Sequence.flamplitude,'Output'};
Panel(13,:) = {'rfspoil (deg)',ExpPars.Sequence.rfspoil,'Output'};
Panel(14,:) = {'trbuf (us)',ExpPars.Sequence.trbuf,'Output'};
Panel(15,:) = {'relslab',ExpPars.Sequence.relslab,'Output'};
Panel(16,:) = {'asymmreftwk',ExpPars.Sequence.asymmreftwk,'Output'};
Panel(17,:) = {'','','Output'};
Panel(18,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
Panel(19,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
Panel(20,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};
PanelOutput = cell2struct(Panel,{'label','value','type'},2);

% Status2('done','',2);       

