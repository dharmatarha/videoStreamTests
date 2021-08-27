% Simple & Dumb handshake using UDP packets
%
% The goal is for two PCs with synchronized internal clocks to negotiate a 
% common start time for a recording script.
%
% Logic:
% (1) Open an UDP socket
% (2) Repeatedly send initial handshake message, wait for response (first stage)
% (3) Get timstamp and start sending that timestamp repeatedly until 
%     a timestamp is received from the other side (second stage)
% (4) Derive common / shared start time from the two timestamps
%
% We work with the following assumptions:
% - Internal clocks are synced (~fractional second, ideally ~millisecond)
% - Transmission is reliable and fast (missing packets can kill the whole procedure)
%


%% Settings, params

% Import
pkg load sockets;

% Constants
maxTimeOut = 60;  % maximum allowed time for the handshake in secs
waitTime = 0.2;  % time between sending packets when repeatedly doing so, in both stages, in secs
maxDiff = 100;  % maximum allowed difference for the two timestamps (local and remote) in the second stage
startDelay = 103; % shared start time is the average of the two timestamps (local and remote) + startDelay, in secs
localPort = 9998;
remoteIP = '10.160.12.108';
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





