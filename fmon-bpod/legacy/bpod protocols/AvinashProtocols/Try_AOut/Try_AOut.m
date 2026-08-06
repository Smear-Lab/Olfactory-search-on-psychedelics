function Try_AOut        
global BpodSystem
global AOut

%% Setup (runs once before the first trial)
MaxTrials = 10000; % Set to some sane value, for preallocation

if (exist('AOut','var')==0)
    % Analog
    % Output---------------------------------------------------------------------------------------------------
    AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); %shorter version of last 2 lines
end
%SetWavePlayer parameters
if strcmp(AOut.OutputRange, '0V:5V')==0; AOut.OutputRange='0V:5V'; end % min to max range (options in BpodWavePlayer)
if AOut.SamplingRate ~= 1000; AOut.SamplingRate = 1000; end % set to 1000 Hz
if strcmp(AOut.TriggerMode, 'Master')==0; AOut.TriggerMode='Master'; end %Normal, Master, or Toggle
if AOut.LoopDuration(1) ~= 7200; AOut.LoopDuration = [7200 7200 0 0]; end %must be set to a finite number to allow for looping (continuous output)
if strcmp(AOut.OutputRange, 'On')==0;AOut.LoopMode = {'On';'On';'Off';'Off'}; end % channels set to loop (as opposed to play out only for buffer length)

% AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); %Init Analog Out (aka WavePlayer)
% %SetWavePlayer parameters
% AOut.OutputRange = '0V:5V';             % min to max range (options in BpodWavePlayer)
% AOut.SamplingRate = 1000;              % Hz
% AOut.TriggerMode = 'Master';           %Normal, Master, or Toggle
% AOut.LoopDuration = [7200 7200 0 0];    %must be set to a finite number to allow for looping (continuous output)
% AOut.LoopMode = {'On';'On';'Off';'Off'}; % channels set to loop (as opposed to play out only for buffer length)
%%SetAnalogIn parameters
%Init_AOut; %Init Analog out
%MFC_Flow1 = 100; AOut.loadWaveform(1, ones(1, 1000)*(5*MFC_Flow1/100));
%MFC_Flow2 = 900; AOut.loadWaveform(2, ones(1, 1000)*(5*MFC_Flow2/1000));
AOut.loadWaveform(1, ones(1, 1000)*(0.5));
AOut.loadWaveform(2, ones(1, 1000)*(1.0));
AOut.loadWaveform(3, ones(1, 1000)*(1.5));
AOut.loadWaveform(4, ones(1, 1000)*(2.0));
AOut.loadWaveform(5, ones(1, 1000)*(2.5));
%Variables
% S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
% if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
%     S.GUI.MaxTrials = 100;    %number of trials - trial (1)starts with setting flow rate, (2) ends with mouse response + extra ITI if timeout (S.GUI.TimeOutDur) is needed
%     S.GUI.CurrentTrial = 1; 
%     S.GUI.TimeOutDur = 3;       %timeout mouse gets if it licks after a no-odor trial
%     S.GUI.AInSniffIn = 1;        %channel for A2D Sniff input
%     S.GUI.SniffTrigOut = 1;     % channel for Sniff Trigger TTL output
%     S.GUI.TrigDuration = 0.04;  % Duration of the sync out SniffTrigger
%     S.GUI.AOutAirMFC = 2;       % MI#1 Air on
%     S.GUI.AOutN2MFC = 1;        % MI#3 N2 on
%     S.GUI.SnifVThresh = 0.4;     % Threshold for when Ain will trigger to indicate exhalation, when stims can be changed
%     S.GUI.SnifVReset = -0.5;     % Threshold for when Ain will reset to indicate end of exhalation and start of inhalation.
%     S.GUI.WaterValveTime = 37;     %How long the water valve is to stay open each time it's triggered
% end
% 
% 
% 
% 
% BpodParameterGUI('init', S); % Initialize parameter GUI plugin


% set case-select defaults
OdorVialOutput = {'ValveModule2', 1};   %close dummy; flow thru odor+diluent
SwitchByState = 'WaitForLick';         %gets reward if licking in GO Trial

BpodSystem.Data.AnalogData = cell(1,MaxTrials);

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials;%S.GUI.MaxTrials
    disp(currentTrial);
%     S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    LoadSerialMessages('WavePlayer1', {['P' 1 0],['P' 1 1], ['P' 1 2], ['P' 1 3], ['P' 1 4], ['P' 1 5],['X']});
    
    sma = NewStateMachine();
    
    sma = AddState(sma, 'Name', 'PlaySound1', ...
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'StopSound1'},...
        'OutputActions', {'WavePlayer1', 1}); % Sends serial message 1 - 1.0V
    sma = AddState(sma, 'Name', 'StopSound1', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'PlaySound2'},...
        'OutputActions', {'WavePlayer1', 7}); % Sends serial message 1
    sma = AddState(sma, 'Name', 'PlaySound2', ...
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'StopSound2'},...
        'OutputActions', {'WavePlayer1', 2}); % Sends serial message 1 - 2.0V
    sma = AddState(sma, 'Name', 'StopSound2', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'PlaySound3'},...
        'OutputActions', {'WavePlayer1', 7}); % Sends serial message 1
    
    sma = AddState(sma, 'Name', 'PlaySound3', ...
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'StopSound3'},...
        'OutputActions', {'WavePlayer1', 5}); % Sends serial message 1 - 1.0V
    sma = AddState(sma, 'Name', 'StopSound3', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'PlaySound4'},...
        'OutputActions', {'WavePlayer1', 7}); % Sends serial message 1
    sma = AddState(sma, 'Name', 'PlaySound4', ...
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'StopSound4'},...
        'OutputActions', {'WavePlayer1', 4}); % Sends serial message 1 - 1.0V
    sma = AddState(sma, 'Name', 'StopSound4', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'PlaySound5'},...
        'OutputActions', {'WavePlayer1', 7}); % Sends serial message 1
    
    sma = AddState(sma, 'Name', 'PlaySound5', ...
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'StopSound5'},...
        'OutputActions', {'WavePlayer1', 3}); % Sends serial message 1 - 3.0V
    sma = AddState(sma, 'Name', 'StopSound5', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'WavePlayer1', 7}); % Sends serial message 1

    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
%     S.GUI.CurrentTrial = S.GUI.CurrentTrial+1;
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end
AOut.stop()
clear AOut
