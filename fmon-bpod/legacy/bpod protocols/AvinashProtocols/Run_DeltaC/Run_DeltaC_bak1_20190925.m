function Run_DeltaC
%Avinash Bala Jan 2019. Function runs Odor discrimination using the bpod
%system. Requires the following modules:
% (1) State Machine; (2) Valve Module 1; (3) Valve Module 2; (4) Analog
% Output (Wave Player); (5) Analog In 
% bpod GUI controls trial-to-trial variables. Run using bpod control panel

%% Behavior Board Functions being replaced by GUI variables
% init_plugin_gui - use GUI
% init_RunPauseButton
% init_StopStartButton
% init_threshValue - not necessary if pause
DeltaC_path

global BpodSystem
%global AOut

AIn = BpodAnalogIn(BpodSystem.ModuleUSB.AnalogIn1);  %Init Analog in
AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); %Init Analog Out (aka WavePlayer)
eval(['V1 = ValveDriverModule(BpodSystem.ModuleUSB.',BpodSystem.Modules.Name{1},');']);%load ValveModule at Position 1 as V1
eval(['V2 = ValveDriverModule(BpodSystem.ModuleUSB.',BpodSystem.Modules.Name{2},');']);%load ValveModule at Position 2 as V2
%Init_AOut; %Init Analog out
MFC_Flow1 = 100; AOut.loadWaveform(1, ones(1, 1000)*(5*MFC_Flow1/100));
MFC_Flow2 = 900; AOut.loadWaveform(2, ones(1, 1000)*(5*MFC_Flow2/1000));

%Variables
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.MaxTrials = 100;    %number of trials - trial (1)starts with setting flow rate, (2) ends with mouse response + extra ITI if timeout (S.GUI.TimeOutDur) is needed
    S.GUI.CurrentTrial = 1; 
    S.GUI.TimeOutDur = 3;       %timeout mouse gets if it licks after a no-odor trial
    S.GUI.AInSniffIn = 1;        %channel for A2D Sniff input
    S.GUI.SniffTrigOut = 1;     % channel for Sniff Trigger TTL output
    S.GUI.TrigDuration = 0.04;  % Duration of the sync out SniffTrigger
    S.GUI.AOutAirMFC = 2;       % MI#1 Air on
    S.GUI.AOutN2MFC = 1;        % MI#3 N2 on
    S.GUI.SnifVThresh = 0.4;     % Threshold for when Ain will trigger to indicate exhalation, when stims can be changed
    S.GUI.SnifVReset = -0.5;     % Threshold for when Ain will reset to indicate end of exhalation and start of inhalation.
    S.GUI.WaterValveTime = 37;     %How long the water valve is to stay open each time it's triggered
end

% create alternate variable lists for (1) Test vs control, and 
% (2) flow rate 50 vs 100 of Nitrogen
MaxTrials = 100
StimTypes = ceil(rand(2,MaxTrials)*2);%create 2-row array; row 1 = catch/test; row 2 = lo (950/50) or hi (900/100) odor levels


%SetWavePlayer parameters
AOut.OutputRange = '0V:5V';             % min to max range (options in BpodWavePlayer)
AOut.SamplingRate = 1000;              % Hz
AOut.TriggerMode = 'Master';           %Normal, Master, or Toggle
AOut.LoopDuration = [7200 7200 0 0];    %must be set to a finite number to allow for looping (continuous output)
AOut.LoopMode = {'On';'On';'Off';'Off'}; % channels set to loop (as opposed to play out only for buffer length)
% load waves in AOut buffers
AOut.loadWaveform(1, ones(1, 1000)*(0.0));      %buffer #1 = zero (off) 
AOut.loadWaveform(2, ones(1, 1000)*(5.0));      %buffer #2 = 5V (full)      ['P' 1 1],['P' 2 2] (0 + 1000)ml
AOut.loadWaveform(3, ones(1, 1000)*(2.5));      %buffer #3 = 2.5V (50%)
AOut.loadWaveform(4, ones(1, 1000)*(4.5));      %buffer #4 = 4.5V (90%) - 	['P' 1 2], ['P' 2 4] (100 + 900)ml
AOut.loadWaveform(5, ones(1, 1000)*(4.75));     %buffer #5 = 4.75V (95%) - 	['P' 1 3], ['P' 2 5] (50 + 950)mk

