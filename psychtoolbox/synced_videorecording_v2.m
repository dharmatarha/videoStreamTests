%% UDP handshake + video-audio capture merged 


% Import
pkg load sockets;
remoteIP = '10.160.12.108';

% Basic params - video recording
moviename = 'mytest1.mov';
windowed = 1;
PsychDefaultSetup(1);
vidLength = 900;  % maximum length for video in secs
Screen('Preference', 'Verbosity', 3);
screen=max(Screen('Screens'));

% Perform basic initialization of the sound driver:
InitializePsychSound;
wavfilename = 'myaudio.wav';

% get correct audio device
device = [];  % system default is our default as well
% we only change audio device in the lab, when we see the correct audio
% card
tmpDevices = PsychPortAudio('GetDevices');
for i = 1:numel(tmpDevices)
    if strncmp(tmpDevices(i).DeviceName, 'ESI Juli@: ICE1724', 18) && strcmp(tmpDevices(i).DeviceName(end-2:end), ',0)')
        device = tmpDevices(i).DeviceIndex;
    end
end


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



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

%% Open device + Start capture
try
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    win = Screen('OpenWindow', screen, 0, [0 0 1400 850]);
    Screen('Flip', win);
    Screen('TextSize', win, 24);
    
    % preallocate frame info holding vars
    frameCaptTime = nan(vidLength*30, 1);
    droppedFrames = nan(vidLength*30, 1);
    VBL_Timestamp = nan(vidLength*30, 1);
    Stimulus_OnsetTime = nan(vidLength*30, 1);
    Flip_Timestamp = nan(vidLength*30, 1);
    
    % Vide device params
    waitForImage = 1;
    
    % open & start audio feedback     
    %pa = PsychPortAudio('Open', [], 4+2+1, [], [], 2);   
    %painput = PsychPortAudio('Open', [], 2+1, 1, [], channels, [], [], selectchannels); % under 'channels' optionally we can define a 2 element vector specifying different channels for input / output
    painput = PsychPortAudio('Open', [], 2+1, 1);
    paoutput = painput;
    
    
    % Preallocate an internal audio recording  buffer with a capacity of at least
    % 10 seconds, possibly more if requested latency is higher:
    lat = 150/1000;
    PsychPortAudio('GetAudioData', painput, max(2 * lat, 10));
      
    % Allocate a zero-filled (ie. silence) output audio buffer of more than
    % sufficient size: Three times the requested latency, but at least 30 seconds.
    % One could do this more clever, but this is a safe no-brainer and memory
    % is cheap:
    outbuffersize = floor(freq * 3 * max(lat, 10));
    PsychPortAudio('FillBuffer', paoutput, zeros(2, outbuffersize));    
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, [0 0 1280 720], [], [], [], codec, withsound, [], 8);
     
    KbReleaseWait;
    WaitSecs('YieldSecs', 2);

    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    sharedStartTime = handshake(remoteIP);
   
    vidstartAt = sharedStartTime; % video capture delay based on handshake sync 
    
    % Start capture with 30 fps
    [Fps, vidcaptureStartTime] = Screen('StartVideoCapture', grabber, 30, 1, vidstartAt);
    
    % start audio right away
    playbackstart = PsychPortAudio('Start', paoutput, 0, [], 1);
    
    % Wait until at least captureQuantum seconds of sound are available from the capture
    % device and then quickly fetch it from the capture device. captureQuantum
    % is the minimum amount of sound data that the driver can capture. If you'd
    % ask for less you'd get at least this amount anyway + possibly extra
    % delays:
    s = PsychPortAudio('GetStatus', painput);
    headroom = 1;
    headroom = round(headroom);
    captureQuantum = headroom * (s.BufferSize / s.SampleRate);
