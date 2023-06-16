function DATA = ReadSiemensDataInfo(DATA,filename)

fid = fopen(filename,'r','l','US-ASCII');
fseek(fid,0,'bof');

firstInt  = fread(fid,1,'uint32');
secondInt = fread(fid,1,'uint32');

if not(and(firstInt < 10000, secondInt <= 64))
    error
end

byteMdh = 184;
szScanHeader    = 192; 
szChannelHeader =  32; 

%-----------------------------------------------------
% Header Stuff
%-----------------------------------------------------
NScans = secondInt;
MeasId = fread(fid,1,'uint32');
FileId = fread(fid,1,'uint32');
MeasOffset = fread(fid,1,'uint64');             % points to beginning of header, usually at 10240 bytes

%-----------------------------------------------------
% Find relevant scan(s)
%-----------------------------------------------------
cPos = MeasOffset;
for n = 1:NScans
    fseek(fid,cPos,'bof');
    HdrLen = fread(fid,1,'uint32');
    Hdr0 = ReadHeaderPhoenixConfig(DATA,fid);
    HdrArr{n} = Hdr0.Phoenix;
    ConfigArr{n} = Hdr0.Config;
    cPos = cPos + HdrLen;
    DataPos(n) = cPos;
    if n < NScans
        fseek(fid,cPos,'bof');
        [~,filePos,~] = loop_mdh_read(fid,'vd');
        cPos = filePos(end);
    end
end

%-----------------------------------------------------
% Test for valid scan
%-----------------------------------------------------
GoodSeq = [];
for n = 1:length(DataPos)
    fseek(fid,DataPos(n),'bof');
    MdhTemp = fread(fid,byteMdh,'uint8=>uint8');
    MdhTemp = MdhTemp([1:20 41:end],:);     
    Mdh = EvalMdh(MdhTemp);
    test = sum(Mdh.sLC);
    if test == 0
        GoodSeq = [GoodSeq n];
    end
end
if isempty(GoodSeq)
    error('A valid sequence was not found');
end
GoodSeqTest = [];
for n = 1:length(GoodSeq)
    HdrTemp = HdrArr{GoodSeq(n)};
    Seq = HdrTemp.tSequenceFileName;
    Seq = char(Seq);
    Seq = Seq(15:end);
    if exist([Seq,'_SeqDat'],'file')
        GoodSeqTest = [GoodSeqTest GoodSeq(n)];
    end
end                
if isempty(GoodSeqTest)
    error('A valid sequence was not found');
end
if length(GoodSeqTest) > 1
    %--------
    %error('This .dat file contains two yarnball sequences');
    GoodSeqTest = 2;                                                % hack
    %--------
end
GoodSeq = GoodSeqTest;
Hdr = HdrArr{GoodSeq};
Config = ConfigArr{GoodSeq};

%-----------------------------------------------------
% Read First Mdh
%-----------------------------------------------------
fseek(fid,DataPos(GoodSeq),'bof');
%=====================================================
[~,filePos,~] = loop_mdh_read(fid,'vd');                % Accomodate possible inclusion of SyncData - 230428
fseek(fid,filePos(1),'bof');
%=====================================================
MdhTemp = fread(fid,byteMdh,'uint8=>uint8');
MdhTemp = MdhTemp([1:20 41:end],:);     
Mdh = EvalMdh(MdhTemp);
sLC             = double(Mdh.sLC ) + 1;  
Dims.NCol       = double(Mdh.ushSamplesInScan).';
Dims.NCha       = double(Mdh.ushUsedChannels).';
Dims.NAve       = sLC(:,2).' ;
Dims.Sli        = sLC(:,3).' ;
Dims.Par        = sLC(:,4).' ;
Dims.Eco        = sLC(:,5).' ;
Dims.Phs        = sLC(:,6).' ;
Dims.Rep        = sLC(:,7).' ;
Dims.Set        = sLC(:,8).' ;
Dims.Seg        = sLC(:,9).' ;
Dims.Ida        = sLC(:,10).';
Dims.Idb        = sLC(:,11).';
Dims.Idc        = sLC(:,12).';
Dims.Idd        = sLC(:,13).';
Dims.Ide        = sLC(:,14).';

%-----------------------------------------------------
% Determine Memory Positions
%-----------------------------------------------------
DataSegLength = szScanHeader + (8*Dims.NCol + szChannelHeader) * Dims.NCha;
%=====================================================
% fseek(fid,0,'eof');
% filesize = ftell(fid);
% Dims.Lin = floor((filesize - cPos)/DataSegLength);
% Mem.Pos = (cPos:DataSegLength:filesize-DataSegLength);
Dims.Lin = length(filePos)-1;                           % Accomodate possible inclusion of SyncData - 230428
Mem.Pos = filePos(1:end-1);
%=====================================================
Mem.DataSegLength = DataSegLength;
fclose(fid);

