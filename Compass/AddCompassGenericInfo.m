%==================================================================
% AddCompassGenericInfo
%================================================================== 

function IMG = AddCompassGenericInfo(Image,Name,CreateFunc,PanelOutput,DispType,DispWid)

    IMG.Method = class(CreateFunc);
    IMG.Im = Image;  

    Panel(1,:) = {'','','Output'};
    Panel(2,:) = {'Create Function',IMG.Method,'Output'};
    PanelOutput0 = cell2struct(Panel,{'label','value','type'},2);
    IMG.PanelOutput = [PanelOutput0;PanelOutput];
    IMG.ExpDisp = PanelStruct2Text(IMG.PanelOutput);
 
    %----------------------------------------------
    % Set Up Compass Display
    %----------------------------------------------
    MSTRCT.type = DispType;
    MSTRCT.dispwid = DispWid;
    MSTRCT.ImInfo.pixdim = [1 1 1];
    MSTRCT.ImInfo.vox = 1;
    MSTRCT.ImInfo.info = IMG.ExpDisp;
    MSTRCT.ImInfo.baseorient = 'Axial';             % all images should be oriented axially
    INPUT.Image = IMG.Im;
    INPUT.MSTRCT = MSTRCT;
    IMDISP = ImagingPlotSetup(INPUT);
    IMG.IMDISP = IMDISP;
    IMG.type = 'Image';
    if isprop(CreateFunc,'Path')
        IMG.path = CreateFunc.Path;
    else
        IMG.path = [];
    end
    IMG.name = ['IMG_',Name];
end



