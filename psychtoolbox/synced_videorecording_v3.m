function synced_record(pairNo, labName)

%% UDP handshake + video-audio capture and playback.
%
% Initial script for minimal-latency audiovisual channel between two labs
% located right next to each other.
% To be ran on two separate stimulus control PCs, both recording in a lab and
% displaying its recordings in the other lab. The PCs are assumed to be
% temporally synced (simply by syncing to the same NTP time server on the local
% network).
%


% Import
pkg load sockets;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%    HELPER FUNCTIONS    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Helper function for "handshake", that is, for negotiating a shared start
% time across local and remote PCs
function sharedStartTime = handshake(remoteIP)
      %% handshake 

      % Constants
      maxTimeOut = 60;  % maximum allowed time for the handshake in secs
      waitTime = 0.05;  % time between sending packets when repeatedly doing so, in both stages, in secs
      maxDiff = 1;  % maximum allowed difference for the two timestamps (local and remote) in the second stage
      startDelay = 5; % shared start time is the average of the two timestamps (local and remote) + startDelay, in secs
      localPort = 9998;
      %remoteIP = '10.160.21.140';
      %remoteIP = '10.160.12.108';
      remotePort = 9998;
      remoteAddr = struct('addr', remoteIP, 'port', remotePort);
      initMessage = 'kuldj egy jelet';
      
     % Dummy calls for Psychtoolbox functions
      GetSecs; WaitSecs(0.1);
      
      % Open socket, connect it to remote address
      udpSocket = socket(AF_INET, SOCK_DGRAM);
      bind(udpSocket, localPort);
      connect(udpSocket, remoteAddr);
      
      %% First stage
      
      % While loop with timeout
      successFlag = 0;
      stageStart = GetSecs;
      while ~successFlag && (GetSecs-stageStart) < maxTimeOut
          % try reading from the socket
          [incomingMessage, count] = recv(udpSocket, 512, MSG_DONTWAIT);  % non-blocking
          % if there was incoming packet and it matches initMessage, 
          % send last messages and move on
          if count ~= -1
              disp(incomingMessage);
          endif
          if count ~= -1 && strcmp(char(incomingMessage), initMessage)
              % send initMessage twice 
              for i = 1:2
                  send(udpSocket, initMessage);
              endfor
              % set flag for exiting the while loop
              successFlag = 1; 
              disp([char(10), 'Received expected message in first stage, moving on.']);
          % if there was no incoming packet or it did not match initMessage,
          % send initMessage  
          else
              send(udpSocket, initMessage);
          endif
          % wait a bit before next iteration
          WaitSecs(waitTime);
      endwhile
      
      % Check for timeout
      if ~successFlag
          disconnect(udpSocket);
          error('Handshake procedure timed out during first stage!');
      endif
      
      
      %% Second stage
      
      % While loop with timeout
      successFlag = 0;
      stageStart = GetSecs;
      timeMessage = num2str(stageStart, '%.5f');  % packet requires string or uint8
      while ~successFlag && (GetSecs-stageStart)<maxTimeOut
          % try reading from the socket
          [incomingMessage, count] = recv(udpSocket, 512, MSG_DONTWAIT);  % non-blocking
          % if there was incoming packet and it is a timestamp close to timeMessage,
          % send last messages and move on
          if count ~= -1
              disp(incomingMessage);
          endif
          if count ~= -1 && abs(str2double(char(incomingMessage))-stageStart) < maxDiff
              % send timeMessage twice 
              for i = 1:2
                  send(udpSocket, timeMessage);
              endfor
              % set flag for exiting the while loop
              successFlag = 1;
              disp([char(10), 'Received timestamp-like message in second stage, moving on.']);
          % if there was no incoming packet or it did not match timeMessage,
          % send timeMessage
          else
              send(udpSocket, timeMessage);
          endif
          % wait a bit before next iteration
          WaitSecs(waitTime);
      endwhile
      
      % Check for timeout
      if ~successFlag
          disconnect(udpSocket);
          error('Handshake procedure timed out during second stage!');
      
      endif
      
      
      %% Get shared start time
      
      sharedStartTime = (str2double(char(incomingMessage)) + stageStart)/2 + startDelay;
      disp([char(10), 'Calculated shared start time, handshake successful!']);   
      
      %% Cleanup
      
      disconnect(udpSocket); 
      
