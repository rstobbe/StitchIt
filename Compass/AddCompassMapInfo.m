%==================================================================
% ReturnOneImage
%================================================================== 

function IMG = AddCompassMapInfo(Image,DataObj,AcqInfo,StitchIt,ReconPanelOutput,NameSuffix)

    IMG.Method = class(StitchIt);
    IMG.Im = Image;  
    Info = DataObj.DataInfo;           
    IMG.ExpPars = Info.ExpPars;

    Panel(1,:) = {'','','Output'};
    Panel(2,:) = {'Recon Function',IMG.Method,'Output'};
    PanelOutput0 = cell2struct(Panel,{'label','value','type'},2);
    IMG.PanelOutput = [PanelOutput0;Info.PanelOutput;ReconPanelOutput];
    IMG.ExpDisp = PanelStruct2Text(IMG.PanelOutput);
 
    %----------------------------------------------
    % Set Up Compass Display
    %----------------------------------------------
    sz = size(Image);
    PixDims = AcqInfo.Fov./sz(1:3);
    MSTRCT.type = 'map';
    MSTRCT.dispwid = [-max(abs(IMG.Im(:))) max(abs(IMG.Im(:)))];
    MSTRCT.ImInfo.pixdim = PixDims;
    MSTRCT.ImInfo.vox = PixDims(1)*PixDims(2)*PixDims(3);
    MSTRCT.ImInfo.info = IMG.ExpDisp;
    MSTRCT.ImInfo.baseorient = 'Axial';             % all images should be oriented axially
    INPUT.Image = IMG.Im;
    INPUT.MSTRCT = MSTRCT;
    IMDISP = ImagingPlotSetup(INPUT);
    IMG.IMDISP = IMDISP;
    IMG.type = 'Image';
    IMG.path = DataObj.DataPath;
    IMG.name = ['IMG_',DataObj.DataName,'_',NameSuffix];
end

