function LickTraining
global BpodSystem

MaxTrials = 5; % Set to some sane value, for preallocation

%--- Define parameters and trial structure
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
initvar = inputdlg({'WaterValveTime','nRepeats'},'Water Calibration Variables',...
    1, {'37', '100'})

if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.WaterValveTime = str2num(initvar{1}); %(make sure to specify .GUI, otherwise it'll throw an unexpected field error)
    S.GUI.MaxTrials = str2num(initvar{2})
end

%--- Initialize plots and start USB connections to any modules
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
% Initialize ValveDriver Module
V = ValveDriverModule(BpodSystem.ModuleUSB.ValveModule1);


%% Main loop (runs once per trial)
for currentTrial = 1:S.GUI.MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    LoadSerialMessages('ValveModule1', {['B' 16], ['B' 0]});
    %--- Assemble state machine
    sma = NewStateMatrix();
    sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port 1 low (is out)
    %statename 'WaitForLick' - waiting for lick
    sma = AddState(sma, 'Name', 'WaitForLick', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', 'WaterValveOn'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaterValveOn', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {});%{});
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', S.GUI.WaterValveTime/1000,...
        'StateChangeConditions', {'Tup', 'DrinkingGrace'},...
        'OutputActions', {'ValveModule1',1});%
 
%     sma = AddState(sma, 'Name', 'Drinking', ...
%         'Timer', 0,...
%         'StateChangeConditions', {'Condition1', 'DrinkingGrace'},...
%         'OutputActions', {'ValveModule1', 00000000});
    sma = AddState(sma, 'Name', 'DrinkingGrace', ...
        'Timer', 2,...
        'StateChangeConditions', {'Tup', '>exit'},...%, 'Port1In', 'Drinking'},...
        'OutputActions', {'ValveModule1',2});%{'ValveModule1',2});%
%     %statename 'Drinking' - open Water delivery valve afer time 'WaterValveTime'
%     sma = AddState (sma, 'Name', 'Drinking',...
%         'Timer', 0.5,...
%         'StateChangeConditions', {'Tup', 'ValvesOff'},...
%         'OutputActions',{});
%     
    %statename 'Drinking' - open Water delivery valve afer time 'WaterValveTime'
%     sma = AddState (sma, 'Name', 'ValvesOff',...
%         'Timer', 0,...
%         'StateChangeConditions', {'Tup', '>exit'},...
%         'OutputActions',{'ValveModule1', 3});
    
    
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    
    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        
        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        
    end
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
    disp(currentTrial);
end