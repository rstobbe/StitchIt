%==================================================================
% DisplayStatusObject
%================================================================== 

classdef DisplayStatusObject < handle

    properties (SetAccess = private)                                     
        DataObj
        Compass = 0
        DisplaySensitivityMaps = 0
        DisplayCombinedImages = 0
        DisplayRxProfs = 0
        DisplayOffResMap = 0
        DisplayInitialImages = 0
        DisplayIterations = 0
        DisplayIterationStep = 1
        SaveIterationStep = 0
        PrevStringLen = 0
        SaveIterationPath
        ItNum = 1
    end
    
    methods

%==================================================================
% Constructor
%==================================================================   
        function [obj] = DisplayStatusObject()
            test = who('global');
            for n = 1:length(test)
                if strcmp(test{n},'COMPASSINFO')
                    obj.Compass = 1;
                    break
                end
            end
        end

%==================================================================
% Status
%==================================================================         
        function Status(obj,String,Level)  
            if obj.Compass
                Status2('busy',String,Level);
            end
            back = repmat('\b',1,obj.PrevStringLen);
            fprintf(back);
            fprintf(String);
            obj.PrevStringLen = length(String);
        end

%==================================================================
% StatusClear
%==================================================================         
        function StatusClear(obj)  
            if obj.Compass
                Status2('done','',1);
                Status2('done','',2);
                Status2('done','',3);
            end
            back = repmat('\b',1,obj.PrevStringLen);
            fprintf(back);
            disp('');
        end        

%==================================================================
% TestDisplaySensitivityMaps
%==================================================================         
        function TestDisplaySensitivityMaps(obj,SensMaps)  
            if ~obj.Compass
                return
            end
            if obj.DisplaySensitivityMaps
                totgblnum = ImportImageCompass(SensMaps,'SensMaps');
                Gbl2ImageOrtho('IM3',totgblnum);
            end
        end         

%==================================================================
% TestDisplayCombinedImages
%==================================================================         
        function TestDisplayCombinedImages(obj,CombImage)  
            if ~obj.Compass
                return
            end
            if obj.DisplayCombinedImages
                totgblnum = ImportImageCompass(CombImage,'CombImage');
                Gbl2ImageOrtho('IM3',totgblnum);
            end
        end        
        
%==================================================================
% TestDisplayRxProfs
%==================================================================         
        function TestDisplayRxProfs(obj,RxProfs)  
            if ~obj.Compass
                return
            end
            if obj.DisplayRxProfs
                totgblnum = ImportImageCompass(RxProfs,'RxProfs');
                Gbl2ImageOrtho('IM3',totgblnum);
            end
        end        
        
%==================================================================
% TestDisplayOffResMap
%==================================================================         
        function TestDisplayOffResMap(obj,OffResMap)  
            if ~obj.Compass
                return
            end
            if obj.DisplayOffResMap
                totgblnum = ImportOffResMapCompass(OffResMap,'OffResMap',[],[],max(abs(OffResMap(:))));
                Gbl2ImageOrtho('IM3',totgblnum);
            end
        end          

%==================================================================
% TestDisplayInitialImages
%==================================================================         
        function TestDisplayInitialImages(obj,Image0,Name)  
            if ~obj.Compass
                return
            end
            if obj.DisplayInitialImages
                if isempty(Name)
                    totgblnum = ImportImageCompass(Image0,'Image0');
                else
                    totgblnum = ImportImageCompass(Image0,Name);
                end
                Gbl2ImageOrtho('IM3',totgblnum);
            end
        end
        
%==================================================================
% DisplayCount
%==================================================================       
        function StitchItDisplayCount(obj) 
            String = ['StitchIteration ' num2str(obj.ItNum)];
            if obj.Compass
                Status2('busy',String,3);
            end
            back = repmat('\b',1,obj.PrevStringLen);
            fprintf(back);
            fprintf(String);
            obj.PrevStringLen = length(String);
        end 
      
%==================================================================
% ResetIterationCount
%==================================================================       
        function ResetIterationCount(obj) 
            obj.ItNum = 1;
        end        

%==================================================================
% IterationAnalysis
%==================================================================            
        function IterationAnalysis(obj,Image,nit) 
            if ~obj.Compass
                return
            end
            if obj.DisplayIterations
                if rem(nit,obj.DisplayIterationStep) == 0
                    totgblnum = ImportImageCompass(Image,['StitchIteration',num2str(nit)],obj.SaveIterationStep,obj.SaveIterationPath);
                    Gbl2ImageOrtho('IM3',totgblnum);
                end
            end
        end        
        
%==================================================================
% Set
%==================================================================  
        function SetDataObj(obj,val)
            obj.DataObj = val;
            if obj.SaveIterationStep
                mkdir([obj.DataObj.DataPath,obj.DataObj.DataName,'\']);
                obj.SaveIterationPath = [obj.DataObj.DataPath,obj.DataObj.DataName,'\'];
            end
        end
        function SetDisplaySensitivityMaps(obj,val)    
            obj.DisplaySensitivityMaps = val;
        end
        function SetDisplayCombinedImages(obj,val)    
            obj.DisplayCombinedImages = val;
        end        
        function SetDisplayRxProfs(obj,val)
            obj.DisplayRxProfs = val;
        end
        function SetDisplayOffResMap(obj,val)    
            obj.DisplayOffResMap = val;
        end
        function SetDisplayInitialImages(obj,val)    
            obj.DisplayInitialImages = val;
        end
        function SetDisplayIterations(obj,val)    
            obj.DisplayIterations = val;
        end
        function SetDisplayIterationStep(obj,val)    
            obj.DisplayIterationStep = val;
        end
        function SetSaveIterationStep(obj,val)    
            obj.SaveIterationStep = val;
        end 
        
    end
end
    

