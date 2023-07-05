%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = LRwfmTest_v1b_SeqDat(MrProt,DataInfo)

err.flag = 0;
err.msg = '';

Status2('busy','Load ''LRwfmTest'' Sequence Info',2);

%---------------------------------------------
% Read Trajectory
%---------------------------------------------    
sWipMemBlock = MrProt.sWipMemBlock;
test1 = sWipMemBlock.alFree;
test2 = sWipMemBlock.adFree;
if test1{3} == 10
    type = 'Traj';
elseif test1{3} == 20
    type = 'BP';
elseif test1{3} == 21
    type = 'PC';    
end
GradTestId = num2str(test1{4});
if test1{5} == 1
    dir = 'X';
elseif test1{5} == 2
    dir = 'Y';
elseif test1{5} == 3
    dir = 'Z';
end         
ExpPars.tro = test2{6};
ExpPars.nproj = test1{7};
if test1{13} == 1
    ExpPars.GradTestPos = 'Left';
elseif test1{13} == 2
    ExpPars.GradTestPos = 'Right';
elseif test1{13} == 3
    ExpPars.GradTestPos = 'Up';
elseif test1{13} == 4
    ExpPars.GradTestPos = 'Down';
elseif test1{13} == 5
    ExpPars.GradTestPos = 'In';
elseif test1{13} == 6
    ExpPars.GradTestPos = 'Out';
end 
ExpPars.TrajName = [type,GradTestId,dir];
ExpPars.TrajImpName = ['IMP_',type,GradTestId,dir];

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
ExpPars.Sequence.rfspoil = test2{10};

%---------------------------------------------
% Testing Info
%---------------------------------------------
ExpPars.Sequence.flamplitude = MrProt.sTXSPEC.aRFPULSE{1}.flAmplitude;

%--------------------------------------------
% Panel
%--------------------------------------------
Panel(1,:) = {'','','Output'};
Panel(2,:) = {'Trajectory',ExpPars.TrajName,'Output'};
Panel(3,:) = {'Scan Time (seconds)',ExpPars.scantime,'Output'};
Panel(4,:) = {'TR (ms)',ExpPars.Sequence.tr,'Output'};
Panel(5,:) = {'TE (ms)',ExpPars.Sequence.te,'Output'};
Panel(6,:) = {'Flip (degrees)',ExpPars.Sequence.flip,'Output'};
Panel(7,:) = {'FlipAmplitude',ExpPars.Sequence.flamplitude,'Output'};
Panel(8,:) = {'RfDuration (us)',ExpPars.Sequence.rfpulselen,'Output'};
Panel(9,:) = {'RingDown (us)',ExpPars.Sequence.rdwn,'Output'};
Panel(10,:) = {'Averages',ExpPars.averages,'Output'};
Panel(11,:) = {'GradTestPos',ExpPars.GradTestPos,'Output'};
PanelOutput = cell2struct(Panel,{'label','value','type'},2);

Status2('done','',2);       