endfunction


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%    MAIN    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% check inputs
if nargin ~= 2
    error("Need two input args, pairNo and labName!");
end
if ~isnumeric(pairNo) || ~ismember(pairNo, 1:99)
    error("Input arg pairNo should be between 1-99!");
end
if ~ischar(labName) || ~ismember(labName, {"Mordor", "Gondor"})
    error("Input arg labName should be one of Mordor/Gondor as char array!");
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Basic settings, params, preallocation

% Network address of remote PC for handshake
remoteIP = "10.160.21.115";

% save file name
savefile = ["pair", num2str(pairNo), labName, "_times.mat"];

% Params for audio + video recording
moviename = ["pair", num2str(pairNo), labName, ".mov"];
vidLength = 1800;  % maximum length for video in secs
wavfilename = ["pair", num2str(pairNo), labName, ".wav"];
freq = 44100;
audioDevMode = 2+1;  % 1 = playback only; 2 = recording only; 3 = playback + recording
audioReqLatencyClass = 2;  % 0 = play nicely, no pushing for low-latency; 1 = aim for low-latency; 2 = agressively aim for low-latency (full control)
audioLatency = 0.025;  % intended latency for audio recording - playback loop, in secs
capturebinspec = 'v4l2src device=/dev/video0 ! image/jpeg,width=1920,height=1080,framerate=30/1 ! jpegdec ! videoconvert';  % custom Gstreamer pipeline definition
codec = ':CodecType=DEFAULTencoder';  % default codec
codec = [moviename, codec];
waitForImage = 0;  % setting for Screen('GetCapturedImage'), 0 = polling (non-blocking); 1 = blocking wait for next image
vidSamplingRate = 30;  % expected video sampling rate, real sampling rate will differ
vidDropFrames = 1;  % dropframes flag for StartVideoCapture, 0 = do not drop frames; 1 = drop frame if necessary, only return the last cpatured frame
vidRecFlags = 16;  % recordingflags arg for OpenVideoCapture, 16 = use parallel thread in background
backgroundColor = [0, 0, 0];  % general screen openwindow background color
windowTextSize = 24;  % general screen openwindow text size

% preallocate frame info holding vars, adjust for potentially higher-than-expected sampling rate
frameCaptTime = nan((vidLength+60)*vidSamplingRate, 1);
flipTimeStamps = nan((vidLength+60)*vidSamplingRate, 3);  % three columns for the three flip timestamps returned by Screen
droppedFrames = frameCaptTime;

% preallocate audio data var, for two channels
recordedaudio = zeros(2, (vidLength+60)*freq);
recAudioCounter = 0;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Psychtoolbox initializations

Priority(1);
PsychDefaultSetup(1);
InitializePsychSound;
Screen('Preference', 'Verbosity', 3);
screen=max(Screen('Screens'));
RestrictKeysForKbCheck(KbName('ESCAPE'));  % only report ESCape key press via KbCheck
GetSecs; WaitSecs(0.5);  % dummy calls
oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);  % skip tests

% get correct audio device - we are looking for an ESI Juli@ card with address (hw:2,0) or (hw:3,0)
audioDevice = [];  % empty == system default
% we only change audio device in the lab, when we see the correct audio card
tmpDevices = PsychPortAudio('GetDevices');
for i = 1:numel(tmpDevices)
    if strncmp(tmpDevices(i).DeviceName, 'ESI Juli@: ICE1724', 18) && strcmp(tmpDevices(i).DeviceName(end-2:end), ',0)')
        audioDevice = tmpDevices(i).DeviceIndex;
        disp(['Found ESI Juli@ soundcard, will use the corresponding device: ', tmpDevices(i).DeviceName]);
    end
end

% Try to set video capture to custom pipeline
try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));
catch ME
    disp('Failed to set Screen(''SetVideoCaptureParameter''), errored out.');
    sca; 
    rethrow(ME);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Open devices + Start capture

