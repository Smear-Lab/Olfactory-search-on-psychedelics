function Sniff_TrigFV    
%AnalogIn_Voltage.m
% sample code for reading voltage from AnalogIn module
% for indices, look at var BpodSystem in Matlab memory after you run 'bpod'
global BpodSystem
%eval(['V1 = ValveDriverModule(BpodSystem.ModuleUSB.',BpodSystem.Modules.Name{1},');']);%load ValveModule at Position 1 as V1
%eval(['V2 = ValveDriverModule(BpodSystem.ModuleUSB.',BpodSystem.Modules.Name{2},');']);%load ValveModule at Position 2 as V2
AIn = BpodAnalogIn(BpodSystem.ModuleUSB.AnalogIn1);  %
AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); %

%Variables
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.MaxTrials = 100;    %number of cycles
    S.GUI.AInSniffIn = 1;        %channel for A2D Sniff input
    S.GUI.SniffTrigOut = 1;     % channel for Sniff Trigger TTL output
    S.GUI.TrigDuration = 0.04;  % Duration of the sync out SniffTrigger
    S.GUI.AOutAirMFC = 2;       %MI#1 Air on
    S.GUI.AOutN2MFC = 1;        %MI#3 N2 on
    S.GUI.SnifVThresh = 0.4;     % Threshold for when Ain will trigger
    S.GUI.SnifVReset = -0.5;     % Threshold for when Ain will reset
end

MaxTrials = 100
%%SetAnalogIn parameters
AIn.nActiveChannels = 1;                             % Number of active channels
AIn.Thresholds(1) = S.GUI.SnifVThresh;               % Trigger threshold for A2D data
AIn.ResetVoltages(1) = S.GUI.SnifVReset;             % Voltage at which trigger is reset. Note, for +ve slope trigger, V-Reset << V-Trigger
AIn.InputRange{1} = '-5V:5V';                      % Input voltage range
AIn.SMeventsEnabled(1) = 1;                          % 
AIn.startReportingEvents;                            % start sending events to state machine
%SAIn.scope();

BpodParameterGUI('init', S); % Initialize parameter GUI plugin
F = figure;
Ax = axes;

BpodSystem.Data.AnalogData = cell(1,MaxTrials);

for currentTrial = 1:S.GUI.MaxTrials
    pause(1);
    disp(currentTrial);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    disp(num2str(S.GUI.TrigDuration))
    LoadSerialMessages('AnalogIn1', {['L' 1], ['L' 0]});
    LoadSerialMessages('ValveModule1', {['B' 8], ['B' 24], ['B' 0], ['B' 16]});
    sma = NewStateMachine();
    %sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.GUI.TrigDuration, 'OnsetDelay', 0, 'Channel', 'BNC1');% TTL durstion and source
    
    sma = AddState(sma, 'Name', 'BreathOn', ... % start A1 Collect with 2p
        'Timer', 0,...
        'StateChangeConditions', {'Tup','Image1'},...`
        'OutputActions', {'AnalogIn1', 1}); % AIn.startLogging
    
    sma = AddState(sma, 'Name', 'Image1', ... % TTL based 2p collect (Timer 1)
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'FullOdor1'},...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'XSnf1', ... % Wait for Snf
        'Timer', 0.001,...
        'StateChangeConditions', {'AnalogIn1_1','FullOdor1'},...
        'OutputActions', {'BNCState',1,'ValveModule1',1}); 
        
    sma = AddState(sma, 'Name', 'FullOdor1', ... % Wait for Snf
        'Timer', 0,...
        'StateChangeConditions', {'AnalogIn1_1', 'XSnf2'},...
        'OutputActions', {'ValveModule1',1}); % FV ON {'I2C1', 5});
    
    sma = AddState(sma, 'Name', 'XSnf2', ... % Wait for Sniff 2
        'Timer', 0,...
        'StateChangeConditions', {'Tup','DelC'},...
        'OutputActions', {}); 
         
    sma = AddState(sma, 'Name', 'DelC', ... % DeltaC 1 s
        'Timer', 0,...
        'StateChangeConditions', {'AnalogIn1_1', 'OdrOff'},...
        'OutputActions', {}); % Manifold ON - Dilute Odor {'I2C1', 9});
 
    sma = AddState(sma, 'Name', 'OdrOff', ... % Odor Off
        'Timer', 0,...
        'StateChangeConditions', {'Tup','DelCOff'},...
        'OutputActions',  {}); %{'I2C1',6}) FV OFF;  
    
    sma = AddState(sma, 'Name', 'DelCOff', ... % DC Off
        'Timer', 0,...
        'StateChangeConditions', {'Tup','Image3'},...
        'OutputActions',  {}); % Manifold OFF %{'I2C1',10}); 
    sma = AddState(sma, 'Name', 'Image3', ... % 
        'Timer', 0.1,...
        'StateChangeConditions', {'Tup', 'BreathOff'},...
        'OutputActions', {'AnalogIn1', 2});%AIn.stopLogging;
    
    sma = AddState(sma, 'Name', 'BreathOff', ... % 
        'Timer', 0.1,...
        'StateChangeConditions', {'Tup', 'TrialEnd'},...
        'OutputActions', {'ValveModule1', 3});
    
    sma = AddState(sma, 'Name', 'TrialEnd', ... % 
        'Timer', 3,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {});
    
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
    data = AIn.getData;
    BpodSystem.Data.AnalogData{currentTrial} = data;
    plot(Ax, data.x, data.y(1,:))
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
%        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        
    %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        
    end
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end
