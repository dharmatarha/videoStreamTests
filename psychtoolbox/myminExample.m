% Minimal example to reproduce the file saving problem with custom Gstreamer input

% Displays and records video for "vidLength" secs from camera at /dev/video0 
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
capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert' % sound? alsasrc \ ! audio/x-raw,width=16,depth=16,rate=44100,channel=1 \ ! audioconvert \';

try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));
catch ME
    sca; 
    rethrow(ME);
end

% Default codec:
codec = ':CodecType=DEFAULTencoder';
codec = [moviename, codec];

vidstartAt = GetSecs + 20; % starting time for video in secs?

%% Open device + Start capture
try
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    win = Screen('OpenWindow', screen, 0, [0 0 1000 600]);
    Screen('Flip',win);
    Screen('TextSize', win, 24);
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, [0 0 1920 1080], [], [], [], codec, withsound, [], 8);
    
    KbReleaseWait;
    WaitSecs('YieldSecs', 2);

    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    % Start capture with target fps
    [Fps, startTime] = Screen('StartVideoCapture', grabber, 30, 1, vidstartAt);

    % startTime = vidstartAt;
    % Run until keypress or until maximum allowed time is reached
    while ~KbCheck && GetSecs < vidstartAt+vidLength
        
        % Wait blocking for next image then return it as texture
        [tex, captureTimestamp, ~] = Screen('GetCapturedImage', win, grabber, 1, oldtex);

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
    disp([char(10), 'Elapsed time: ', num2str(telapsed), ' secs']);  
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

disp([char(10), num2str(startTime), ...
      char(10), num2str(captureTimestamp)]);

RestrictKeysForKbCheck([]);

Screen('Preference', 'SkipSyncTests', oldsynclevel);
