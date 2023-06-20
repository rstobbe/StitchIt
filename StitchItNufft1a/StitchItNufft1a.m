%================================================================
% StitchItNufft1a
%   
%================================================================

classdef StitchItNufft1a < handle

    properties (SetAccess = private)                                     
        StitchIt
        Options
        Log
        AcqInfo
        RxChannels
        ChanPerGpu
        NumGpuUsed
        ReconRxBatches
        ReconRxBatchLen
        RxProfs
        TestTime
    end
    
    methods 

%==================================================================
% Constructor
%==================================================================   
        function [obj] = StitchItNufft1a(Options)
            obj.StitchIt = StitchItFunctions();
            obj.Options = Options;
            obj.Log = Log('');
        end                        
        
%==================================================================
% Setup
%==================================================================   
        function Setup(obj,AcqInfo,RxProfs)
            obj.AcqInfo = AcqInfo;    
            sz = size(RxProfs);
            if length(sz) == 3
                obj.RxChannels = 1;
            else
                obj.RxChannels = sz(4);
            end
            if obj.RxChannels == 1          
                obj.Options.SetGpus2Use(1);
            end
            obj.Options.Initialize(obj.AcqInfo);
            obj.NumGpuUsed = obj.Options.Gpus2Use;
            
            %--------------------------------------
            % Receive Batching
            %   - for limited memory GPUs (and/or many RxChannels)
            %--------------------------------------             
            GridMemory = (obj.Options.ZeroFill^3)*20;          % k-space + image + invfilt (complex & single)
            BaseImageMemory = (obj.Options.BaseMatrix^3)*8;
            DataKspaceMemory = obj.AcqInfo.NumTraj*obj.AcqInfo.NumCol*16;
            TotalMemory = GridMemory + BaseImageMemory + DataKspaceMemory;
            AvailableMemory = obj.StitchIt.GpuParams.AvailableMemory;
            for n = 1:20
                obj.ReconRxBatches = n;
                obj.ChanPerGpu = ceil(obj.RxChannels/(obj.Options.Gpus2Use*obj.ReconRxBatches));
                MemoryNeededTotal = TotalMemory + BaseImageMemory * obj.ChanPerGpu;
                if MemoryNeededTotal*1.2 < AvailableMemory
                    break
                end
            end
            obj.ReconRxBatchLen = obj.ChanPerGpu * obj.Options.Gpus2Use;              
            
            %--------------------------------------
            % StitchIt Initialize
            %--------------------------------------
            obj.StitchIt.Initialize(obj.Options,obj.AcqInfo,obj.ChanPerGpu,obj.Log);
            
            %--------------------------------------
            % Load RxProfs
            %--------------------------------------   
            if obj.ReconRxBatches == 1
                obj.StitchIt.LoadRcvrProfMatricesGpuMum(RxProfs);
            else
                obj.RxProfs = RxProfs;
            end 
        end      

%==================================================================
% Inverse
%   - check if all calls Async...
%   - some Cuda efficiency coding to be done still
%   - weight kern properly - take out scaling...
%================================================================== 
        function Image = Inverse(obj,Data)
            tic
            ImageArray = complex(zeros([obj.Options.BaseMatrix obj.Options.BaseMatrix obj.Options.BaseMatrix,obj.ReconRxBatches,obj.NumGpuUsed],'single'),0);
            for q = 1:obj.ReconRxBatches 
                RbStart = (q-1)*obj.ReconRxBatchLen + 1;
                RbStop = q*obj.ReconRxBatchLen;
                if RbStop > obj.RxChannels
                    RbStop = obj.RxChannels;
                end
                Rcvrs = RbStart:RbStop;
                if obj.ReconRxBatches ~= 1
                    obj.StitchIt.LoadRcvrProfMatricesGpuMum(obj.RxProfs(:,:,:,Rcvrs));
                end
                obj.StitchIt.InitializeBaseMatricesGpuMem;
                for p = 1:obj.ChanPerGpu
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end
                        obj.StitchIt.LoadSampDatGpuMemAsyncCidx(GpuNum,Data,ChanNum);
                    end  
                    obj.StitchIt.InitializeGridMatricesGpuMem;
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end    
                        obj.StitchIt.GridSampDat(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end  
                        obj.StitchIt.KspaceFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.InverseFourierTransform(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.ImageFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.MultInvFilt(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.AccumulateImage(GpuNum,p);
                    end
                end
                for m = 1:obj.NumGpuUsed
                    GpuNum = m-1;
                	ImageArray(:,:,:,q,m) = obj.StitchIt.ReturnBaseImage(GpuNum);
                end
            end
            Image = sum(ImageArray,[4 5]);
            Scale = 1/obj.StitchIt.ConvScaleVal * single(obj.StitchIt.BaseImageMatrixMemDims(1)).^1.5 / single(obj.StitchIt.GridImageMatrixMemDims(1))^3;
            Image = Image*Scale;
            obj.TestTime = [obj.TestTime toc];
            TestTotalTime = sum(obj.TestTime)
        end           

%==================================================================
% Forward
%   - check if all calls Async...
%   - some Cuda efficiency coding to be done still
%==================================================================         
        function Data = Forward(obj,Image)
            Data = complex(zeros([obj.AcqInfo.NumCol,obj.AcqInfo.NumTraj,obj.ChanPerGpu],'single'),0);
            obj.StitchIt.LoadImageMatrixGpuMem(Image);
            for q = 1:obj.ReconRxBatches 
                RbStart = (q-1)*obj.ReconRxBatchLen + 1;
                RbStop = q*obj.ReconRxBatchLen;
                if RbStop > obj.RxChannels
                    RbStop = obj.RxChannels;
                end
                Rcvrs = RbStart:RbStop;
                if obj.ReconRxBatches ~= 1
                    obj.StitchIt.LoadRcvrProfMatricesGpuMum(obj.RxProfs(:,:,:,Rcvrs));
                end
                for p = 1:obj.ChanPerGpu 
                    obj.StitchIt.InitializeGridMatricesGpuMem;
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.RcvrWgtExpandImage(GpuNum,p);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.MultInvFilt(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.ImageFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        obj.StitchIt.FourierTransform(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end  
                        obj.StitchIt.KspaceFourierTransformShift(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end   
                        obj.StitchIt.ForwardKspaceScaleCorrect(GpuNum); 
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end    
                        obj.StitchIt.ReverseGrid(GpuNum);
                    end
                    for m = 1:obj.NumGpuUsed
                        GpuNum = m-1;
                        ChanNum = (q-1)*obj.ReconRxBatches + (p-1)*obj.NumGpuUsed + m;
                        if ChanNum > obj.RxChannels
                            break
                        end 
                        Data(:,:,ChanNum) = obj.StitchIt.ReturnSampDat(GpuNum);
                    end
                end
            end
        end
        
%==================================================================
% Finish
%================================================================== 
        function Finish(obj)
            obj.StitchIt.FreeGpuMem;
        end
        
    end
end
