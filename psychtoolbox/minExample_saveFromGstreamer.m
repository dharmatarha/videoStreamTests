% Minimal example code to work around the file saving problem with custom Gstreamer input
%
% Here we try to save the video with the custom Gstreamer pipe itself,
% using tee. That is, we split the pipeline in two, and only feed one
% branch to psychtoolbox (hopefully)
%
% Displays and records video for "vidLength" secs from camera at /dev/video0 
% using a custom gsteramer pipe. Display is at top-left corner, 
% all params are hardcoded.


%% Basic params

% basic setup
PsychDefaultSetup(1);
Screen('Preference', 'Verbosity', 10);
screen=max(Screen('Screens'));

% Main video capture params
vidLength = 5;  % length of video in secs
recordingFlags = 0;
targetFps = 30;
rect = [0 0 1280 720];

% Custom Gstreamer pipeline definition:
% Try to record the file with Gstreamer pipe definition, using tee
% capturebinspec = ['v4l2src device=/dev/video0 ! image/jpeg,width=1280,height=720,framerate=30/1 ! jpegdec ! tee name=t',...
%     't. ! queue ! videoconvert ! x264enc tune=zerolatency ! h264parse ! matroskamux ! filesink location=''raw_dual.mkv'' sync=false ',...
%     't. ! queue ! videoconvert'];
capturebinspec = ['v4l2src device=/dev/video0 ! jpegdec ! tee name=t',...
    't. ! queue ! videoconvert ! x264enc tune=zerolatency ! h264parse ! matroskamux ! filesink location=''raw_dual.mkv'' sync=false ',...
    't. ! queue ! videoconvert'];

try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));
catch ME
    sca; 
    rethrow(ME);
end


%% Open device + Start capture
try
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    win = Screen('OpenWindow', screen, 0, rect);
    Screen('Flip',win);
    Screen('TextSize', win, 24);
    
    % Open video capture device - pure live display
    grabber = Screen('OpenVideoCapture', win, -9, rect, [], [], [], [], recordingFlags, [], []);
    WaitSecs('YieldSecs', 2);

    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    % Start capture with target fps
    Screen('StartVideoCapture', grabber, targetFps, 1);

    startTime = GetSecs;
    % Run until keypress or until maximum allowed time is reached
    while GetSecs < startTime+vidLength
        
        % Wait blocking for next image then return it as texture
        [tex] = Screen('GetCapturedImage', win, grabber, 1, oldtex);

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
    close(vidObj);
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
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
