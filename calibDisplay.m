
try
  
  PsychDefaultSetup(2);
  screen=max(Screen("Screens"));
  RestrictKeysForKbCheck(KbName("ESCAPE"));  % only report ESCape key press via KbCheck
  GetSecs; WaitSecs(0.5);  % dummy calls
  oldsynclevel = Screen("Preference", "SkipSyncTests", 1);  % skip tests
  instrTime = 10;
  markerTime = 3600;
  stopMarkerTime = 5;
  
  % load img
  fileP = "/home/mordor/pupil_calib_marker.jpg";
  markerImg = imread(fileP);
  fileP = "/home/mordor/pupil_calib_stop_marker.jpg";
  markerStopImg = imread(fileP);

  onWin = Screen("OpenWindow", screen);
  [width, height]=Screen("WindowSize", onWin);
  Screen("TextSize", onWin, 36);
  instrText = ["Calibration start.", char(10), "Once it appears, fixate the marker in the center", char(10), "while slowly rotating your head"];
  DrawFormattedText(onWin, instrText, "center", "center", [0 0 0], [], [], [], [], [], [width/2-300, height/2-300, width/2+300, height/2+300]);

  % instructions
  startTime = Screen("Flip", onWin);
  WaitSecs(instrTime);

  % calibration marker setup
  markerTex = Screen("MakeTexture", onWin, markerImg);
  Screen("DrawTexture", onWin, markerTex, [], [width/2-100, height/2-100, width/2+100, height/2+100]);

  % calibration start
  calibStart = Screen('Flip', onWin);
  while GetSecs < calibStart + markerTime
    [keyIsDown, secs, keyCode] = KbCheck;
    if keyIsDown && find(keyCode) == KbName('ESCAPE') 
        break;
    end
  end
  

  % calibration stop marker setup
  markerTex = Screen("MakeTexture", onWin, markerStopImg);
  Screen("DrawTexture", onWin, markerTex, [], [width/2-100, height/2-100, width/2+100, height/2+100]);
  calibStop = Screen('Flip', onWin);

  WaitSecs(stopMarkerTime);

  sca;

catch ME
    sca;
    rethrow(ME);
    
end
  


