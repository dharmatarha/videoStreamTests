function videoChannel_d404(pairNo, labName, gstSpec)
%% Function for video-mediated interaction in room D404
%
% USAGE: videoChannel_d404(pairNo, labName, gstSpec='see below')
%
% Default "gstSpec":
%  gstSpec = ['udpsrc port=19009 caps="application/x-rtp,media=',...
%    '(string)video,clock-rate=(int)90000,encoding-name=(string)RAW,sampling=',...
%    '(string)YCbCr-4:2:0,depth=(string)8,width=(string)1920,height=(string)1080,',...
%    'colorimetry=(string)SMPTE240M,payload=(int)96,a-framerate=(string)30" ',...
%    '! queue ! rtpvrawdepay ! videoconvert'];
%
% Reads in video frames from a v4l2 video device and displays them on 
% screen as fast as it can.
%
% Version for webcam RTP stream coming from remote lab.
%
% Assumptions:
% - Remote machine (Mordor or Gondor stimulus control machine) has 
% opened a gst-launch pipeline sinking the webcam feed to local machine 
% (as RTP over UDP).
% - Local machine can access the udp feed with a gst-launch pipe and treat as 
% input to Psychtoolbox.
% 
% Mandatory inputs:
% pairNo        - Numeric value, pair number, one of [1:999]. 
% labName    - Char array, lab name, one of {"Luca", "Adam"}. 
%                   Added to filenames.
%
% Optional inputs:
% gstSpec      - Char array, gst-launch pipe specification to be used as a custom
%                   capture bin for Psychtoolbox video capture functions. Defaults to
%                   the long, ugly line specified above, below "USAGE"
%    

%% Input checks

if ~ismember(nargin, 2:3)
    error('Input args "pairNo" are "labName" are required while "gstSpec" is optional!');
endif
if nargin == 2
    gstSpec = ['udpsrc port=19009 caps="application/x-rtp,media=',...
    '(string)video,clock-rate=(int)90000,encoding-name=(string)RAW,sampling=',...
    '(string)YCbCr-4:2:0,depth=(string)8,width=(string)1920,height=(string)1080,',...
    'colorimetry=(string)SMPTE240M,payload=(int)96,a-framerate=(string)30" ',...
    '! queue ! rtpvrawdepay ! videoconvert'];
endif
if ~isnumeric(pairNo) || ~ismember(pairNo, 1:999)
    error("Input arg pairNo should be one of 1:999!");
endif
if ~ischar(labName) || ~ismember(labName, {"Luca", "Adam"})
    error("Input arg labName should be one of Luca / Adam as char array!");
endif


%% Constants, params, setup

% filename for saving timestamps and other relevant vars
savefile = ["pair", num2str(pairNo), labName, "_times.mat"];

% remote IP, depends on lab name
if strcmp(labName, "Luca")
    remoteIP = "10.160.12.111";
elseif strcmp(labName, "Adam")
    remoteIP = "10.160.12.108";
endif

% video recording
moviename = ["pair", num2str(pairNo), labName, ".mov"];
vidLength = 3600;  % maximum length for video in secs
codec = ':CodecType=DEFAULTencoder';  % default codec
codec = [moviename, codec];

% video settings
waitForImage = 1;  % setting for Screen('GetCapturedImage'), 0 = polling (non-blocking); 1 = blocking wait for next image
vidSamplingRate = 30;  % expected video sampling rate, real sampling rate will differ
vidDropFrames = 1;  % dropframes flag for StartVideoCapture, 0 = do not drop frames; 1 = drop frame if necessary, only return the last captured frame
vidRecFlags = 16;  % recordingflags arg for OpenVideoCapture, 16 = use parallel thread in background; consider adding 1, 32, 128, 2048, 4096
vidRes = [0 0 1920 1080];  % frame resolution

% screen params
backgroundColor = [0, 0, 0];  % general screen openwindow background color
windowTextSize = 24;  % general screen openwindow text size

% preallocate frame info holding vars, adjust for potentially higher-than-expected sampling rate
frameCaptTime = nan((vidLength+60)*vidSamplingRate, 1);
flipTimeStamps = nan((vidLength+60)*vidSamplingRate, 3);  % three columns for the three flip timestamps returned by Screen
droppedFrames = frameCaptTime;


%% Psychtoolbox initializations

