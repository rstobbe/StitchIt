%=========================================================
% 
%=========================================================

function [ExpPars,PanelOutput,err] = TUTEnss_v1k_SeqDat(MrProt,DataInfo)

err.flag = 0;
err.msg = '';

% Status2('busy','Load ''TUTEnss'' Sequence Info',2);

%---------------------------------------------
% Read Trajectory
%---------------------------------------------    
sWipMemBlock = MrProt.sWipMemBlock;
test1 = sWipMemBlock.alFree;
test2 = sWipMemBlock.adFree;
fov = num2str(test1{21});
vox = num2str(round(test1{22}*test1{23}*test1{24}/1e8));
voxarr = [test1{22} test1{23} test1{24}];
% ind = find(voxarr == max(voxarr),1,'first');
ind = 3;
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
ExpPars.rcvrs = DataInfo.NCha;
ExpPars.averages = DataInfo.NAve;
%--
ExpPars.FirstSampDelay = '';                       
%--

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
ExpPars.Sequence.rfspoil = test2{10};

%---------------------------------------------
% Testing Info
%---------------------------------------------
% ExpPars.Sequence.flamplitude = MrProt.sTXSPEC.aRFPULSE{1}.flAmplitude;
ExpPars.Sequence.flamplitude = 'NaN';

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
% Other Parameters
%--------------------------------------------
% ShimVals = cell(1,9);
% ShimVals{1} = MrProt.sGRADSPEC.asGPAData{1}.lOffsetX;
% ShimVals{2} = MrProt.sGRADSPEC.asGPAData{1}.lOffsetY;
% ShimVals{3} = MrProt.sGRADSPEC.asGPAData{1}.lOffsetZ;
% ShimVals0 = [];
% if isfield(MrProt.sGRADSPEC,'alShimCurrent')
%     ShimVals0 = MrProt.sGRADSPEC.alShimCurrent;
% end
% ShimVals(4:3+length(ShimVals0)) = ShimVals0;
% Freq = MrProt.sTXSPEC.asNucleusInfo{1}.lFrequency;
% Ref = MrProt.sProtConsistencyInfo.flNominalB0 * 42577000;
% tof = Freq - Ref;
% ShimVals(9) = {tof};
% ShimNames = {'x','y','z','z2','zx','zy','x2y2','xy','tof'};
% % ShimValsUI{1} = ShimVals{1}/6.259;
% % ShimValsUI{2} = ShimVals{2}/6.2465;
% % ShimValsUI{3} = ShimVals{3}/6.108;
% % ShimValsUI{4} = ShimVals{4}/2.016;
% % ShimValsUI{5} = ShimVals{5}/2.815;
% % ShimValsUI{6} = ShimVals{6}/2.853;
% % ShimValsUI{7} = ShimVals{7}/2.815;
% % ShimValsUI{8} = ShimVals{8}/2.866;
% ShimValsUI{1} = ShimVals{1}/6.2587;
% ShimValsUI{2} = ShimVals{2}/6.2463;
% ShimValsUI{3} = ShimVals{3}/6.1081;
% ShimValsUI{4} = ShimVals{4}/2.0146;
% ShimValsUI{5} = ShimVals{5}/2.7273;
% ShimValsUI{6} = ShimVals{6}/2.8389;
% ShimValsUI{7} = ShimVals{7}/2.8049;
% ShimValsUI{8} = ShimVals{8}/2.7928;
% ShimValsUI{9} = ShimVals{9}

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
Panel(15,:) = {'','','Output'};
Panel(16,:) = {'Shift1 (mm)',ExpPars.shift(1),'Output'};
Panel(17,:) = {'Shift2 (mm)',ExpPars.shift(2),'Output'};
Panel(18,:) = {'Shift3 (mm)',ExpPars.shift(3),'Output'};
PanelOutput = cell2struct(Panel,{'label','value','type'},2);

% Status2('done','',2);       

