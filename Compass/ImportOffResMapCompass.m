%==================================================================
% CompassImageCompass
%================================================================== 

function totgblnum = ImportOffResMapCompass(Image,Name,Save,Path,MaxOffRes)

    if nargin < 3
        Save = 0;
        Path = [];
    end

    Compass = 0;
    Test = whos('global');
    for n = 1:length(Test)
        if strcmp(Test(n).name,'TOTALGBL')
            Compass = 1;
        end
    end
    if Compass == 0
        return
    end

    IMG.Im = Image;  
    IMG.ExpPars = [];

    Panel(1,:) = {'','','Output'};
    Panel(2,:) = {'Generic',[],'Output'};
    PanelOutput0 = cell2struct(Panel,{'label','value','type'},2);
    IMG.PanelOutput = PanelOutput0;
    IMG.ExpDisp = PanelStruct2Text(IMG.PanelOutput);
 
    %----------------------------------------------
    % Set Up Compass Display
    %----------------------------------------------
    MSTRCT.type = 'real';
    MSTRCT.dispwid = [-MaxOffRes MaxOffRes];
    MSTRCT.ImInfo.pixdim = [1 1 1];
    MSTRCT.ImInfo.vox = 1;
    MSTRCT.ImInfo.info = [];
    MSTRCT.ImInfo.baseorient = 'Axial';             % all images should be oriented axially
    INPUT.Image = IMG.Im;
    INPUT.MSTRCT = MSTRCT;
    IMDISP = ImagingPlotSetup(INPUT);
    IMG.IMDISP = IMDISP;
    IMG.type = 'Image';
    IMG.path = Path;
    IMG.name = ['IMG_',Name];

    %----------------------------------------------
    % Load Compass
    %----------------------------------------------
    totalgbl{1} = IMG.name;
    totalgbl{2} = IMG;
    from = 'CompassLoad';
    totgblnum = Load_TOTALGBL(totalgbl,'IM',from);

    %----------------------------------------------
    % Save
    %----------------------------------------------
    if Save == 1
        saveData.IMG = IMG;
        save([IMG.path,IMG.name],'saveData');
    end
    
end