try
    % Open onscreen window for video playback
    win = Screen('OpenWindow', screen, backgroundColor);
    Screen('TextSize', win, windowTextSize);  % set text size for win
    Screen('Flip', win);  % initial flip to background
    
    % open audio device
    painput = PsychPortAudio('Open', audioDevice, audioDevMode, audioReqLatencyClass);
    paoutput = painput;  % different handle for output (playback)
    
    % Preallocate an internal audio recording  buffer with a capacity of at least
    % 10 seconds, possibly more if requested latency is higher:
    PsychPortAudio('GetAudioData', painput, max(2 * audioLatency, 10));
      
    % Allocate a zero-filled (ie. silence) output audio buffer of more than
    % sufficient size: Three times the requested latency, but at least 30 seconds.
    % One could do this more clever, but this is a safe no-brainer and memory
    % is cheap:
    outbuffersize = floor(freq * 3 * max(audioLatency, 10));
    PsychPortAudio('FillBuffer', paoutput, zeros(2, outbuffersize));    
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, [], [], [], [], codec, vidRecFlags);
    % Wait a bit for OpenVideoCapture to return
    KbReleaseWait;
    WaitSecs('YieldSecs', 1);
    
    sharedStartTime = handshake(remoteIP);
    
    % Start capture with 30 fps
    [Fps, vidcaptureStartTime] = Screen('StartVideoCapture', grabber, vidSamplingRate, vidDropFrames, sharedStartTime);
    
    % start audio playback right away
    playbackstart = PsychPortAudio('Start', paoutput, 0, [], 1);
    
    % Wait until at least captureQuantum seconds of sound are available from the capture
    % device and then quickly fetch it from the capture device. captureQuantum
    % is the minimum amount of sound data that the driver can capture. If you'd
    % ask for less you'd get at least this amount anyway + possibly extra
    % delays:
    s = PsychPortAudio('GetStatus', painput);
    headroom = 5;
    headroom = round(headroom);
    captureQuantum = headroom * (s.BufferSize / s.SampleRate);
    fprintf('CaptureQuantum (Duty cycle length) is %f msecs, for a buffersize of %i samples.\n', captureQuantum * 1000, s.BufferSize);
    [audiodata offset overflow capturestart] = PsychPortAudio('GetAudioData', painput, [], captureQuantum);
    
    % Sanity check returned values: audiodata should be at least headroom * s.BufferSize
    % samples, offset should be zero as this is the first 'GetAudioData' call
    % since 'Start' of capture. overflow should be zero, otherwise we screwed
    % up our timing already in the first few milliseconds because the system is
    % not up to the task / overloaded for the requested latency settings.
    % 'capturestart' contains the estimated time when the first returned audio
    % sample hit the microphone / line-in connector:
    if (size(audiodata, 2) < headroom * s.BufferSize) || (offset~=0) || (overflow > 0)
      fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
      fprintf('Realsize samples %i < Expected size %i? Or offset %i ~= 0 ? Or overflow %i > 0 ?\n', size(audiodata, 2), headroom * s.BufferSize, offset, overflow);
      timingfailed = 1;
    end
    
    % Ok, we have our initial batch of audio samples in 'audiodata', recorded
    % at time 'capturestart'. The sound output is currently feeding zeroes
    % (=silence) from the zero-filled output buffer to the speakers and the
    % first zero-sample in that buffer will hit the speakers at time
    % 'playbackstart'. We now need to copy our 'audiodata' batch of samples
    % into the output buffer, but at an offset from the start that is selected
    % to exactly achieve output of our first 'audiodata' sample at the
    % requested latency.
    %
    % The first sample was captured at time 'capturestart' and the requested
    % latency for output is 'lat': Therefore the wanted playback time for this
    % first sample is...
    reqonsettime = capturestart + audioLatency;
    
    % Sanity check: Are we ahead of the playback stream with our requested
    % onset time of reqonsettime? If not, then the system won't be able to
    % achieve the requested audioLatency and we'll be late!
    s = PsychPortAudio('GetStatus', paoutput);
    if s.CurrentStreamTime > reqonsettime
      fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
      fprintf(['Requested onset at time %f seconds, but audio stream is already at time %f seconds\n--> ' ...
      'We will be at least %f msecs too late!\n'], reqonsettime, s.CurrentStreamTime, 1000 * (s.CurrentStreamTime - reqonsettime));
      timingfailed = 2;
    end
    
    % The first sample from the output buffer will playback at time
    % 'playbackstart', therefore our first sample should be placed at a
    % timeoffset relative to the start of the outputbuffer of...
    reqtimeoffset = reqonsettime - playbackstart;
    
    % Our first audio sample needs to be placed at a time offset of
    % 'reqtimeoffset' in the audio output buffer, overwriting the "silence"
    % there. Map offset in seconds to offset in samples: The system plays out
    % s.SampleRate samples per second, so we need to place our audio at an
    % offset of...
    reqsampleoffset = round(reqtimeoffset * s.SampleRate);
    
    if reqsampleoffset < 0
      fprintf('If sound feedback works at all, then extra latency will be at least %f msecs, probably more!\n', 1000 * abs(reqtimeoffset));    
    end
    
    % Make sure the offset is positive, ie at least zero:
    reqsampleoffset = max(reqsampleoffset, 0);
    
    % Overwrite the output buffer with our captured audiodata, starting at
    % sample index 'reqsampleoffset'. Need to set the 'streamingrefill' flag to
    % 1 in order to enable this special overwrite mode. The 'underflow' flag
    % will tell us if we made the refill in time, or if we "missed the train"
    % in the last microsecond: A non-zero value means we missed.
    [underflow, nextSampleStartIndex, nextSampleETASecs] = PsychPortAudio('FillBuffer', paoutput, audiodata, 1, reqsampleoffset);
    
    s = PsychPortAudio('GetStatus', paoutput);
    if underflow > 0
      fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
      fprintf(['Requested onset at time %f seconds, but audio stream is already at time %f seconds\n--> ' ...
      'We will lose at least the first %f msecs of the sound signal!\n'], reqonsettime, s.CurrentStreamTime, 1000 * (s.CurrentStreamTime - reqonsettime));
      timingfailed = 3;
    end
    
    % Ok, if we made it until here without a non-zero 'timingfailed' flag, then
    % at least the first few milliseconds of captured sound should play at
    % exactly the desired 'lat'ency between capture and playback.
    
    % From now on we'll just need to periodically fetch chunks of audio data
    % from the capture device and feed it into the output device without any
    % complex math or tricks involved. However in order to avoid dropouts and
    % other audible artifacts we need to make sure that we feed new data fast
    % enough. We will now execute a loop that tries to fetch audio in the
    % smallest possible quantity from the capturedevice, then immediately
    % append it to the output buffer:
    updateQuantum = s.BufferSize / s.SampleRate;
    captureQuantum = updateQuantum;
    
    % Get current status of outputdevice:
    s1 = PsychPortAudio('GetStatus', paoutput);
    
