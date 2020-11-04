function [startTime, count, frameCaptTime, droppedFrames] = CustomGstreamerDemo(moviename, withsound, showit, windowed)
% USAGE: [startTime, count, frameCaptTime, droppedFrames] = CustomGstreamerDemo(moviename [, withsound=1] [, showit=1] [, windowed=1])
%
% Based on VideoRecordingDemo from Psychtoolbox 3.0.16.
%
% Demonstrates simple video capture and recording to a movie file using a
% custom GStreamer pipeline.
%
% The demo starts the videocapture engine, recording video from the default
% video source and (optionally) sound from the default audio source. It
% encodes the video+audio data and writes it to the
% 'moviename' movie file. Optionally it previews the recorded
% video onscreen (often at a much lower framerate to keep system load low
% enough for reliable recording). Recording ends if any key is pressed on
% the keyboard.
%
% Arguments and their meaning:
%
% 'moviename' name of output movie file. The file must not exist at start
% of recording, otherwise it is overwritten.
%
% 'codec' Indicate the type of video codec you want to use.
% Defaults to "whatever the system default is". Some codecs are very fast,
% i.e., high framerates and low system load, others provide high compression
% rates, i.e., small video files at good quality. Usually there's a tradeoff
% between encoding speed, quality and compression ratio, so you'll have to try
% out different ones to find one suitable for your purpose. Some codecs only
% work at specific framerates or for specific image sizes.
%
% The supported codecs and settings with GStreamer can be found in the code
% and are explained in 'help VideoRecording'.
%
% Empirically, the MPEG-4 or H264 codecs seem to provide a good tradeoff
% between quality, compression, speed and cpu load. They allow to reliably
% record drop-free sound and video with a resolution of 640x480 pixels at
% 30 frames per second.
%
% H.264 has better quality and higher compression, but is able to nearly
% saturate a MacBookPro, so reliable recording at 30 fps may be difficult
% to achieve or needs more powerful machines.
%
% Some of the other codecs may provide the highest image quality and lowest
% cpu load, but they also produce huge files, e.g., all the DVxxx codecs
% for PAL and NTSC video capture, as well as the component video codecs.
%
% 'withsound' If set to non-zero, sound will be recorded as well. This is
% the default.
%
% 'showit' If non-zero, video will be shown onscreen during recording
% (default: Show it). Not showing the video during recording will
% significantly reduce system load, so this may help to sustain a skip free
% recording on lower end machines.
%
% 'windowed' If set to non-zero, show captured video in a window located at
% the top-left corner of the screen, instead of fullscreen. Windowed
% display is the default.
%


%% Input checks

if nargin < 1
    error('Function CustomGstreamerDemo requires input arg "moviename"!');
end
if nargin < 2 
    % A setting of '2' (ie 2nd bit set) means: Enable sound recording.
    withsound = 2;
end
if nargin < 3 
    showit = 1;
end
if nargin < 4 
    windowed = 1;
end

disp([newline, 'Function CustomGstreamerDemo started with input args:',...
    newline, 'Movie file name: ', moviename,...
    newline, 'Sound setting (withsound): ', num2str(withsound),...
    newline, 'Display (showit): ', num2str(showit),...
    newline, 'Small window if display is on (windowed): ', num2str(windowed)]);


%% Basics

% Test if we're running on PTB-3 + unify key names
PsychDefaultSetup(1);
% Test if running on Linux, abort otherwise
if ~IsLinux
    error('The function is for Linux, win / osx would require different settings...');
end

% maximum length for video in secs
maxTime = 900;

% Only report ESCape key press via KbCheck:
RestrictKeysForKbCheck(KbName('ESCAPE'));

% set verbosity to high
Screen('Preference', 'Verbosity', 6);

% Open window on secondary display, if any:
screen=max(Screen('Screens'));

disp([newline, 'Basic settings OK']);


%% Settings for custom Gstreamer source

% We use a Logitech c920 camera which offers two image/video formats, YUYV
% and MJPG. Our aim is to obtain high fps with a good resolution and that
% is only offered with MJPG format. Psychtoolbox tries to use the default
% YUYV format so we need to feed a custom Gstreamer pipe to it.

% Custom gstreamer settings:
% "v4l2src" is the plugin for vidoe4linux2 devices
% "jpegdec" is needed for webcam, see https://gstreamer.freedesktop.org/data/doc/gstreamer/head/gst-plugins-good/html/gst-plugins-good-plugins-v4l2src.html
% "v4l2src" is the plugin for vidoe4linux2 devices
% "videoconvert" is for automatic encoding for the sink (which is not
% specified here)
capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec ! videoconvert';
% capturebinspec = 'v4l2src device=/dev/video0 ! jpegdec';

