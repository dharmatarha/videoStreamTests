% Minimal example to reproduce the file saving problem with custom Gstreamer input

% Displays and records video for "vidLength" secs from camera at /dev/video0 
% using a custom gsteramer pipe. Display is at top-left corner, 
% all params are hardcoded.


%% Basic params

moviename = 'test.mov';

PsychDefaultSetup(1);
vidLength = 5;  % maximum length for video in secs
Screen('Preference', 'Verbosity', 6);
screen=max(Screen('Screens'));

% Custom Gstreamer pipeline definition:
%capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert'
%capturebinspec = 'rtspsrc location=rtsp://admin:Password@192.168.1.21:554/ ! queue ! rtph265depay ! h265parse ! avdec_h265 ! videoconvert';
%capturebinspec = 'rtspsrc location=rtsp://admin:Password@192.168.1.21:554/ ! rtph265depay ! h265parse ! avdec_h265 ! videoconvert';
capturebinspec = 'v4l2src device=/dev/video2 ! videoconvert';

try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));
catch ME
    sca; 
    rethrow(ME);
end

% Default codec:
codec = ':CodecType=DEFAULTencoder';
codec = [moviename, codec];


%% Open device + Start capture
try
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    win = Screen('OpenWindow', screen, 0, [0 0 1920 1080]);
    Screen('Flip',win);
    Screen('TextSize', win, 24);
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, [0 0 1920 1080], [], [], [], codec, 0, [], 8);
    disp('HEYHEY      Video Device Opened!');
    WaitSecs('YieldSecs', 2);

    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    % Start capture with target fps
    Screen('StartVideoCapture', grabber, 25, 1);
    disp('HEYHEY      Video Capture Started!');

    startTime = GetSecs;
    % Run until keypress or until maximum allowed time is reached
    while GetSecs < startTime+vidLength
        
        % Wait blocking for next image then return it as texture
        [tex, ~, ~] = Screen('GetCapturedImage', win, grabber, 1, oldtex);
        disp('HEYHEY      FIRST IMAGE CAPTURED!');

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
    disp([char(10), 'Elapsed time: ', num2str(round(telapsed, 2)), ' secs']);  
    % Shutdown
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    sca;
    % Report fps
    avgfps = count / telapsed;
    disp([char(10), 'Average framerate: ', num2str(avgfps)]);
    
catch ME
    % In case of error, call 'CloseAll'
    sca;
    rethrow(ME);
    
end  % try

Screen('Preference', 'SkipSyncTests', oldsynclevel);