%    oldcaptureQuantum = -1;
    cumoverrun   = 0;
    cumunderflow = 0;
    
%    temp = GetSecs;
    
##    recordedaudio = [];
    
    % helper variables for the display loop
    oldtex = 0;
    vidFrameCount = 1;
    
    % Run until keypress or until maximum allowed time is reached
    while ~KbCheck && GetSecs < sharedStartTime+vidLength
         
        % Check for next available image, return it as texture if there was one
        [tex, frameCaptTime(vidFrameCount), droppedFrames(vidFrameCount)] = Screen('GetCapturedImage', win, grabber, waitForImage, oldtex);  
        
        % If a texture is available, draw and show it.
        if tex > 0
            % Check for completion of previous asynchronous flip.
            % Previous flip should have finished way earlier as screen refresh
            % rate is higher than video capture rate
            if vidFrameCount > 1  % only from the second frame on
                flipTimestamps(vidFrameCount-1, 1:3) = Screen('AsyncFlipEnd', win);  % timestamps belong to previous frame, hence the minus 1 index
            endif
            
            % Print capture timestamp in seconds since start of capture:
            Screen('DrawText', win, sprintf('Capture time (secs): %.4f', frameCaptTime(vidFrameCount)), 0, 0, 255);
            % Draw new texture from framegrabber.
            Screen('DrawTexture', win, tex);
            oldtex = tex;
            % Asyncronous flip - non-blocking, only schedules the buffer for next screen refresh
            Screen('AsyncFlipBegin', win);
            
            % adjust video frame counter
            vidFrameCount = vidFrameCount + 1;
            
        end  % if tex
        
        