Priority(1);
PsychDefaultSetup(1);
Screen('Preference', 'Verbosity', 3);
screen=max(Screen('Screens'));
GetSecs; WaitSecs(0.1); KbCheck;  % dummy calls

% Try to set video capture to custom pipeline
try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', gstSpec));
catch ME
    disp('Failed to set Screen(''SetVideoCaptureParameter''), errored out.');
    sca; 
    rethrow(ME);
end


%% Start video capture

try
    % Open onscreen window for video playback
    win = Screen('OpenWindow', screen, backgroundColor);
    Screen('TextSize', win, windowTextSize);  % set text size for win
    Screen('Flip', win);  % initial flip to background
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, vidRes, [], [], [], codec, vidRecFlags);
    % Wait a bit for OpenVideoCapture to return
    WaitSecs('YieldSecs', 1);
    
    % get a shared start time across machines
    sharedStartTime = UDPhandshake(remoteIP);
    
    % Start capture 
    [reportedSamplingRate, vidcaptureStartTime] = Screen('StartVideoCapture', grabber, vidSamplingRate, vidDropFrames, sharedStartTime);
    % Check the reported sampling rate, compare to requested rate
    if reportedSamplingRate ~= vidSamplingRate
        warning(['Reported sampling rate from Screen(''StartVideoCapture'') is ', ...
        num2str(reportedSamplingRate), ' fps, not matching the requested rate of ', ...
        num2str(vidSamplingRate), ' fps!']);
    endif
    
    % helper variables for the display loop
    oldtex = 0;
    vidFrameCount = 1;

    % Run until keypress or until maximum allowed time is reached
    while GetSecs < sharedStartTime+vidLength
         
         % check for key press (ESCAPE)
         [keyIsDown, ~, keyCode] = KbCheck;
         if keyIsDown && keyCode(KbName('ESCAPE'))
             disp([char(10), 'User requested abort...']);
             break;
         endif        
         
        % Check for next available image, return it as texture if there was one
        [tex, frameCaptTime(vidFrameCount), droppedFrames(vidFrameCount)] = Screen('GetCapturedImage', win, grabber, waitForImage, oldtex);  
        
        % If a texture is available, draw and show it.
        if tex > 0
            % Check for completion of previous asynchronous flip.
            % Previous flip should have finished way earlier as screen refresh
            % rate is higher than video capture rate
            if vidFrameCount > 1  % only from the second frame on
                flipTimestamps(vidFrameCount-1, 1:3) = Screen('AsyncFlipEnd', win);  % timestamps belong to previous frame, hence the minus 1 index
            endif
            
            % Print capture timestamp in seconds since start of capture:
            Screen('DrawText', win, sprintf('Capture time (secs): %.4f', frameCaptTime(vidFrameCount)), 0, 0, 255);
            % Draw new texture from framegrabber.
            Screen('DrawTexture', win, tex);
            oldtex = tex;
            % Asyncronous flip - non-blocking, only schedules the buffer for next screen refresh
            Screen('AsyncFlipBegin', win);
            
            % adjust video frame counter
            vidFrameCount = vidFrameCount + 1;
            
        endif  % if tex
       
    endwhile 

    
    %% Cleanup, saving out timing information
    
    % get total elapsed time
    elapsedTime = GetSecs - vidcaptureStartTime;
    
    % shutdown video and screen
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    stopCaptureTime = GetSecs; 
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    closeCaptureTime = GetSecs; 
    Priority(0);
    sca;

    % save major timestamps
    save(savefile, "sharedStartTime", "videoCaptureStartTime",...
    "frameCaptTime", "vidFrameCount", "flipTimestamps", "stopCaptureTime",...
    "closeCaptureTime", "elapsedTime");

    % report fps
    avgfps = vidFrameCount / elapsedTime;
    disp([char(10), 'Average framerate: ', num2str(avgfps)]);

    % report start time of capture, elapsed time 
    disp([char(10), 'Requested (shared) start time was: ', num2str(vidcaptureStartTime)]);
    disp([char(10), 'Start of capture was: ', num2str(vidcaptureStartTime)]);
    disp([char(10), 'Difference: ', num2str(vidcaptureStartTime - sharedStartTime)]);
    disp([char(10), 'Total elapsed time from start of capture: ', num2str(elapsedTime)]);     
    
    
catch ME

    % In case of error, close screens, video
    Priority(0);
    sca;  % closes video too
    rethrow(ME);
    
    
end  % try



endfunction
