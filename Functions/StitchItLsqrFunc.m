function Out = StitchItLsqrFunc(In,Transp,Nufft,SzIm,SzData)

switch Transp
    case 'notransp'
        In = reshape(In,SzIm);
        Out = Nufft.Forward(In);
        Out = Out(:);
    case 'transp'
        In = reshape(In,SzData);
        Out = Nufft.Inverse(In); 
        Out = Out(:);
end   


