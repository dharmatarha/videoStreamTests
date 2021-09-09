function vblData = displayTimingTest(eventNo, period)


%% Function for testing display flip timing
%
% USAGE: vblData = displayTimingTest(eventNo, period)
%
% The function flashes the monitor "eventNo" times, with "period" interval 
% between subsequent events. Flashes are accompanied by a TTL-type trigger.
% Flashes last for one refresh cycle (one flip) and are composed of a 
% black-white-black transition.
%
% Inputs:
% eventNo       - Numeric value, integer in range 1:10^4. Number of flashes 
%               and corresponding triggers
% period        - Numeric value, interval between events in secs. Should be 
%               between 0.01 and 10. 
%
% Outputs:
% vblData       - Numeric matrix, contains the flip timestamps for event 
%               onsets and offsets, as reported by Screen('Flip').
%
%


%% Input checks

if nargin ~= 2
    error('Function displayTimingTest requires inputs "eventNo" and "period"!');
endif
if ~ismember(eventNo, 1:10^4)
    error('Input arg "eventNo" should be an integer value in range 1:10^4!');
endif
if ~isnumeric(period) || period < 0.01 || period > 10
    error('Input arg "period" should be between 0.01 and 10!');
endif

disp([char(10), 'Called displayTimingTest with input args: ', ...
    char(10), 'Event number: ', num2str(eventNo), ...
    char(10), 'Period: ', num2str(period), ' secs.']);


%% Settings, params

backgrColor = [0 0 0];  % black background
eventColor = [255 255 255];  % event is white flash
triggerL = 2000;  % trigger length in microseconds
triggerVal = 10;  % trigger value
vblData = zeros(eventNo, 2);


%% Psychtoolbox setup

PsychDefaultSetup(1);
screens = Screen('Screens');
screenNumber = max(screens);
% open onscreen window
[onWin, onWinRect] = Screen('OpenWindow', screenNumber, backgrColor);
% get frame interval
ifi = Screen('GetFlipInterval', onWin);
% set priority
topPriorityLevel = MaxPriority(onWin);
Priority(topPriorityLevel);
% dummy calls
GetSecs; WaitSecs(0.5); KbCheck;
% init parallel port control
ppdev_mex('Open', 1);
% hide cursor
HideCursor(screenNumber);


%% Set flash events interval as a multiple of IFI
waitFrames = period/ifi;
if mod(waitFrames, 1) ~= 0
    waitFrames = round(waitFrames);
    disp([char(10), 'The requested period is not a precise multiple of the ',...
    'inter-flip interval. Period between events is set to ',...
    num2str(waitFrames*ifi) , ' secs instead.']);
endif


%% Events loop

Screen('FillRect', onWin, backgrColor);
Screen('Flip', onWin);

disp([char(10), 'Starting in 3 secs...']);
startTime = GetSecs + 3;

for eventIdx = 1:eventNo

    % Prepare event on window
    Screen('FillRect', onWin, eventColor);

    % Flip event:
    % If first event, flip at "startTime", otherwise flip at 
    % waitFrames-0.5*ifi from the time of the last flip
    if eventIdx == 1
        vbl = Screen('Flip', onWin, startTime - (0.5 * ifi));
    else
        vbl = Screen('Flip', onWin, vbl + (waitFrames - 0.5) * ifi);
    endif
    lptwrite(1, triggerVal, triggerL);

    % Prepare background on window
    Screen('FillRect', onWin, backgrColor);

    % Flip back to background
    backgrVbl = Screen('Flip', onWin, vbl + (0.5 * ifi));

    % store timestamps
    vblData(eventIdx, :) = [vbl, backgrVbl];

end


%% cleanup

ppdev_mex('Close', 1);
Priority(0);
Screen('CloseAll');
ShowCursor(screenNumber);


endfunction
