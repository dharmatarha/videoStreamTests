
% check for working Psychtoolbox + unify key names
PsychDefaultSetup(1);

% check for linux (usual Ubuntu 18.04 or 20.04 setups)
if ~IsLinux
    error('This script was written with linux in mind... Sorry!');
end

% open screen OpenWindow
whichScreen = max(Screen('Screens'));
win = Screen('OpenWindow', whichScreen);

% Set verbosity to high
verbLevel = 2;
PsychVideoDelayLoop('Verbosity', verbLevel);

% Start a video device
myRes = [0 0 640 480];
colorVid = 1;
handle = PsychVideoDelayLoop('Open', win, [], myRes, colorVid);

% Set abort key
key1 = KbName('Escape');
PsychVideoDelayLoop('SetAbortKeys', key1);
% Set timeout
timeOut = 30;
PsychVideoDelayLoop('SetAbortTimeout', timeOut);
% Set processing time estimate
timeMarginEst = 0.008;
PsychVideoDelayLoop('SetHeadstart', timeMarginEst);

% Set presentation mode
PsychVideoDelayLoop('SetPresentation', 0, 0, 0);

% Set timestamp logging
PsychVideoDelayLoop('SetLogging', 1, timeOut+1);

% Ask for frames to be recorded
PsychVideoDelayLoop('RecordFrames', 1);

% Start the loop
PsychVideoDelayLoop('RunLoop', 0);

% Query the log + recorded frames (texture ids)
log = PsychVideoDelayLoop('GetLog');
texIDs = PsychVideoDelayLoop('GetRecordedFrames');

% Close & cleanup
PsychVideoDelayLoop('Close');

% If it errors out, close video device with:
% Screen('CloseVideoCapture', handle);






















