%================================================================
% StitchIt
%   
%================================================================

classdef StitchIt < handle

    properties (SetAccess = private)                                     
        ItNum
        Nufft
        DispBytes
        DispImage
        DispImageStep = 10   
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchIt(Nufft)
            obj.ItNum = 1;
            obj.Nufft = Nufft;
        end 

%==================================================================
% ResetCounter
%==================================================================   
        function ResetCounter(obj)
            obj.ItNum = 1;
        end         

%==================================================================
% SetDispImageStep
%==================================================================   
        function SetDispImageStep(obj,val)
            obj.DispImageStep = val;
        end             

%==================================================================
% Standard
%==================================================================           
        function Out = Standard(obj,In,Transp)
            switch Transp
                case 'notransp'
                    %obj.DisplayImage(In);
                    Out = obj.Nufft.Forward(In);
                case 'transp'
                    Out = obj.Nufft.Inverse(In); 
                    obj.DisplayCount;
                    %obj.DisplayImage(Out);
            end   
        end        
        
%==================================================================
% Vectored
%==================================================================           
        function Out = Vectored(obj,In,Transp,SzIm,SzData)
            switch Transp
                case 'notransp'
                    In = reshape(In,SzIm);
                    %obj.DisplayImage(In);
                    Out = obj.Nufft.Forward(In);
                    Out = Out(:);
                case 'transp'
                    In = reshape(In,SzData);
                    Out = obj.Nufft.Inverse(In); 
                    obj.DisplayCount;
                    %obj.DisplayImage(Out);
                    Out = Out(:);
            end
        end

%==================================================================
% VectoredTik
%==================================================================           
        function Out = VectoredTik(obj,In,Transp,SzIm,SzData,Opt)
            switch Transp
                case 'notransp'
                    Tik = Opt.Lambda * In;
                    In = reshape(In,SzIm);
                    %obj.DisplayImage(In);
                    Out = obj.Nufft.Forward(In);
                    Out = Out(:);
                    Out = [Out(:); Tik]; 
                case 'transp'
                    Tik = In(prod(SzData)+1:end);
                    In = In(1:prod(SzData));
                    In = reshape(In,SzData);
                    Out = obj.Nufft.Inverse(In);
                    obj.DisplayCount;
                    %obj.DisplayImage(Out);
                    Out = Out(:);
                    Out = Out + Opt.Lambda*Tik;
            end   
        end        
 
%==================================================================
% LsqrTikVec
%==================================================================           
        function Out = LsqrTikVec(obj,In,Transp,SzIm,SzData,Opt)
            switch Transp
                case 'notransp'
                    Tik = Opt.Lambda * In;
                    In = reshape(In,SzIm);
                    %obj.DisplayImage(In);
                    Out = obj.Nufft.Forward(In);
                    Out = Out(:);
                    Out = [Out(:); Tik]; 
                case 'transp'
                    Tik = In(prod(SzData)+1:end);
                    In = In(1:prod(SzData));
                    In = reshape(In,SzData);
                    Out = obj.Nufft.Inverse(In);
                    obj.DisplayCount;
                    %obj.DisplayImage(Out);
                    Out = Out(:);
                    Out = Out + Opt.Lambda*Tik;
            end   
        end          
        
%==================================================================
% DisplayCount
%==================================================================           
        function DisplayCount(obj)        
%             if obj.ItNum == 1
%                 obj.DispBytes = fprintf('Created Image %i',obj.ItNum);
%             else
%                 fprintf(repmat('\b',1,obj.DispBytes));
%                 obj.DispBytes = fprintf('Created Image %i',obj.ItNum);
%             end
            Status2('busy',['Image',num2str(obj.ItNum)],3);
            obj.ItNum = obj.ItNum + 1;
        end

%==================================================================
% DisplayImage
%==================================================================           
        function DisplayImage(obj,Out)        
            if mod(obj.ItNum,obj.DispImageStep) == 0
                ImportImageCompass(Out,['Image',num2str(obj.ItNum)]);
            end 
        end
        
    end
end


