%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = TIRnss_v1k_SeqDat(MrProt,DataInfo)

err.flag = 0;
err.msg = '';

Status2('busy','Load ''TIRnss'' Sequence Info',2);

%---------------------------------------------
% Read Trajectory
%---------------------------------------------    
sWipMemBlock = MrProt.sWipMemBlock;
test1 = sWipMemBlock.alFree;
test2 = sWipMemBlock.adFree;
fov = num2str(test1{21});
vox = num2str(round(test1{22}*test1{23}*test1{24}/1e8));
voxarr = [test1{22} test1{23} test1{24}];
ind = find(voxarr == max(voxarr),1,'first');
if ind == 1
    elip = num2str(100*test1{23}/test1{22});
elseif ind == 2
    elip = num2str(100*test1{22}/test1{23}); 
elseif ind == 3
    elip = num2str(100*test1{22}/test1{24}); 
end
tro = num2str(round(10*test2{5}));
nproj = num2str(test1{6});
p = num2str(test1{25});
id = num2str(test1{26});
ExpPars.TrajName = ['TPI_F',fov,'_V',vox,'_E',elip,'_T',tro,'_N',nproj,'_P',p,'_ID',id];
ExpPars.TrajImpName = ExpPars.TrajName;

%---------------------------------------------
% Sequence Info
%---------------------------------------------
ExpPars.scantime = MrProt.lTotalScanTimeSec;
ExpPars.Sequence.flip = MrProt.adFlipAngleDegree{1};             % in degrees
ExpPars.Sequence.tr = MrProt.alTR{1}/1e3;                        % in ms
ExpPars.Sequence.te = MrProt.alTE{1}/1e3;                        % in ms
ExpPars.Sequence.ti = MrProt.alTI{1}/1e3;                        % in ms
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
ExpPars.Sequence.invpulselen = test1{33};
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
Panel(7,:) = {'TI (ms)',ExpPars.Sequence.ti,'Output'};
Panel(8,:) = {'Flip (degrees)',ExpPars.Sequence.flip,'Output'};
Panel(9,:) = {'Averages',ExpPars.averages,'Output'};
Panel(10,:) = {'','','Output'};
Panel(11,:) = {'rfexdur (us)',ExpPars.Sequence.rfpulselen,'Output'};
Panel(12,:) = {'rfinvdur (us)',ExpPars.Sequence.invpulselen,'Output'};
Panel(13,:) = {'rdwn (us)',ExpPars.Sequence.rdwn,'Output'};
Panel(14,:) = {'flamplitude',ExpPars.Sequence.flamplitude,'Output'};
Panel(15,:) = {'rfspoil (deg)',ExpPars.Sequence.rfspoil,'Output'};
Panel(16,:) = {'','','Output'};
Panel(17,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
Panel(18,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
Panel(19,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};
PanelOutput = cell2struct(Panel,{'label','value','type'},2);

Status2('done','',2);       

