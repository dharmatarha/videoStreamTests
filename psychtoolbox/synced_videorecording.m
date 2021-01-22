%% UDP handshake + video-audio capture merged 


%% Basic params - video recording

% Import
pkg load sockets;
remoteIP = '10.160.12.108';

moviename = 'mytest.mov';
withsound = 2; % record with sound
windowed = 1;
PsychDefaultSetup(1);
vidLength = 900;  % maximum length for video in secs
Screen('Preference', 'Verbosity', 6);
screen=max(Screen('Screens'));

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
    VBL_Timestamp = nan(vidLength*30, 1);
    Stimulus_OnsetTime = nan(vidLength*30, 1);
    Flip_Timestamp = nan(vidLength*30, 1);
    
    sharedStartTime = handshake(remoteIP);
   
    vidstartAt = sharedStartTime; % video capture delay based on handshake sync 
    
    % Start capture with 30 fps
    [Fps, vidcaptureStartTime] = Screen('StartVideoCapture', grabber, 30, 1, vidstartAt);
  
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
                [VBLTimestamp, StimulusOnsetTime, FlipTimestamp] = Screen('Flip', win); % flip can return 2 timestamps, one at the start of the flip, one at the end
                
                count = count + 1;
                
                % Store frame-specific values
                frameCaptTime(count, 1) = pts;
                droppedFrames(count, 1) = nrdropped;
                VBL_Timestamp(count, 1) = VBLTimestamp;
                Stimulus_OnsetTime(count, 1) = StimulusOnsetTime;
                Flip_Timestamp(count, 1) = FlipTimestamp;
                
            else  % if tex
                WaitSecs('YieldSecs', 0.005);
                
            end  % if tex
      
    end  % while

    % Done, report elapsed time
    telapsed = GetSecs - vidcaptureStartTime;
    
    % Shutdown
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    vidStopTime = GetSecs; 
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    vidCloseTime = GetSecs; 
    tmp = isequal(vidStopTime, vidCloseTime);
    
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

% get timestamps for everything: flip --> save to vector, stopvidecapture, etc.
% merge with handshake procedure




