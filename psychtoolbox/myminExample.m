% Minimal example to reproduce the file saving problem with custom Gstreamer input

% Displays and records video for "vidLength" secs (or untill keypress) from camera at /dev/video0 
% using a custom gsteramer pipe. Display is at top-left corner, 
% all params are hardcoded.

% with Kbcheck 

%% Basic params

moviename = 'mytest.mov';
withsound = 2; % record with sound
windowed = 1;
PsychDefaultSetup(1);
vidLength = 900;  % maximum length for video in secs
Screen('Preference', 'Verbosity', 6);
screen=max(Screen('Screens'));

% Only report ESCape key press via KbCheck:
RestrictKeysForKbCheck(KbName('ESCAPE'));

% Custom Gstreamer pipeline definition:
capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert'

try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));
catch ME
    sca; 
    rethrow(ME);
end

% Default codec:
codec = ':CodecType=DEFAULTencoder';
codec = [moviename, codec];

vidstartAt = GetSecs + 15; % video capture delay in secs

%% Open device + Start capture
try
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    win = Screen('OpenWindow', screen, 0, [0 0 1400 850]);
    Screen('Flip', win);
    Screen('TextSize', win, 24);
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, [0 0 1280 720], [], [], [], codec, withsound, [], 8);
    
    KbReleaseWait;
    WaitSecs('YieldSecs', 2);

    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    % preallocate frame info holding vars
    frameCaptTime = nan(vidLength*30, 1);
    droppedFrames = nan(vidLength*30, 1);
    
    % Start capture with 30 fps
    [Fps, startTime] = Screen('StartVideoCapture', grabber, 30, 1, vidstartAt);

    % Run until keypress or until maximum allowed time is reached
    while ~KbCheck && GetSecs < vidstartAt+vidLength
        
        % Wait blocking for next image then return it as texture
        [tex, pts, nrdropped] = Screen('GetCapturedImage', win, grabber, 1, oldtex);

           % If a texture is available, draw and show it.
            if tex > 0
                % Print capture timestamp in seconds since start of capture:
                Screen('DrawText', win, sprintf('Capture time (secs): %.4f', pts), 0, 0, 255);

                % Draw new texture from framegrabber.
                Screen('DrawTexture', win, tex);
                oldtex = tex;
                Screen('Flip', win);
                
                count = count + 1;
                
                % Store frame-specific values
                frameCaptTime(count, 1) = pts;
                droppedFrames(count, 1) = nrdropped;
                
            else  % if tex
                WaitSecs('YieldSecs', 0.005);
                
            end  % if tex
      
    end  % while

    % Done, report elapsed time
    telapsed = GetSecs - startTime;
    
    % Shutdown
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    sca;
    % Report fps
    avgfps = count / telapsed;
    disp([char(10), 'Average framerate: ', num2str(avgfps)]);
    
catch ME
    % In case of error, call 'CloseAll'
    RestrictKeysForKbCheck([]);
    sca;
    rethrow(ME);
    
end  % try

% report start time of capture, elapsed time 
disp([char(10), 'Start of capture: ', num2str(startTime)]);
disp([char(10), 'diff: ', num2str(startTime - vidstartAt)]);
disp([char(10), 'Elapsed time: ', num2str(telapsed), ' secs']); 
##      char(10), num2str(frameCaptTime)]);

RestrictKeysForKbCheck([]);

Screen('Preference', 'SkipSyncTests', oldsynclevel);