% Assign capturebinspec as gst-launch style capture bin spec for use as video source:

% From Screen('SetVideoCaptureParameter?'):
% "
% 'SetNextCaptureBinSpec=xxx'
% Will set the gst-launch line which describes the video capture source to be used
% during the next call to Screen('OpenVideoCapture', -9, ...); Opening a video
% capture device with the special deviceIndex -9 means to create a GStreamer bin
% and use it as video source. The bin is created by parsing the string passed
% here. Use the special 'capturePtr' value -1 when setting this bin description,
% as this call may need to be made while a capture device is not yet opened, so no
% valid 'capturePtr' exists. This setting is only honored on the GStreamer video
% capture engine.
% "

Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', capturebinspec));

% Signal to Screen() that a special string should be used. This via special deviceId -9:
deviceId = -9;

% Select codec

% From VideoRecordingDemo comments:    
% Good codecs:
%codec = ':CodecType=avenc_mpeg4' % % MPEG-4 video + audio: Ok @ 640 x 480.
%codec = ':CodecType=x264enc Keyframe=1 Videobitrate=8192 AudioCodec=alawenc ::: AudioSource=pulsesrc ::: Muxer=qtmux'  % H264 video + MPEG-4 audio: Tut seshr gut @ 640 x 480
%codec = ':CodecType=VideoCodec=x264enc speed-preset=1 noise-reduction=100000 ::: AudioCodec=faac ::: Muxer=avimux'
%codec = ':CodecSettings=Keyframe=60 Videobitrate=8192 '
    
% We expect Linux, where we can assign default auto-selected codec:
codec = ':CodecType=DEFAULTencoder';
% Add movie file name
codec = [moviename, codec];

% Depth format
depth = 4;

% Set recording flags:
% Setting the 5th bit (bit 4) aka adding
% +16 will offload the recording to a separate processing thread. Pure
% recording is then fully automatic and makes better use of multi-core
% processor machines.
recordingflags = withsound + 16;

% ROI / resolution:
roi = [0 0 1280 720];

% Bit depth
bpc = 8;

% Target fps
requestedFps = 30;

% Frame dropping setting for video
% From Screen('StartVideoCapture?'):
% "
% If 'dropframes' is provided and set to 1, the device is requested to always
% deliver the most recently acquired frame, dropping previously captured but not
% delivered frames if necessary. The default is to queue up as many frames as
% possible. If you want to do video recordings, you want to have the default of
% zero. If you want to do interactive realtime processing of video data (e.g,
% video feedback for action-perception studies or build your own low-cost
% eyetracker), then you want to use dropframes=1 for lowest possible latency.
% "
dropframes = 1;

% Set video params for live feed vs. only recording
if showit > 0
    % We perform blocking waits for new images:
    waitforimage = 1;
else
    % We only grant processing time to the capture engine, but don't expect
    % any data to be returned and don't wait for frames:
    waitforimage = 4;
    % Setting the 3rd bit of 'recordingflags' (= adding 4) disables some
    % internal processing which is not needed for pure disk recording. This
    % can safe significant amounts of processor load --> More reliable
    % recording on low-end hardware. 
    recordingflags = recordingflags + 4;
end

disp([newline, 'Settings for custom Gstreamer source OK']);


%% Open device + Start capture