%%SetAnalogIn parameters
AIn.nActiveChannels = 1;                             % Number of active channels
AIn.Thresholds(1) = S.GUI.SnifVThresh;               % Trigger threshold for A2D data
AIn.ResetVoltages(1) = S.GUI.SnifVReset;             % Voltage at which trigger is reset. Note, for +ve slope trigger, V-Reset << V-Trigger
AIn.InputRange{1} = '-2.5V:2.5V';                      % Input voltage range
AIn.SMeventsEnabled(1) = 1;                          % 
AIn.startReportingEvents;                            % start sending events to state machine
%SAIn.scope();

BpodParameterGUI('init', S); % Initialize parameter GUI plugin
F = figure;
Ax = axes;

%Turn on MFCs (turned off at end of main loop (currentTrial)
AOut.play(1,1);
AOut.play(2,2);

% set case-select defaults
OdorVialOutput = {'ValveModule2', 1};   %close dummy; flow thru odor+diluent
SwitchByState = 'WaitForLick';         %gets reward if licking in GO Trial

BpodSystem.Data.AnalogData = cell(1,MaxTrials);

for currentTrial = 1:S.GUI.MaxTrials
    disp(currentTrial);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    %load serial messages - these will be triggered by states ("sma") below
    LoadSerialMessages('AnalogIn1', {['L' 1], ['L' 0]});
    LoadSerialMessages('ValveModule1', {['B' 8], ['B' 16], ['B' 0], ['B' 44], ['B' 74]});
    LoadSerialMessages('ValveModule2', {['B' 195], ['B' 165], ['B' 153], ['B' 0]});
    LoadSerialMessages('WavePlayer1', {['P' 1 0],['P' 2 1], ['P' 1 1], ['P' 2 3], ['P' 1 2], ['P' 2 4],['X']});
    
    DeltaC_trialtype; %get trial variables from function DeltaC_trialtype.m
    
    sma = NewStateMachine();
    %sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.GUI.TrigDuration, 'OnsetDelay', 0, 'Channel', 'BNC1');% TTL durstion and source
    %#1
    sma = AddState(sma, 'Name', 'SetMFC', ... % #1 Set flow rates to trial specifications - 900/100 or 950/50
        'Timer', 0,...
        'StateChangeConditions', {'Tup','WaitForEquilibration'},...
        'OutputActions', MFCOut);
    %#2
    sma = AddState(sma, 'Name', 'OpenVial', ... % #2 Open olfactometer vial - wait for MFC flow to stabilize (sma1)
        'Timer', 2,...
        'StateChangeConditions', {'Tup','WaitForEquilibration'},...
        'OutputActions', OdorVialOutput);
    %#3
    sma = AddState(sma, 'Name', 'WaitForEquilibration', ...     % #3 wait 3 s for odor levels to equilibrate
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'SniffSensorOn'},...
        'OutputActions', {});
    %#4
    sma = AddState(sma, 'Name', 'SniffSensorOn', ...            % #4 start monitoring for sniff
        'Timer', 0,...
        'StateChangeConditions', {'Tup','XSnf0'},...`
        'OutputActions', {'AnalogIn1', 1});%                     % AIn.startLogging
    %#5
    sma = AddState(sma, 'Name', 'XSnf0', ...%                    % Wait for Sniff 0
        'Timer', 0.001,...
        'StateChangeConditions', {'AnalogIn1_1','OpenFV'},...%   %   executes on sniff trigger being exceeded
        'OutputActions', {});
    %#1
    sma = AddState(sma, 'Name', 'OpenFV', ...%                   % Open FV + any CCM channels for this trial
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'XSnf1'},...
        'OutputActions', {'BNCState',1,Snf0_CCM});
    %#1
    sma = AddState(sma, 'Name', 'XSnf1', ...%                    %Wait for Sniff 1
        'Timer', 0,...%
        'StateChangeConditions', {'AnalogIn1_1', 'DelC_Period'},...%
        'OutputActions', {}); 
    %#1
    sma = AddState(sma, 'Name', 'DelC_Period', ...%                 %Open/Close CCM channels
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Click_CCM'},...
        'OutputActions', {'BNCState',1,Snf1_CCM});%     
    %#1
    sma = AddState(sma, 'Name', 'Click_CCM', ...%                   %15ms wait, in case any CCM channels need opening/closing
        'Timer', 0.015,...
        'StateChangeConditions', {'Tup', 'XSnf2'},...
        'OutputActions', {'BNCState',1,Post_Snf1CCM);%
    
    sma = AddState(sma, 'Name', 'XSnf2', ... % Wait for Sniff 2
        'Timer', 0,...
        'StateChangeConditions', {'Tup','EndSniffs'},...
        'OutputActions', {}); 
         
    sma = AddState(sma, 'Name', 'EndSniffs', ...%                   % Close all vials and channels
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'XSnf2'},...
        'OutputActions', {'BNCState',1,Snf2_CCM});% 
    %#1
    sma = AddState(sma, 'Name', 'OdorOff', ...                    % Turn off FV, send out second TTL
        'Timer', 0,...
        'StateChangeConditions', {'Tup', SwitchByState},...        %     Case-dependent switch to water delivery or to time-out
        'OutputActions', {'ValveModule1',3});                       %   Close FV
    %#1
    sma = AddState(sma, 'Name', 'WaitForLick', ...                  %WAIT FOR LICK
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', 'WaterValveOn'},...
        'OutputActions', {});
    %#1
    sma = AddState(sma, 'Name', 'WaterValveOn', ...                 %DELIVER WATER TO MOUSE
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {});%{});
    %#1
    sma = AddState(sma, 'Name', 'Drinking', ...                     % CLOSE VALVE AFTER TIME DETERMINED EARLIER; 
        'Timer', S.GUI.WaterValveTime/1000,...
        'StateChangeConditions', {'Tup', 'DrinkingGrace'},...       
        'OutputActions', {'ValveModule1',2});%
    %#1
    sma = AddState(sma, 'Name', 'DrinkingGrace', ...                %Add 500 ms for mouse to respond or drink
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', 'TrialEnd'},...
        'OutputActions', {'ValveModule1',3});
    %#1
    sma = AddState(sma, 'Name', 'WaterBypass4NoGo', ...             %jump to here for NoGo trial; adds time out for TimeOutDur
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'TrialEnd'},...
        'OutputActions', {});
    %#1
    sma = AddState(sma, 'Name', 'TrialEnd', ...                     %End trial
        'Timer', 0,...
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
    end
    S.GUI.CurrentTrial = S.GUI.CurrentTrial+1;
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end
AOut.stop()                                         % set MFCs to zero

%% Things that need to be replicated from behavior board setup
% State machine states that duplicate the initial variable declarations and
% the select-case seeries that run the Arduino in the Behavior Board
% Variables - line 27-38 and 48-59
% Variables neeed to be accessible thru GUI - threshold, thresh-reset %
%       Lines 36 & 37, note: GUI vars are updated at start of each trial in main
%       loop
% pause; accessible thru Bpod controls
% Series of State Machines
% Set MFC flow rates (100/900 or 50/950)
% Switch airflow to OdorVial slected
% Wait for SNIFF 1
% Final Valve on + Manifold Dummy or Dilution OR Dump out if no smiff
% Wait for SNIFF 2
% Manfold valves
% Wait for SNIFF 3
% Turn off all Manifold valves and Final Valve
% Reward if lick
% Olfactometer - air to dummy
% Timeout if needed
% Read data
% Save data
% Update Response to matrix and Figure to compute %Hits
% Clear variables needed.
%