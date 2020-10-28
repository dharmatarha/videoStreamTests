

% wrap everything in a try-catch construct
try


    % check for working Psychtoolbox + unify key names
    PsychDefaultSetup(1);

    % check for linux (usual Ubuntu 18.04 or 20.04 setups)
    if ~IsLinux
        error('This script was written with linux in mind... Sorry!');
    end

    % open screen OpenWindow
    whichScreen = max(Screen('Screens'));
    win = Screen('OpenWindow', whichScreen);

    % parameters for various PsychVideoDelayLoop calls
    verbLevel = 2;
    myRes = [0 0 1280 720];
    colorVid = 1;
    keyAbort = KbName('Escape');
    timeOut = 30;
    timeMarginEst = 0.008;
    setPresFullFov = 0;
    setPresMirrored = 0;
    setPresUpsideDown = 0;
    captureRate = 30;
    loggingMode = 1;
    loggingMaxSeconds = timeOut+1;
    frameStep = 1;
    delayFrames = 1;
    
    % Set verbosity to high
    PsychVideoDelayLoop('Verbosity', verbLevel);

    % Start a video device
    handle = PsychVideoDelayLoop('Open', win, [], myRes, colorVid);

    % Settings:
    % Set abort key
    PsychVideoDelayLoop('SetAbortKeys', keyAbort);
    % Set timeout
    PsychVideoDelayLoop('SetAbortTimeout', timeOut);
    % Set processing time estimate
    PsychVideoDelayLoop('SetHeadstart', timeMarginEst);
    % Set presentation mode
    PsychVideoDelayLoop('SetPresentation', setPresFullFov, setPresMirrored, setPresUpsideDown);
    % Tune video refresh rate
    fps = PsychVideoDelayLoop('TuneVideoRefresh', captureRate);
    % Set timestamp logging
    PsychVideoDelayLoop('SetLogging', loggingMode, loggingMaxSeconds);
    % Ask for frames to be recorded
    PsychVideoDelayLoop('RecordFrames', frameStep);

    % Start the loop
    PsychVideoDelayLoop('RunLoop', delayFrames);

    % Query the log + recorded frames (texture ids)
    log = PsychVideoDelayLoop('GetLog');
    texIDs = PsychVideoDelayLoop('GetRecordedFrames');

    % Close & cleanup
    PsychVideoDelayLoop('Close');
    Screen('CloseAll');
    sca; close all;

% if    
catch ME
    disp('Error in the try loop:');
    disp(ME.message);
    PsychVideoDelayLoop('Close');
    Screen('CloseAll'); 
    sca; close all; 
    rethrow(ME);
    
end
    
    
    % If it errors out, close video device with:
    % Screen('CloseVideoCapture', handle);






















