%==================================================================
% DisplayStatusCompass
%================================================================== 

function DisplayStatusCompass(ReconObj,String,Level)

    if nargin == 3
        if ReconObj.CompassCalling
            Status2('busy',String,Level);
        end
    else
        disp('String');
    end
        
    
end

