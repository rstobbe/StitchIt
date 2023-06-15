function Out = StitchItLsqrTikFunc(In,Transp,Nufft,SzIm,SzData,Opt)

switch Transp
    case 'notransp'
        Tik = Opt.Lambda * In;
        In = reshape(In,SzIm);
        Out = Nufft.Forward(In);
        Out = Out(:);
        Out = [Out(:); Tik]; 
    case 'transp'
        Tik = In(prod(SzData)+1:end);
        In = In(1:prod(SzData));
        In = reshape(In,SzData);
        Out = Nufft.Inverse(In);
        Out = Out(:);
        Out = Out + Opt.Lambda*Tik;
end   


