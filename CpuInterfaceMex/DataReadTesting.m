DataFile = 'D:\StitchTesting\meas_MID00685_FID123679_YB_RO3_VOX25_BH.dat';
N = 100000;

DataMemPosArr = uint64(N*(1:5000));

DataReadSize = 15050;
DataStart = 9;
DataCol = 15000;
DataCha = 60;
DataInfo = uint64([DataReadSize DataStart DataCol DataCha]); 

tic
Data = BuildDataArray(DataFile,DataMemPosArr,DataInfo);
test = size(Data)
test = Data(5:200)
toc