try
    if windowed > 0
        % Open window in top left corner of screen. We ask PTB to continue
        % even in case of video sync trouble, as this is sometimes the case
        % on OS/X in windowed mode - and we don't need accurate visual
        % onsets in this demo anyway:
        oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
        
        % Open 800x600 pixels window at top-left corner of 'screen'
        % with black background color:
        win=Screen('OpenWindow', screen, 0, [0 0 1500 900]);
    else
        % Open fullscreen window on 'screen', with black background color:
        oldsynclevel = Screen('Preference', 'SkipSyncTests');
        win=Screen('OpenWindow', screen, 0);
    end
    
    % Initial flip to a blank screen:
    Screen('Flip',win);
    
    % Set text size for info text. 24 pixels is also good for Linux.
    Screen('TextSize', win, 24);
    
    % Open device
    grabber = Screen('OpenVideoCapture', win, deviceId, roi, depth, [], [], codec, recordingflags, [], bpc);

    disp([newline, 'Video capture device opened']);
    
    % Wait a bit between 'OpenVideoCapture' and start of capture below.
    % This gives the engine a bit time to spin up and helps avoid jerky
    % recording at the first iteration after startup of Octave/Matlab.
    % Successive recording iterations won't need this anymore:
    WaitSecs('YieldSecs', 2);
    
    % Wait for keys to be released before starting capture
    KbReleaseWait;

    % Define helper variables for the display loop
    oldtex = 0;
    count = 0;
    
    % preallocate frame info holding vars
    frameCaptTime = nan(maxTime*requestedFps, 1);
    droppedFrames = nan(maxTime*requestedFps, 1);
    
    % Start capture with target fps. Capture hardware will fall back to
    % fastest supported framerate if it is not supported. Note that some
    % cameras override fps based on lighting conditions.
    [captureFps] = Screen('StartVideoCapture', grabber, requestedFps, dropframes);

    disp([newline, 'StartVideoCapture returned fps: ', num2str(captureFps)]);
    disp([newline, 'Starting display', newline]);
    
    startTime = GetSecs;
    % Run until keypress or until maximum allowed time is reached
    while ~KbCheck && GetSecs < startTime+maxTime
        
        % Wait blocking for next image. If waitforimage == 1 then return it
        % as texture, if waitforimage == 4, do not return it (no preview,
        % but faster). oldtex contains the handle of previously fetched
        % textures - recycling is not only good for the environment, but also for speed ;)
        if waitforimage~=4
            % Live preview: Wait blocking for new frame, return texture
            % handle and capture timestamp:
            [tex, pts, nrdropped]=Screen('GetCapturedImage', win, grabber, waitforimage, oldtex);

            % Some output to the console:
            if count > 0
                if mod(count, round(captureFps*2)) == 0
                    disp(['Frame count: ', num2str(count),... 
                        '; avg t/frame: ', num2str((pts-startTime)/(count+1)),... 
                        '; frames dropped: ', num2str(nrdropped)]);
                end 
            end 

            % If a texture is available, draw and show it.
            if tex > 0
                % Print capture timestamp in seconds since start of capture:
                Screen('DrawText', win, sprintf('Capture time (secs): %.4f', pts), 0, 0, 255);
                if count>0
                    % Compute delta between consecutive frames:
                    delta = (pts - oldpts) * 1000;
                    oldpts = pts;
                    Screen('DrawText', win, sprintf('Interframe delta (msecs): %.4f', delta), 0, 20, 255);
                else
                    oldpts = pts;
                end

                % Draw new texture from framegrabber.
                Screen('DrawTexture', win, tex);

                % Recycle this texture - faster:
                oldtex = tex;

                % Show it:
                Screen('Flip', win);
                
                % Adjust counter
                count = count + 1;
                
                % Store frame-specific values
                frameCaptTime(count, 1) = pts;
                droppedFrames(count, 1) = nrdropped;
                
            else  % if tex
                
                WaitSecs('YieldSecs', 0.005);
                
            end  % if tex
            
        else  % if waitforimage
            
            % Recording only: We have nothing to do here, as thread offloading
            % is enabled above via flag 16 so all processing is done automatically
            % in the background.

            % Well, we do one thing. We sleep for 0.1 secs to avoid taxing the cpu
            % for no good reason:
            WaitSecs('YieldSecs', 0.1);
        end  % if waitforimage
        
        % Ready for next frame
        
    end  % while

    % Done. Shut us down, report elapsed time
    telapsed = GetSecs - startTime;
    disp([newline, 'Elapsed time: ', num2str(round(telapsed, 2)), ' secs']);

    % Call close on tex?
    Screen('Close', tex);
    
    % Stop capture engine and recording
    Screen('StopVideoCapture', grabber);
    
    % Close engine and recorded movie file
    Screen('CloseVideoCapture', grabber);
    
    % Wait, give a chance for finishing writing the file?
    WaitSecs('YieldSecs', 5);
    
    % Close display, release all remaining resources
    sca;
    
    % Crop result vars
    frameCaptTime(count+1:end) = [];
    droppedFrames(count+1:end) = [];
    
    % Report fps
    avgfps = count / telapsed;
    disp([newline, 'Average framerate: ', num2str(avgfps)]);
    
catch ME
    
    % In case of error, the 'CloseAll' call will perform proper shutdown
    % and cleanup:
    RestrictKeysForKbCheck([]);
    sca;
    rethrow(ME);
    
end  % try

% Allow KbCheck et al. to query all keys:
RestrictKeysForKbCheck([]);

% Restore old vbl sync test mode:
Screen('Preference', 'SkipSyncTests', oldsynclevel);




