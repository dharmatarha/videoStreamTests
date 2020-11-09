% Minimal example code to work around the file saving problem with custom Gstreamer input
%
% Here we try to save the frames as images directly from matlab. Logic:
% (1) Start psychtoolbox video capture without reqesting recording (only
% live display)
% (2) Use 'GetCapturedImage' with special flag to return raw image as well
% (3) Write out images to video file with matlab's built-in VideoWriter 
%
% Displays and records video for "vidLength" secs from camera at /dev/video0 
% using a custom gsteramer pipe. Display is at top-left corner, 
% all params are hardcoded.


%% Basic params

% movie name is only used for VideoWriter object
moviename = 'test';

% basic setup
PsychDefaultSetup(1);
Screen('Preference', 'Verbosity', 6);
screen=max(Screen('Screens'));

% Main video capture params
vidLength = 5;  % length of video in secs
recordingFlags = 0;
targetFps = 30;
rect = [0 0 1280 720];
getImageSpecialFlag = 2;

% Matlab video writer init
vidProfile = 'Motion JPEG AVI';  % Ok quality, ~2 MB / sec for 1280x720, slow: ~35 ms / frame
% vidProfile = 'Archival';  % ~10 MB / sec for 1280x720, super slow: ~57 ms / frame
vidObj = VideoWriter(moviename, vidProfile);
open(vidObj);

% var for timing video writing
frameWriteTimes = nan(vidLength*targetFps, 1);

% Custom Gstreamer pipeline definition:
% (1) Base version, works but file remains 0 bytes, with or without the "! videoconvert" part:
capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert';

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
        [tex, captureTime, droppedCount, rawImg] = Screen('GetCapturedImage', win, grabber, 1, oldtex, getImageSpecialFlag);

        if tex > 0
            Screen('DrawTexture', win, tex);  % Draw new texture from device
            oldtex = tex;  % Recycle texture
            Screen('Flip', win);  % Show new texture
 
            count = count + 1;  
            
            % write out image with matlab's video writer
            vidWriteStart = GetSecs;
            tmp = permute(rawImg(1:3, :, :), [3, 2, 1]);  % raw image from GetCapturedImage needs to be rearranged into height-by-width-by-3  
            writeVideo(vidObj, tmp(:, :, [3, 2, 1]));  % need to rearrange color channels to RGB
            frameWriteTimes(count, 1) = GetSecs-vidWriteStart;

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
    % Report write speed
    disp([newline, 'Median time for writing out a video frame: ',... 
        num2str(median(frameWriteTimes, 'omitnan')), newline]);
    
catch ME
    % In case of error, call 'CloseAll'
    sca;
    close(vidObj);
    rethrow(ME);
    
end  % try

Screen('Preference', 'SkipSyncTests', oldsynclevel);
