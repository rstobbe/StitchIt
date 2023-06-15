function Out = StitchItLsqrWavFunc(In,Transp,Nufft)

switch Transp
    case 'notransp'
        Out = Nufft.Forward(In);
    case 'transp'
        Out = Nufft.Inverse(In); 
end   


