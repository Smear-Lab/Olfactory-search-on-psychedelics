%{
FMON Trainer Module for Bpod
Preferences (Set variables in Freely Moving Olfactory Navigation Task)

Written By: Nate Gonzales-Hess (nhess@uoregon.edu)
Last Updated: 7/7/2023
%}

function fmon_spontaneous
%% Initialize Bpod
global BpodSystem
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S

%% Start Bonsai
%Clear Bpod TCP Socket
BpodSystem.BonsaiSocket = [];

% Run Bonsai connect Python Script
[~,~] = system('start C:\ProgramData\Anaconda3\python.exe D:\fmon-bpod\connect_gui.py');

% Connect to Bonsai
BpodSystem.BonsaiSocket = TCPCom(11235);

%% Set Timer
% Get duration from GUI, or use default of 60 minutes.
if evalin('base', 'exist(''session_duration'', ''var'')')
    session_duration = evalin('base', 'session_duration');
else
    session_duration = 60;
end
%Initialize session timer.
t = timer;
t.StartDelay = session_duration*60;  % time in seconds
t.TimerFcn = @(~,~)timeUp(session_duration);  % timeUp is defined at end of this file
start(t);

%% Set Reward amounts
% Read variables from workspace, supplied by fmon_prefs GUI.
% If Variables don't exist, set to defaults (.1 seconds)
if evalin('base', 'exist(''LeftValveTime'', ''var'')')
    LeftValveTime = evalin('base', 'LeftValveTime');
else
    LeftValveTime = 0.1;
end

if evalin('base', 'exist(''RightValveTime'', ''var'')')
    RightValveTime = evalin('base', 'RightValveTime');
else
    RightValveTime = 0.1;
end

if evalin('base', 'exist(''InitValveTime'', ''var'')')
    InitValveTime = evalin('base', 'InitValveTime');
else
    InitValveTime = 0.1;
end

% Time to wait before lick port out is confirmed
PortOutDelay = .5;

%% Define trials
%n_HalfTrials = 50;
%TrialTypes = [1];  % First trial is left (1)
% Build list, alternating between 2 and 1
%for i = 1:n_HalfTrials-1
%   TrialTypes(end+1) = 2;
%   TrialTypes(end+1) = 1;
%end

%BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
%MaxTrials = length(TrialTypes);

%% Build ITI list
% Read variables from workspace, supplied by fmon_prefs GUI.
%if evalin('base', 'exist(''min_iti'', ''var'')')
%    min_iti = evalin('base', 'min_iti');
%else
%    min_iti = 0;
%end

%if evalin('base', 'exist(''max_iti'', ''var'')')
%    max_iti = evalin('base', 'max_iti');
%else
%    max_iti = 0;
%end
% Build ITI list
%iti_list = round((max_iti-min_iti) .* rand(1,length(TrialTypes)) + min_iti);

%% Initialize plots
%BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
%BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
%TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);

%% Main trial loop
for currentTrial = 1:1000
    
    % Initialize new state machine description
    sma = NewStateMachine(); 
    
    sma = AddState(sma, 'Name', 'NothingForever', ...
        'Timer', 1000,...
        'StateChangeConditions', {},...  % Do nothing 
        'OutputActions', {});

    T = BpodTrialManager;
    T.startTrial(sma);
    RawEvents = T.getTrialData;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        %BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); %  Computes trial events from raw data
        %BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        %BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        %UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end


%% Time-Up Functions
function timeUp(duration)
    disp(num2str(duration) + " minutes have elapsed! The session has ended.");  % Print to console, maybe make this an alert
    RunProtocol('Stop');  % Stop the protocol   
    BpodSystem.BonsaiSocket = [];
    [~,~] = system('start C:\ProgramData\Anaconda3\python.exe D:\fmon-bpod\disconnect_gui.py'); % Stop Bonsai
    SaveBpodSessionData();  % Save Session Data to Bpod data folder
    disp('running data output script');
    run('D:\fmon-bpod\fmon_data_output.m'); % Run data processing script
