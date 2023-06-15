%==================================================================
% CompassImageCompass
%================================================================== 

function ImportImageCompass(Image,Name)

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
    MSTRCT.type = 'abs';
    MSTRCT.dispwid = [0 max(abs(IMG.Im(:)))];
    MSTRCT.ImInfo.pixdim = [1 1 1];
    MSTRCT.ImInfo.vox = 1;
    MSTRCT.ImInfo.info = [];
    MSTRCT.ImInfo.baseorient = 'Axial';             % all images should be oriented axially
    INPUT.Image = IMG.Im;
    INPUT.MSTRCT = MSTRCT;
    IMDISP = ImagingPlotSetup(INPUT);
    IMG.IMDISP = IMDISP;
    IMG.type = 'Image';
    IMG.path = '';
    IMG.name = ['IMG_',Name];

    %----------------------------------------------
    % Load Compass
    %----------------------------------------------
    totalgbl{1} = IMG.name;
    totalgbl{2} = IMG;
    from = 'CompassLoad';
    Load_TOTALGBL(totalgbl,'IM',from);

%     %----------------------------------------------
%     % Save
%     %----------------------------------------------
%     saveData.IMG = IMG;
%     save([IMG.path,IMG.name],'saveData');
    
end

