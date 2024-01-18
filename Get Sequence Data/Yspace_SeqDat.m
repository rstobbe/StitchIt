%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = Yspace_SeqDat(MrProt,DataInfo)

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
ExpPars.averages = DataInfo.NAve;
%--
ExpPars.FirstSampDelay = ExpPars.Sequence.te;                       % te might actually be associated with a later sampling point
%--

%---------------------------------------------
% Other Info
%---------------------------------------------
ExpPars.Sequence.expulselen = test1{31};
ExpPars.Sequence.refpulselen = test1{32};
ExpPars.Sequence.rdwn = test1{33};
if isempty(ExpPars.Sequence.rdwn)
    ExpPars.Sequence.rdwn = 0;
end
ExpPars.Sequence.trbuf = test1{34};
if isempty(ExpPars.Sequence.trbuf)
    ExpPars.Sequence.trbuf = 0;
end

ExpPars.Sequence.crushdur = test1{51};
ExpPars.Sequence.crushmag = test1{52};
ExpPars.Sequence.crushslew = test1{53};
ExpPars.Sequence.crushbuff = test1{54};

ExpPars.Sequence.dummies = test1{36};
ExpPars.Sequence.fatsatdur = test1{37};
ExpPars.Sequence.fatsatfreq = test1{38};
ExpPars.Sequence.fatsatflip = test1{39};
ExpPars.Sequence.fatsattbw = test1{40};
ExpPars.Sequence.fatsatdel = test1{41};

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
        ExpPars.shift(2) = 0;
        ExpPars.shift(3) = 0; 
    end
else
    ExpPars.shift(1) = 0;
    ExpPars.shift(2) = 0;
    ExpPars.shift(3) = 0; 
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
Panel(8,:) = {'Averages',ExpPars.averages,'Output'};
Panel(9,:) = {'','','Output'};
Panel(10,:) = {'ExPulseLen (us)',ExpPars.Sequence.expulselen,'Output'};
Panel(11,:) = {'RefPulseLen (us)',ExpPars.Sequence.refpulselen,'Output'};
Panel(12,:) = {'rdwn (us)',ExpPars.Sequence.rdwn,'Output'};
Panel(13,:) = {'trbuf (us)',ExpPars.Sequence.trbuf,'Output'};
Panel(14,:) = {'','','Output'};
Panel(15,:) = {'CrushDur (us)',ExpPars.Sequence.crushdur,'Output'};
Panel(16,:) = {'CrushMag (mT/m)',ExpPars.Sequence.crushmag,'Output'};
Panel(17,:) = {'CrushSlew (mT/m/ms)',ExpPars.Sequence.crushslew,'Output'};
Panel(18,:) = {'CrushBuff (us)',ExpPars.Sequence.crushbuff,'Output'};
Panel(19,:) = {'','','Output'};
Panel(20,:) = {'Dummies',ExpPars.Sequence.dummies,'Output'};
Panel(21,:) = {'FatSatDur (us)',ExpPars.Sequence.fatsatdur,'Output'};
Panel(22,:) = {'FatSatFreq (Hz)',ExpPars.Sequence.fatsatfreq,'Output'};
Panel(23,:) = {'FatSatFlip (deg)',ExpPars.Sequence.fatsatflip,'Output'};
Panel(24,:) = {'FatSatTbw',ExpPars.Sequence.fatsattbw,'Output'};
Panel(25,:) = {'FatSatDel (us)',ExpPars.Sequence.fatsatdel,'Output'};
Panel(26,:) = {'','','Output'};
Panel(27,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
Panel(28,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
Panel(29,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};

PanelOutput = cell2struct(Panel,{'label','value','type'},2);

% Status2('done','',2);       

