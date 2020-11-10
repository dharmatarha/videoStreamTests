% Minimal example to reproduce the file saving problem with custom Gstreamer input

% Displays and records video for vidLength secs from camera at /dev/video0 
% using a custom gsteramer pipe. Display is at top-left corner, 
% all params are hardcoded.


%% Basic params

moviename = 'test.mov';

PsychDefaultSetup(1);
vidLength = 5;  % maximum length for video in secs
Screen('Preference', 'Verbosity', 6);
screen=max(Screen('Screens'));
recordingFlags = 256;

% Custom Gstreamer pipeline definition:
% (1) Base version, works but file remains 0 bytes, with or without the "! videoconvert" part:
% capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert';
% (2) Works but file remains 0 bytes
% capturebinspec = 'v4l2src device=/dev/video0 ! image/jpeg,width=1280,height=720,framerate=30/1 ! jpegdec ! videoconvert ! video/x-raw,width=1280,height=720,framerate=30/1,format=YUY2 ! videoconvert';  
% (3) Works but file remains 0 bytes:
% capturebinspec = 'v4l2src device=/dev/video0 ! image/jpeg,width=1280,height=720,framerate=30/1 ! jpegdec ! videoconvert';
% (4) Try Gstreamer pipeline delivering YUV / YUY2 format - shows video but file remains 0 bytes:
% capturebinspec = 'v4l2src device=/dev/video0 ! video/x-raw,width=1280,height=720,framerate=30/1,format=YUY2 ! videoconvert';
capturebinspec = 'v4l2src device=/dev/video0 ! video/x-raw,format=YUY2 ! videoconvert';

% capturebinspec = 'v4l2src device=/dev/video0 ! image/jpeg,width=1280,height=720,framerate=30/1 ! jpegparse ! jpegdec ! videoconvert ! video/x-raw,width=1280,height=720,format=BGRx,framerate=30/1';
% capturebinspec = 'v4l2src device=/dev/video0 ! image/jpeg,width=1280,height=720,framerate=30/1 ! jpegdec ! videoconvert ! video/x-raw,width=1280,height=720,format=BGRx,framerate=30/1';
% capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert ! x264enc tune="zerolatency" threads=1 ! video/x-h264,stream-format=byte-stream';

try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));
catch ME
    sca; 
    rethrow(ME);
end

% Default codec:
% codec = ':CodecType=DEFAULTencoder';
% codec = [moviename, codec];
codec = moviename;


%% Open device + Start capture
try
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    win = Screen('OpenWindow', screen, 0, [0 0 1280 720]);
    Screen('Flip',win);
    Screen('TextSize', win, 24);
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, [0 0 1280 720], [], [], [], codec, recordingFlags, [], 8);
    WaitSecs('YieldSecs', 2);

    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    % Start capture with target fps
    Screen('StartVideoCapture', grabber, 30, 1);

    startTime = GetSecs;
    % Run until keypress or until maximum allowed time is reached
    while GetSecs < startTime+vidLength
        
        % Wait blocking for next image then return it as texture
        [tex, ~, ~] = Screen('GetCapturedImage', win, grabber, 1, oldtex);

        if tex > 0
            Screen('DrawTexture', win, tex);  % Draw new texture from device
            oldtex = tex;  % Recycle texture
            Screen('Flip', win);  % Show new texture
            count = count + 1;  
        else
            WaitSecs('YieldSecs', 0.005);
        end
        
    end  % while

    % Done, report elapsed time
    telapsed = GetSecs - startTime;
    disp([newline, 'Elapsed time: ', num2str(round(telapsed, 2)), ' secs']);  
    % Shutdown
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
%     WaitSecs('YieldSecs', 3);
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
%     WaitSecs('YieldSecs', 3);
    sca;
    % Report fps
    avgfps = count / telapsed;
    disp([newline, 'Average framerate: ', num2str(avgfps)]);
    
catch ME
    % In case of error, call 'CloseAll'
    sca;
    rethrow(ME);
    
end  % try

Screen('Preference', 'SkipSyncTests', oldsynclevel);
