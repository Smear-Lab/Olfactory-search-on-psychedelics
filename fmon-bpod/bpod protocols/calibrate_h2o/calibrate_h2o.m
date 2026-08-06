function calibrate_h2o
%%
global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.CurrentBlock = 1; % Training level % 1 = Direct Delivery at both ports 2 = Poke for delivery
    S.GUI.RewardAmount = 5; %ul
    S.GUI.PortOutRegDelay = 0.5; % How long the mouse must remain out before poking back in
end

%% Define trials
reps = 100;
TrialTypes = ones(1,reps);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
%BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
%BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
%TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);

%% Valve Times
% Read variables from workspace
LeftValveTime = evalin('base', 'LeftValveTime');
RightValveTime = evalin('base', 'RightValveTime');
InitValveTime = evalin('base', 'InitValveTime');

%% Count Reps
count = 1;

%% Main trial loop
for currentTrial = 1:reps

    sma = NewStateMachine(); % Initialize new state machine description
    
    sma = AddState(sma, 'Name', 'LeftReward', ...
    'Timer', LeftValveTime,...
    'StateChangeConditions', {'Tup', 'InitReward'},...
    'OutputActions', {'ValveState', 1}); 

    sma = AddState(sma, 'Name', 'InitReward', ...
        'Timer', InitValveTime,...
        'StateChangeConditions', {'Tup', 'RightReward'},...
        'OutputActions', {'ValveState', 4});     
    
    sma = AddState(sma, 'Name', 'RightReward', ...
        'Timer', RightValveTime,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'ValveState', 2});

    T = BpodTrialManager;
    T.startTrial(sma)
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    RawEvents = T.getTrialData;
    %    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
    %    BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); %  Computes trial events from raw data
    %    UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
    %    end

    count = count + 1;
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

RunProtocol('Stop');  % Stop the protocol 

%% Outcome plot. If needed.
function UpdateOutcomePlot(TrialTypes, Data)
    global BpodSystem
    disp(Data.nTrials);
    Outcomes = zeros(1,Data.nTrials);
    for x = 1:Data.nTrials
        Outcomes(x) = 1;
    end
    TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
