function zz_StitchMatlabCompile

CC = '89';
Lib = ['CUDA',CC,'_Library230823_113.lib'];

CUDApath = getenv('CUDA_PATH_V11_3');      
CUDApath = [CUDApath,'\lib\x64'];
CUDAlib = cd;

listing = dir;
for n = 1:length(listing)   
    if listing(n).isdir
        continue
    end
    File = listing(n).name;
    [Path,Name,Ext] = fileparts(File);
    if not(strcmp(Ext,'.cpp'))
        continue
    end
    Output = [File(1:end-4),CC];
    mex('-R2018a',...                                     
        ['-I',CUDAlib], ...
        ['-L',CUDApath],'-lcudart','-lcufft', ... 
        ['-L',CUDAlib], ...
        ['-l',Lib], ...
        '-output',Output, ...
        File);      
end



