
DatFile = 'I:\24100314 (YarnLungRws)\meas_MID00158_FID29466_YessN9800A10.dat';
DataObj = SiemensStitchItDataObject(DatFile);
DataObj.Initialize;

TrajMashObj = TrajMashEndExp2a();
TrajMashObj.SetAtExpirationFrac(0.25);              % The 'fraction of the respiration cycle' included as expiration  

ReconObj = ReconLungNufftV2a();   
ReconObj.SetBaseMatrix(300);                        % Whatever zero-fill you are after...
ReconObj.SetTrajMashObj(TrajMashObj);

load('E:\RichLungs\F600_V0270_E100_T010_N9800_SU70_1O_D0_ZXY\YB_F600_V270_E100_T10_N98000_P223_S1070_ID24100211.mat','saveData');
ReconObj.SetAcqInfo(saveData.WRT.STCH);
ReconObj.SetAcqInfoRxp(saveData.WRT.STCHRXP);

Image = ReconObj.CreateImage(DataObj);
Test = 0;