%{
PID GRID SAMPLER for Bpod

Written By: Nate Gonzales-Hess (nhess@uoregon.edu)
Last Updated: 6/29/2023
%}

function fmon_pid
%%
global BpodSystem

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S

%% Start Bonsai
% Run Bonsai connect Python Script
[~,~] = system('C:\ProgramData\Anaconda3\python.exe D:\fmon-pid\connect.py');
disp("Starting Bonsai");
java.lang.Thread.sleep(2000);

%% Define trials
nLeftTrials = 15;
nRightTrials = 15;
mix_time = 2;
odor_time = 2;
iti_time = .5;

TrialTypes = [ones(1, nLeftTrials) ones(1, nRightTrials)*2];  % 1 = Left, 2 = Right
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
MaxTrials = length(TrialTypes);

%% Initialize plots
%BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 500 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
%BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
%TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);
%% Main trial loop
for currentTrial = 1:MaxTrials
    
    % Valve Module serial messages, 1 = Odor, 2 = Omission, 3 = Reset
    LoadSerialMessages('ValveModule1', {['B' 15], ['B' 51], ['B' 0]});  % Left valves
    LoadSerialMessages('ValveModule2', {['B' 15], ['B' 51], ['B' 0]});  % Right valves
    LoadSerialMessages('ValveModule3', {['B' 3], ['B' 0]});  % Final Valves
    
    % Determine trial-specific state matrix fields
    switch TrialTypes(currentTrial)
        case 1
            OdorantState = 'OdorLeft';
        case 2
            OdorantState = 'OdorRight';
    end

    % Initialize new state machine description
    sma = NewStateMachine(); 
    
    % State definitions    
    sma = AddState(sma, 'Name', 'Reset', ...
        'Timer', iti_time/2,...
        'StateChangeConditions', {'Tup', OdorantState},...
        'OutputActions', {'ValveModule1', 3, 'ValveModule2', 3, 'ValveModule3', 2});  % Reset all valves to 0V
    
    sma = AddState(sma, 'Name', 'OdorLeft', ...
    'Timer', mix_time,...
    'StateChangeConditions', {'Tup', 'finalValvesOpen'},...
    'OutputActions', {'ValveModule1', 1, 'ValveModule2', 2});  % Left odor, right omission

    sma = AddState(sma, 'Name', 'OdorRight', ...
        'Timer', mix_time,...
        'StateChangeConditions', {'Tup', 'finalValvesOpen'},...
        'OutputActions', {'ValveModule1', 2, 'ValveModule2', 1});  % Left omission, right odor
    
    sma = AddState(sma, 'Name', 'finalValvesOpen', ...
    'Timer', odor_time,...
    'StateChangeConditions', {'Tup', 'finalValvesClose'},...
    'OutputActions', {'ValveModule3', 1});  % Final valves open

    sma = AddState(sma, 'Name', 'finalValvesClose', ...
    'Timer', .5,...
    'StateChangeConditions', {'Tup', 'ITI'},...
    'OutputActions', {'ValveModule3', 2});  % Final valves close
    
    sma = AddState(sma, 'Name', 'ITI', ... 
    'Timer', iti_time/2,...
    'StateChangeConditions', {'Tup', 'exit'},...
    'OutputActions', {}); 

    T = BpodTrialManager;
    T.startTrial(sma)
    RawEvents = T.getTrialData;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); %  Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        %UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end

end

%% Stop Bonsai
% Run Bonsai connect Python Script
[~,~] = system('C:\ProgramData\Anaconda3\python.exe D:\fmon-pid\disconnect.py');
disp("Stopping Bonsai");
java.lang.Thread.sleep(3000);

%% Stop the Bpod protocol
RunProtocol('Stop');  