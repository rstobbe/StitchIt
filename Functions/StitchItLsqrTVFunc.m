function Out = StitchItLsqrTVFunc(In,Transp,Nufft,SzIm,SzData,Opt)

switch Transp
    case 'notransp'
        In = reshape(In,SzIm);
        Sobel(:,:,1) = [ 1  3  1;  3  6  3;  1  3  1];
        Sobel(:,:,2) = [ 0  0  0;  0  0  0;  0  0  0];
        Sobel(:,:,3) = [-1 -3 -1; -3 -6 -3; -1 -3 -1];
        Gz2 = convn(In,Sobel,'same');
        Gy2 = convn(In,permute(Sobel,[2 3 1]),'same');
        Gx2 = convn(In,permute(Sobel,[3 2 1]),'same');
        Gmag = (Gx2.^2 + Gy2.^2 + Gz2.^2).^0.5;
%         Gmag = imgradient3(abs(In));
        TV = Opt.Lambda * Gmag;
        TV = TV(:);
        Out = Nufft.Forward(In);
        Out = Out(:);
        Out = [Out(:); TV]; 
    case 'transp'
        TV = In(prod(SzData)+1:end);
        In = In(1:prod(SzData));
        In = reshape(In,SzData);
        Out = Nufft.Inverse(In);
        Out = Out(:);
        Out = Out + Opt.Lambda*TV;
end   