%        captureQuantum = updateQuantum;
        
%        if captureQuantum ~= oldcaptureQuantum
%            oldcaptureQuantum = captureQuantum;
%                if verbose > 1
%                  fprintf('Duty cycle adapted to %f msecs...\n', 1000 * captureQuantum);
%                end
%        end
      
        % Get new captured sound data...
%        fetchDelay = GetSecs;
        [audiodata, offset, overrun] = PsychPortAudio('GetAudioData', painput, [], captureQuantum);
%        fetchDelay = GetSecs - fetchDelay;
        underflow = 0;
        % ... and stream it into our output buffer:
        curunderflow = PsychPortAudio('FillBuffer', paoutput, audiodata, 1);
        underflow = underflow + curunderflow;
        
        % get all audiodata
        recordedaudio(:, recAudioCounter+1:recAudioCounter+size(audiodata,2)) = audiodata;
        recAudioCounter = recAudioCounter + size(audiodata, 2);
%        recordedaudio = [recordedaudio audiodata];
        
        % Check for xrun conditions from low-level sound hardware:
        s1 = PsychPortAudio('GetStatus', paoutput);
        s2 = PsychPortAudio('GetStatus', painput);
        xruns = s1.XRuns + s2.XRuns;
        
        cumoverrun = cumoverrun + overrun;
        cumunderflow = cumunderflow + underflow;

        % Done. Next iteration...
        
    end  % while
    
    % close audio devices
    PsychPortAudio('Stop', paoutput);
    PsychPortAudio('Stop', painput);
    % Drain its capture buffer...
    PsychPortAudio('GetAudioData', painput);
    % Done - Close device and driver:
    PsychPortAudio('Close'); 
    
    % store recorded audio in wavfile
    if recAudioCounter < size(recordedaudio, 2)
        recordedaudio(:, recAudioCounter+1:end) = [];
    endif
    psychwavwrite(transpose(recordedaudio), freq, 16, wavfilename);
    
    % Done, report elapsed time
    telapsed = GetSecs - vidcaptureStartTime;
    
    % Shutdown
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    vidStopTime = GetSecs; 
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    vidCloseTime = GetSecs; 
    RestrictKeysForKbCheck([]);
    sca;

    % Save major timestamps
    save(savefile, "sharedStartTime", "videoCaptureStartTime", "playbackstart",...
    "frameCaptTime", "vidFrameCount", "flipTimestamps", "vidStopTime",...
    "vidCloseTime", "telapsed");

    % Report fps
    avgfps = vidFrameCount / telapsed;
    disp([char(10), 'Average framerate: ', num2str(avgfps)]);

catch ME
    % In case of error, close screens, psychportaudio
    Priority(0);
    RestrictKeysForKbCheck([]);
    sca;
    PsychPortAudio('Close');
    % Stop capture engine and recording - this might error out itself if the
    % original error is related to the video capture
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording
    Screen('CloseVideoCapture', grabber);
    % Save major timestamps if we can
    save(savefile, "sharedStartTime", "videoCaptureStartTime", "playbackstart",...
    "frameCaptTime", "vidFrameCount", "flipTimestamps", "vidStopTime",...
    "vidCloseTime", "telapsed");
    rethrow(ME);
    
end  % try

% report start time of capture, elapsed time 
disp([char(10), 'Start of capture: ', num2str(vidcaptureStartTime)]);
disp([char(10), 'diff: ', num2str(vidcaptureStartTime - sharedStartTime)]);
disp([char(10), 'Elapsed time: ', num2str(telapsed), ' secs']); 

Screen('Preference', 'SkipSyncTests', oldsynclevel);
Priority(0);

return