##    if verbose > 1
##      fprintf('CaptureQuantum (Duty cycle length) is %f msecs, for a buffersize of %i samples.\n', captureQuantum * 1000, s.BufferSize);
##    end
    
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
    reqonsettime = capturestart + lat;
    
    % Sanity check: Are we ahead of the playback stream with our requested
    % onset time of reqonsettime? If not, then the system won't be able to
    % achieve the requested 'lat'ency and we'll be late!
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
    
    % Get current status of outputdevice:
    s1 = PsychPortAudio('GetStatus', paoutput);
    
    oldcaptureQuantum = -1;
    cumoverrun   = 0;
    cumunderflow = 0;
    
    temp = GetSecs;
    
    recordedaudio = [];
    
    % Run until keypress or until maximum allowed time is reached
        while ~KbCheck && GetSecs < vidstartAt+vidLength
             
            % Wait blocking for next image then return it as texture
            [tex, pts, nrdropped] = Screen('GetCapturedImage', win, grabber, waitForImage, oldtex);
    
               % If a texture is available, draw and show it.
                if tex > 0
                    % Print capture timestamp in seconds since start of capture:
                    Screen('DrawText', win, sprintf('Capture time (secs): %.4f', pts), 0, 0, 255);
    
                    % Draw new texture from framegrabber.
                    Screen('DrawTexture', win, tex);
                    oldtex = tex;
                    [VBLTimestamp, StimulusOnsetTime, FlipTimestamp] = Screen('Flip', win); % flip can return 2 timestamps, one at the start of the flip, one at the end
                    
                    count = count + 1;
                    
                    % Store frame-specific values
                    frameCaptTime(count, 1) = pts;
                    droppedFrames(count, 1) = nrdropped;
                    VBL_Timestamp(count, 1) = VBLTimestamp;
                    Stimulus_OnsetTime(count, 1) = StimulusOnsetTime;
                    Flip_Timestamp(count, 1) = FlipTimestamp;
                    
                end  % if tex
              
                
            captureQuantum = updateQuantum;

              if captureQuantum ~= oldcaptureQuantum
                oldcaptureQuantum = captureQuantum;
##                if verbose > 1
##                  fprintf('Duty cycle adapted to %f msecs...\n', 1000 * captureQuantum);
##                end
              end
              
              % Get new captured sound data ...
              fetchDelay = GetSecs;
              [audiodata, offset, overrun] = PsychPortAudio('GetAudioData', painput, [], captureQuantum);
              fetchDelay = GetSecs - fetchDelay;
              underflow = 0;
                           
              % ... and stream it into our output buffer:
              while size(audiodata, 2) > 0
                % Make sure to never push more data in the buffer than it can
                % actually hold, ie not more than half its maximum capacity:
                fetch = min(size(audiodata, 2), floor(outbuffersize / 2));
                % We feed data in chunks of 'fetch' samples:
                pushdata = audiodata(:, 1:fetch);
                % audiodata is the remainder which will be pushed in the next loop
                % iteration:
                audiodata = audiodata(:, fetch+1:end);
                
                % Perform streaming buffer refill. As long as we don't push more
                % than a buffer size, the driver will take care of the rest...
                [curunderflow, nextSampleStartIndex, nextSampleETASecs] = PsychPortAudio('FillBuffer', paoutput, pushdata, 1);
                underflow = underflow + curunderflow;
              end
              
              % get all audiodata
              recordedaudio = [recordedaudio pushdata];
              
              % Check for xrun conditions from low-level sound hardware:
              s1 = PsychPortAudio('GetStatus', paoutput);
              s2 = PsychPortAudio('GetStatus', painput);
              xruns = s1.XRuns + s2.XRuns;
                          
              cumoverrun = cumoverrun + overrun;
              cumunderflow = cumunderflow + underflow;

              % Done. Next iteration...
                            
        end  % while
        
  
    PsychPortAudio('Stop', paoutput);
    PsychPortAudio('Stop', painput);
    % Drain its capture buffer...
    PsychPortAudio('GetAudioData', painput);
    % Done - Close device and driver:
    PsychPortAudio('Close'); 
    
    % store recorded audio in wavfile
    psychwavwrite(transpose(recordedaudio), freq, 16, wavfilename);
    
    % Done, report elapsed time
    telapsed = GetSecs - vidcaptureStartTime;
    
    % Shutdown
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    vidStopTime = GetSecs; 
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    vidCloseTime = GetSecs; 
    
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
disp([char(10), 'Start of capture: ', num2str(vidcaptureStartTime)]);
disp([char(10), 'diff: ', num2str(vidcaptureStartTime - vidstartAt)]);
disp([char(10), 'Elapsed time: ', num2str(telapsed), ' secs']); 

RestrictKeysForKbCheck([]);

Screen('Preference', 'SkipSyncTests', oldsynclevel);



