function zz_StitchMatlabCompileSpecific

CC = '61';
Lib = ['CUDA',CC,'_Library250704_124.lib'];

CUDApath = getenv('CUDA_PATH');   
CUDApath = [CUDApath,'\lib\x64'];
CUDAlib = cd;

File = 'PhaseAddFatOffResonance.cpp';

[Path,Name,Ext] = fileparts(File);
if not(strcmp(Ext,'.cpp'))
    error
end
Output = [File(1:end-4),CC];
mex('-R2018a',...                                     
    ['-I',CUDAlib], ...
    ['-L',CUDApath],'-lcudart','-lcufft', ... 
    ['-L',CUDAlib], ...
    ['-l',Lib], ...
    '-output',Output, ...
    File);      




