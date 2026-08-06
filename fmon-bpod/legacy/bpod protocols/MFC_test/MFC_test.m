function MFC_test
global BpodSystem

clear AOut
%Create Analog Out object
AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); 

AOut.OutputRange='0V:5V'; % min to max range (options in BpodWavePlayer)
%AOut.SamplingRate = 1000;% set to 1000 Hz
AOut.TriggerMode= 'Master'; %Normal, Master, or Toggle
AOut.LoopDuration = [7200 7200 7200 7200];
AOut.LoopMode = {'On';'On';'On';'On'};


%AOut.setupSDCard() %Format SD card

%load voltages to WavePlayer
AOut.loadWaveform(1, ones(1, 1000)*(1.0));

for currentTrial = 1:5
    disp(currentTrial);
    LoadSerialMessages('WavePlayer1', {['P' 15 0],['X'],['N']});

    sma = NewStateMachine();
    
    sma = AddState(sma, 'Name', 'PlaySound1', ...
        'Timer', 5,...
        'StateChangeConditions', {'Tup', 'Report'},...
        'OutputActions', {'WavePlayer1', 1}); % Sends serial message 1 - 1.0V
    
    sma = AddState(sma, 'Name', 'Report', ...
    'Timer', 1,...
    'StateChangeConditions', {'Tup', 'StopSound1'},...
    'OutputActions', {'WavePlayer1', 3}); % Sends serial message 2 - 'X'

    sma = AddState(sma, 'Name', 'StopSound1', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'WavePlayer1', 2}); % Sends serial message 2 - 'X'

    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

AOut.stop()
clear AOut
disp('done')