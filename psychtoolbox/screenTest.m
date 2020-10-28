try
    
    % open screen OpenWindow
    whichScreen = max(Screen('Screens'));
    win = Screen('OpenWindow', whichScreen);
    
    WaitSecs(3);
    
    Screen('CloseAll');
    
catch ME
    disp('Error during try loop:');
    disp(ME.message);
    
    Screen('CloseAll');
    
end