% minimal example

%% Basic params

moviename = 'test.mov';

PsychDefaultSetup(1);
maxTime = 10;  % maximum length for video in secs
RestrictKeysForKbCheck(KbName('ESCAPE'));
Screen('Preference', 'Verbosity', 6);
screen=max(Screen('Screens'));

% Custom Gstreamer pipeline definition:
capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert';
% capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec';
Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));

% Default codec:
codec = ':CodecType=DEFAULTencoder';
codec = [moviename, codec];

%% Open device + Start capture
try
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    win = Screen('OpenWindow', screen, 0, [0 0 1280 720]);
    Screen('Flip',win);
    Screen('TextSize', win, 24);
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, [0 0 1280 720], 4, [], [], codec, 0, [], 8);
    WaitSecs('YieldSecs', 2);
    KbReleaseWait;

    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    % Start capture with target fps
    Screen('StartVideoCapture', grabber, 30, 1);

    startTime = GetSecs;
    % Run until keypress or until maximum allowed time is reached
    while ~KbCheck && GetSecs < startTime+maxTime
        
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

    % Done. Shut us down, report elapsed time
    telapsed = GetSecs - startTime;
    disp([newline, 'Elapsed time: ', num2str(round(telapsed, 2)), ' secs']);    
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    sca;
    
    % Report fps
    avgfps = count / telapsed;
    disp([newline, 'Average framerate: ', num2str(avgfps)]);
    
catch ME
    % In case of error, call 'CloseAll'
    RestrictKeysForKbCheck([]);
    sca;
    rethrow(ME);
    
end  % try

RestrictKeysForKbCheck([]);
Screen('Preference', 'SkipSyncTests', oldsynclevel);