%-----------------------------------------------------
% Determine Sequence
%-----------------------------------------------------
Seq = Hdr.tSequenceFileName;
Seq = char(Seq);
Seq = Seq(15:end);

%-----------------------------------------------------
% Stuff
%-----------------------------------------------------
Protocol = Hdr.tProtocolName;
Protocol = char(Protocol);
Protocol = Protocol(1:end);
if strcmp(Config.PatientName(1:2),'xx')
    VolunteerID = Config.Patient;
else 
    VolunteerID = Config.PatientName;
end 
Panel(1,:) = {'','','Output'};
Panel(2,:) = {'VolunteerID',['"',VolunteerID,'"'],'Output'};
Panel(3,:) = {'Protocol',Protocol,'Output'};
Panel(4,:) = {'Sequence',Seq,'Output'};
ind = strfind(filename,'\');
Panel(5,:) = {'File',filename(ind(end)+1:end),'Output'};
PanelOutput0 = cell2struct(Panel,{'label','value','type'},2);

%---------------------------------------------
% Trajectory Set
%---------------------------------------------
func = str2func([Seq,'_SeqDat']);
[ExpPars,PanelOutput,err] = func(Hdr,Dims);
PanelOutput = [PanelOutput0;PanelOutput];
ExpDisp = PanelStruct2Text(PanelOutput);

%---------------------------------------------
% Return
%---------------------------------------------
Info.ExpPars = ExpPars;
Info.ExpDisp = ExpDisp;
Info.PanelOutput = PanelOutput;
Info.Seq = Seq;
Info.Protocol = Protocol;
Info.VolunteerID = VolunteerID;
Info.TrajName = ExpPars.TrajName;    
Info.RxChannels = Dims.NCha;

DATA.DataHdr = Hdr;
DATA.DataDims = Dims;
DATA.DataMem = Mem;
DATA.DataInfo = Info;


end



%==============================================================================
% From mapVBVD
%==============================================================================

function [mdh,mask] = EvalMdh(MdhTemp)
% see pkg/MrServers/MrMeasSrv/SeqIF/MDH/mdh.h
% and pkg/MrServers/MrMeasSrv/SeqIF/MDH/MdhProxy.h

if ~isa( MdhTemp, 'uint8' )
    error( [mfilename() ':NoInt8'], 'Binary mdh data must be a uint8 array!' )
end
Nmeas   = size( MdhTemp, 2 );

mdh.ulPackBit   = bitget( MdhTemp(4,:), 2).';
mdh.ulPCI_rx    = bitset(bitset(MdhTemp(4,:), 7, 0), 8, 0).'; % keep 6 relevant bits
MdhTemp(4,:)   = bitget( MdhTemp(4,:),1);  % ubit24: keep only 1 bit from the 4th byte

% unfortunately, typecast works on vectors, only
data_uint32     = typecast( reshape(MdhTemp(1:76,:),  [],1), 'uint32' );
data_uint16     = typecast( reshape(MdhTemp(29:end,:),[],1), 'uint16' );
data_single     = typecast( reshape(MdhTemp(69:end,:),[],1), 'single' );

data_uint32 = reshape( data_uint32, [], Nmeas ).';
data_uint16 = reshape( data_uint16, [], Nmeas ).';
data_single = reshape( data_single, [], Nmeas ).';

%  byte pos.
%mdh.ulDMALength               = data_uint32(:,1);      %   1 :   4
mdh.lMeasUID                   = data_uint32(:,2);      %   5 :   8
mdh.ulScanCounter              = data_uint32(:,3);      %   9 :  12
mdh.ulTimeStamp                = data_uint32(:,4);      %  13 :  16
mdh.ulPMUTimeStamp             = data_uint32(:,5);      %  17 :  20
mdh.aulEvalInfoMask            = data_uint32(:,6:7);    %  21 :  28
mdh.ushSamplesInScan           = data_uint16(:,1);      %  29 :  30
mdh.ushUsedChannels            = data_uint16(:,2);      %  31 :  32
mdh.sLC                        = data_uint16(:,3:16);   %  33 :  60
mdh.sCutOff                    = data_uint16(:,17:18);  %  61 :  64
mdh.ushKSpaceCentreColumn      = data_uint16(:,19);     %  66 :  66
mdh.ushCoilSelect              = data_uint16(:,20);     %  67 :  68
mdh.fReadOutOffcentre          = data_single(:, 1);     %  69 :  72
mdh.ulTimeSinceLastRF          = data_uint32(:,19);     %  73 :  76
mdh.ushKSpaceCentreLineNo      = data_uint16(:,25);     %  77 :  78
mdh.ushKSpaceCentrePartitionNo = data_uint16(:,26);     %  79 :  80

mdh.SlicePos                    = data_single(:, 4:10); %  81 : 108
mdh.aushIceProgramPara          = data_uint16(:,41:64); % 109 : 156
mdh.aushFreePara                = data_uint16(:,65:68); % 157 : 164

% inlining of evalInfoMask
evalInfoMask1 = mdh.aulEvalInfoMask(:,1);
mask.MDH_ACQEND             = min(bitand(evalInfoMask1, 2^0), 1);
mask.MDH_RTFEEDBACK         = min(bitand(evalInfoMask1, 2^1), 1);
mask.MDH_HPFEEDBACK         = min(bitand(evalInfoMask1, 2^2), 1);
mask.MDH_SYNCDATA           = min(bitand(evalInfoMask1, 2^5), 1);
mask.MDH_RAWDATACORRECTION  = min(bitand(evalInfoMask1, 2^10),1);
mask.MDH_REFPHASESTABSCAN   = min(bitand(evalInfoMask1, 2^14),1);
mask.MDH_PHASESTABSCAN      = min(bitand(evalInfoMask1, 2^15),1);
mask.MDH_SIGNREV            = min(bitand(evalInfoMask1, 2^17),1);
mask.MDH_PHASCOR            = min(bitand(evalInfoMask1, 2^21),1);
mask.MDH_PATREFSCAN         = min(bitand(evalInfoMask1, 2^22),1);
mask.MDH_PATREFANDIMASCAN   = min(bitand(evalInfoMask1, 2^23),1);
mask.MDH_REFLECT            = min(bitand(evalInfoMask1, 2^24),1);
mask.MDH_NOISEADJSCAN       = min(bitand(evalInfoMask1, 2^25),1);
mask.MDH_VOP                = min(bitand(mdh.aulEvalInfoMask(2), 2^(53-32)),1); % was 0 in VD

mask.MDH_IMASCAN            = ones( Nmeas, 1, 'uint32' );

noImaScan = (   mask.MDH_ACQEND             | mask.MDH_RTFEEDBACK   | mask.MDH_HPFEEDBACK       ...
              | mask.MDH_PHASCOR            | mask.MDH_NOISEADJSCAN | mask.MDH_PHASESTABSCAN    ...
              | mask.MDH_REFPHASESTABSCAN   | mask.MDH_SYNCDATA                                 ... 
              | (mask.MDH_PATREFSCAN & ~mask.MDH_PATREFANDIMASCAN) );

mask.MDH_IMASCAN( noImaScan ) = 0;

end % of evalMDH()

function [mdh_blob, filePos, isEOF] = loop_mdh_read( fid, version )
% Goal of this function is to gather all mdhs in the dat file and store them
% in binary form, first. This enables us to evaluate and parse the stuff in
% a MATLAB-friendly (vectorized) way. We also yield a clear separation between
% a lengthy loop and other expressions that are evaluated very few times.
%
% The main challenge is that we never know a priori, where the next mdh is
% and how many there are. So we have to actually evaluate some mdh fields to
% find the next one.
%
% All slow things of the parsing step are found in the while loop.
% => It is the (only) place where micro-optimizations are worthwhile.
%
% The current state is that we are close to sequential disk I/O times.
% More fancy improvements may be possible by using workers through parfeval()
% or threads using a java class (probably faster + no toolbox):
% http://undocumentedmatlab.com/blog/explicit-multi-threading-in-matlab-part1

    switch version
        case 'vb'
            isVD    = false;
            byteMDH = 128;
        case 'vd'
            isVD    = true;
            byteMDH = 184;
            szScanHeader    = 192; % [bytes]
            szChannelHeader =  32; % [bytes]
        otherwise
            % arbitrary assumptions:
            isVD    = false;
            byteMDH = 128;
            warning( [mfilename() ':UnknownVer'], 'Software version "%s" is not supported.', version );
    end

    cPos            = ftell(fid);
    n_acq           = 0;
    allocSize       = 4096;
    ulDMALength     = byteMDH;
    isEOF           = false;
    percentFinished = 0;
    progress_str    = '';
    prevLength      = numel( progress_str );

    mdh_blob = zeros( byteMDH, 0, 'uint8' );
    szBlob   = size( mdh_blob, 2 );
    filePos  = zeros(0, 1, 'like', cPos);  % avoid bug in Matlab 2013b: https://scivision.co/matlab-fseek-bug-with-uint64-offset/

    % get file size
    fseek(fid,0,'eof');
    fileSize = ftell(fid);
    fseek(fid,cPos,'bof');

    % ======================================
    %   constants and conditional variables
    % ======================================
        bit_0 = uint8(2^0);
        bit_5 = uint8(2^5);
        mdhStart = 1-byteMDH;
        
        u8_000 = zeros( 3, 1, 'uint8'); % for comparison with data_u8(1:3)

        % 20 fill bytes in VD (21:40)
        evIdx   = uint8(    21  + 20*isVD); % 1st byte of evalInfoMask
        dmaIdx  = uint8((29:32) + 20*isVD); % to correct DMA length using NCol and NCha
        if isVD
            dmaOff  = szScanHeader;
            dmaSkip = szChannelHeader;
        else
            dmaOff  = 0;
            dmaSkip = byteMDH;
        end
    % ======================================

    t0 = tic;
    while true
        % Read mdh as binary (uint8) and evaluate as little as possible to know...
        %   ... where the next mdh is (ulDMALength / ushSamplesInScan & ushUsedChannels)
        %   ... whether it is only for sync (MDH_SYNCDATA)
        %   ... whether it is the last one (MDH_ACQEND)
        % evalMDH() contains the correct and readable code for all mdh entries.
        try
            % read everything and cut out the mdh
            data_u8 = fread( fid, ulDMALength, 'uint8=>uint8' );
            data_u8 = data_u8( mdhStart+end :  end );
        catch exc
            warning( [mfilename() ':UnxpctdEOF'],  ...
                      [ '\nAn unexpected read error occurred at this byte offset: %d (%g GiB)\n'...
                        'Will stop reading now.\n'                                             ...
                        '=== MATLABs error message ================\n'                         ...
                        exc.message                                                            ...
                        '\n=== end of error =========================\n'                       ...
                       ], cPos, cPos/1024^3 )
            isEOF = true;
            break
        end

        bitMask = data_u8(evIdx);   % the initial 8 bit from evalInfoMask are enough

        if   isequal( data_u8(1:3), u8_000 )    ... % probably ulDMALength == 0
          || bitand(bitMask, bit_0);                % MDH_ACQEND

            % ok, look closer if really all *4* bytes are 0:
            data_u8(4)= bitget( data_u8(4),1);  % ubit24: keep only 1 bit from the 4th byte
            ulDMALength = double( typecast( data_u8(1:4), 'uint32' ) );

            if ulDMALength == 0 || bitand(bitMask, bit_0)
                cPos = cPos + ulDMALength;
                % jump to next full 512 bytes
                if mod(cPos,512)
                    cPos = cPos + 512 - mod(cPos,512);
                end
                break;
            end
        end
        if bitand(bitMask, bit_5);  % MDH_SYNCDATA
            data_u8(4)= bitget( data_u8(4),1);  % ubit24: keep only 1 bit from the 4th byte
            ulDMALength = double( typecast( data_u8(1:4), 'uint32' ) );
            cPos = cPos + ulDMALength;
            continue
        end

        % pehses: the pack bit indicates that multiple ADC are packed into one
        % DMA, often in EPI scans (controlled by fRTSetReadoutPackaging in IDEA)
        % since this code assumes one adc (x NCha) per DMA, we have to correct
        % the "DMA length"
        %     if mdh.ulPackBit
        % it seems that the packbit is not always set correctly
        NCol_NCha = double( typecast( data_u8(dmaIdx), 'uint16' ) );  % [ushSamplesInScan  ushUsedChannels]
        ulDMALength = dmaOff + (8*NCol_NCha(1) + dmaSkip) * NCol_NCha(2);

        n_acq = n_acq + 1;

        % grow arrays in batches
        if n_acq > szBlob
            mdh_blob( :, end + allocSize ) = 0;
            filePos( end + allocSize ) = 0;
            szBlob = size( mdh_blob, 2 );
        end
        mdh_blob(:,n_acq) = data_u8;
        filePos( n_acq )  = cPos;

        if (100*cPos)/fileSize > percentFinished + 1
            percentFinished = floor((100*cPos)/fileSize);
            elapsed_time    = toc(t0);
            time_left       = (fileSize/cPos-1) * elapsed_time;
            prevLength      = numel(progress_str);
            progress_str    = sprintf('    %3.0f %% read in %4.0f s; estimated time left: %4.0f s \n',...
                                      percentFinished,elapsed_time, time_left);
            %fprintf([repmat('\b',1,prevLength) '%s'],progress_str);
        end

        cPos = cPos + ulDMALength;
    end % while true

    if isEOF
        n_acq = n_acq-1;    % ignore the last attempt
    end

    filePos( n_acq+1 ) = cPos;  % save pointer to the next scan

    % discard overallocation:
    mdh_blob = mdh_blob(:,1:n_acq);
    filePos  = reshape( filePos(1:n_acq+1), 1, [] ); % row vector

    prevLength   = numel(progress_str) * (~isEOF);
    elapsed_time = toc(t0);
    progress_str = sprintf('    100 %% read in %4.0f s; estimated time left:    0 s \n', elapsed_time);
    %fprintf([repmat('\b',1,prevLength) '%s'],progress_str);

end % of loop_mdh_read()

