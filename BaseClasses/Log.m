%================================================================
% Created by Alexander Fyrdahl <alexander.fyrdahl@gmail.com>
% Inspired by log4m by Luke Winslow <lawinslow@gmail.com> 
%================================================================

classdef Log < handle
    
    properties  (SetAccess = private)  
        filename
        VerboseLevel = 3
    end
    methods

%==================================================================
% Constructor
%==================================================================          
        function obj = Log(filename)
            obj.filename = filename;
        end

        function debug(obj,varargin)
            writeLog(obj,1,sprintf(varargin{:}));
        end
        
        function trace(obj,varargin)
            writeLog(obj,2,sprintf(varargin{:}));
        end
        
        function info(obj,varargin)
            writeLog(obj,3,sprintf(varargin{:}));
        end
        
        function warn(obj,varargin)
            writeLog(obj,4,sprintf(varargin{:}));
        end
        
        function error(obj,varargin)
            writeLog(obj,5,sprintf(varargin{:}));
        end

        function SetVerbosity(obj,val)
            obj.VerboseLevel = val;
        end        
        
    end
    
    methods (Access = private)
        
        function writeLog(obj,level,message)
            
            if level < obj.VerboseLevel
                return
            end
            
            switch level
                case 1
                    levelStr = 'DEBUG';
                case 2
                    levelStr = 'TRACE';
                case 3
                    levelStr = 'INFO ';
                case 4
                    levelStr = 'WARN ';
                case 5
                    levelStr = 'ERROR';
            end
            
            % Write to log file,
            if ~isempty(obj.filename)
                fid = fopen(obj.filename, 'a', 'n', 'utf-8');
                fprintf(fid,'%s %s - %s\n' ...
                        , datestr(now,'yyyy-mm-dd HH:MM:SS,FFF') ...
                        , levelStr ...
                        , message);
                fclose(fid);
            end
            
            % but output to terminal as well
            fprintf('%s %s - %s\n' ...
                , datestr(now,'yyyy-mm-dd HH:MM:SS,FFF') ...
                , levelStr ...
                , message);

        end
    end
end
