function OdorDiscrimination    
%Avinash Bala Jan 2019. Function runs Odor discrimination using the bpod
%system. Requires the following modules:
% (1) State Machine; (2) Valve Module 1; (3) Valve Module 2; (4) Analog
% Output (Wave Player); (5) Analog In 
% bpod GUI controls trial-to-trial variables. Run using bpod control panel
DeltaC_path
global BpodSystem
global AOut

AIn = BpodAnalogIn(BpodSystem.ModuleUSB.AnalogIn1);  %Init Analog in
AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); %Init Analog Out (aka WavePlayer)
%Init_AOut; %Init Analog out
MFC_Flow1 = 100; AOut.loadWaveform(1, ones(1, 1000)*(5*MFC_Flow1/100));
MFC_Flow2 = 900; AOut.loadWaveform(2, ones(1, 1000)*(5*MFC_Flow2/1000));

%Set GUI Variables - updated every loop
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.MaxTrials = 100;    %number of cycles
    S.GUI.CurrentTrial = 1; 
    S.GUI.TimeOutDur = 3;       %timeout mouse gets if it licks after a no-odor trial
    S.GUI.AInSniffIn = 1;        %channel for A2D Sniff input
    S.GUI.SniffTrigOut = 1;     % channel for Sniff Trigger TTL output
    S.GUI.TrigDuration = 0.04;  % Duration of the sync out SniffTrigger
    S.GUI.AOutAirMFC = 2;       %MI#1 Air on
    S.GUI.AOutN2MFC = 1;        %MI#3 N2 on
    S.GUI.SnifVThresh = -0.15;     % Threshold for when Ain will trigger
    S.GUI.SnifVReset = -0.23;     % Threshold for when Ain will reset
    S.GUI.WaterValveTime = 37;
end

% create alternate streams for no-odor and with-odor trialtypes
MaxTrials = 100
StimTypes = ceil(rand(1,MaxTrials)*2);%create array using rand

%%Set AnalogOut and AnalogIn parameters
AOut.OutputRange = '0V:5V';             % min to max range (options in BpodWavePlayer)
AOut.SamplingRate = 1000;              % Hz
AOut.TriggerMode = 'Master';           %Normal, Master, or Toggle
AOut.LoopDuration = [7200 7200 0 0];    %must be set to a finite number to allow for looping (continuous output)
AOut.LoopMode = {'On';'On';'Off';'Off'}; % channels set to loop (as opposed to play out only for buffer length)
%SetAnalogIn parameters
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

%%Turn on MFCs (turned off at end of main loop (currentTrial)
AOut.play(1,1);
AOut.play(2,2);

% set case-select defaults
OdorVialOutput = {'ValveModule2', 1};   %close dummy; flow thru odor+diluent
SwitchByState = 'WaitForLick';         %gets reward if licking in GO Trial

BpodSystem.Data.AnalogData = cell(1,MaxTrials);

for currentTrial = 1:S.GUI.MaxTrials
    disp(currentTrial);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    LoadSerialMessages('AnalogIn1', {['L' 1], ['L' 0]});
    LoadSerialMessages('ValveModule1', {['B' 8], ['B' 16], ['B' 0]});
    LoadSerialMessages('ValveModule2', {['B' 195], ['B' 165], ['B' 153], ['B' 0]});
    
    switch StimTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1        % GO
            OdorVialOutput = {'ValveModule2', 1};   %close dummy; flow thru odor+diluent
            SwitchByState = 'WaitForLick';         %gets reward if licking in GO Trial
        case 2        %NO-GO
            OdorVialOutput = {'ValveModule2', 2}; %close dummy; NO ODOR flow thru diluent only
            SwitchByState = 'WaterBypass4NoGo';
    end
    
    sma = NewStateMachine();
    %sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.GUI.TrigDuration, 'OnsetDelay', 0, 'Channel', 'BNC1');% TTL durstion and source
    
    sma = AddState(sma, 'Name', 'OpenVial', ... % Open olfactometer vial
        'Timer', 0,...
        'StateChangeConditions', {'Tup','WaitForEquilibration'},...
        'OutputActions', {'ValveModule2', 1});
    
    sma = AddState(sma, 'Name', 'WaitForEquilibration', ...     % wait 3 s for odor levels to equilibrate
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'SniffSensorOn'},...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'SniffSensorOn', ...            % start monitoring for sniff
        'Timer', 0,...
        'StateChangeConditions', {'Tup','XSnf0'},...`
        'OutputActions', {'AnalogIn1', 1});%                     % AIn.startLogging
    
    sma = AddState(sma, 'Name', 'XSnf0', ...%                    % Wait for Sniff 0
        'Timer', 0.001,...
        'StateChangeConditions', {'AnalogIn1_1','OpenFV'},...%   %   executes on sniff trigger being exceeded
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'OpenFV', ...%                   % Open FV
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'XSnf1'},...
        'OutputActions', {'BNCState',1,'ValveModule1',1});%      %   Open valve 4 (FV); sends TTL thru StateMachine output 1
    
    sma = AddState(sma, 'Name', 'XSnf1', ...%                    % Wait for Sniff 1
        'Timer', 0,...%
        'StateChangeConditions', {'AnalogIn1_1', 'OdorOff'},...%
        'OutputActions', {}); 

    sma = AddState(sma, 'Name', 'OdorOff', ...                    % Turn off FV, send out second TTL
        'Timer', 0,...
        'StateChangeConditions', {'Tup', SwitchByState},...        %     Case-dependent switch to water delivery or to time-out
        'OutputActions', {'ValveModule1',3});                       %   Close FV
    
    sma = AddState(sma, 'Name', 'WaitForLick', ...                  %WAIT FOR LICK - getting stuck here 5/1/2019
        'Timer', 0.1,...
        'StateChangeConditions', {'Port1In', 'WaterValveOn', 'Tup', 'DrinkingGrace'},... % need to give it two options to go to different states
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'WaterValveOn', ...                 %DELIVER WATER TO MOUSE
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {});%{});
    
    sma = AddState(sma, 'Name', 'Drinking', ...                     % CLOSE VALVE AFTER TIME DETERMINED EARLIER; 
        'Timer', S.GUI.WaterValveTime/1000,...
        'StateChangeConditions', {'Tup', 'DrinkingGrace'},...       
        'OutputActions', {'ValveModule1',2});%

    sma = AddState(sma, 'Name', 'DrinkingGrace', ...                %Add 500 ms for mouse to respond or drink
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', 'TrialEnd'},...
        'OutputActions', {'ValveModule1',3});
    
    sma = AddState(sma, 'Name', 'WaterBypass4NoGo', ...             %jump to here for NoGo trial; adds time out for TimeOutDur
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'TrialEnd'},...
        'OutputActions', {});
    
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
