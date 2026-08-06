function ASD_FaceTracking     
%Avinash Bala Sep 2020. Function runs Odor delivery using the bpod
%system. Requires the following modules:
% (1) State Machine; (2) Valve Module 1; (3) Valve Module 2; (4) Analog
% Output (Wave Player); (5) Analog In 
% bpod GUI controls trial-to-trial variables. Run using bpod control panel
%sends TTL to camera for on=screen indication of odor delivery

global BpodSystem
global AOut

%% Turn on AnalogIn and AnalogOut
AIn = BpodAnalogIn(BpodSystem.ModuleUSB.AnalogIn1);  %Init Analog in
% NOTE - Analog Out is not used in this script - lines 49-43 and 58-61 also
% commented out
% AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); %Init Analog Out (aka WavePlayer)
guiname = 'Input Session variables';
prompt = {'Sniff trigger activation value (Volts)', 'Sniff trigger reset value (Volts) - usually negative', 'Number of trials'};
numlines = 1;
defaultanswer = {num2str(0.0), num2str(-0.025), num2str(100)};
options.Resize = 'on'; options.WindowStyle = 'normal'; options.Interpreter = 'tex';
answer = inputdlg(prompt,guiname,numlines,defaultanswer,options);
SniffTrig_Value = str2double(answer{1});SniffTrig_Reset = str2double(answer{2}); MaxTrials_Value = str2double(answer{3});

%Set GUI Variables - updated every loop
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.MaxTrials = MaxTrials_Value;    %number of cycles
    S.GUI.CurrentTrial = 1; 
    S.GUI.TimeOutDur = 3;       %timeout mouse gets if it licks after a no-odor trial
    S.GUI.AInSniffIn = 1;        %channel for A2D Sniff input
    S.GUI.SniffTrigOut = 1;     % channel for Sniff Trigger TTL output
    S.GUI.TrigDuration = 0.04;  % Duration of the sync out SniffTrigger
    S.GUI.AOutAirMFC = 2;       %MI#1 Air on
    S.GUI.AOutN2MFC = 1;        %MI#3 N2 on
    S.GUI.SnifVThresh = SniffTrig_Value;     % Threshold for when Ain will trigger
    S.GUI.SnifVReset = SniffTrig_Reset;     % Threshold for when Ain will reset
    S.GUI.WaterValveTime = 37;
end

% create alternate streams for no-odor and with-odor trialtypes


%%Set AnalogOut and AnalogIn parameters ***COMMENTED OUT - NOT USED
% AOut.OutputRange = '0V:5V';             % min to max range (options in BpodWavePlayer)
% AOut.SamplingRate = 1000;              % Hz
% AOut.TriggerMode = 'Master';           %Normal, Master, or Toggle
% AOut.LoopDuration = [7200 7200 0 0];    %must be set to a finite number to allow for looping (continuous output)
% AOut.LoopMode = {'On';'On';'Off';'Off'}; % channels set to loop (as opposed to play out only for buffer length)
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
% Set MFC flow rates  ***COMMENTED OUT - NOT USED
%Turn MFCs on
% MFC_Flow1 = 100; AOut.loadWaveform(1, ones(1, 1000)*(5*MFC_Flow1/100));
% MFC_Flow2 = 900; AOut.loadWaveform(2, ones(1, 1000)*(5*MFC_Flow2/1000));
% AOut.play(1,1);
% AOut.play(2,2);

% Create variable that defines trial types; save to file with unique name
OdorVials = []; OdorVials.num = [1, 2, 3, 4]; OdorVials.name = {'Pinene', '2-PE', 'Blank', '2-MB'};
InitTrialsBatch = 20;
StimTypes = ones(1, 100)*NaN; 
StimTypes(1:InitTrialsBatch) = 3;
StimTypes(21:100) = ceil(rand(1,(S.GUI.MaxTrials-InitTrialsBatch))*4);% create list of trial types (which valve to open) using RAND
OdorVialOutput = {'ValveModule2', 1};   %close dummy; flow thru odor+diluent
date_String = datetime;date_String.Format = 'yyMMdd_HHmm';
StimTypes_FName = [char(string(date_String)),'_StimTypes.mat'];
save(StimTypes_FName,'StimTypes')

%initialize bpod system
BpodNotebook('init'); % Initialize Bpod notebook (for manual data annotation)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
% Aug 26 --------------------so far
%% Main loop (runs once per trial)

for currentTrial = 1:S.GUI.MaxTrials
    disp(currentTrial);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    LoadSerialMessages('AnalogIn1', {['L' 1], ['L' 0]});
    LoadSerialMessages('ValveModule1', {['O' 4], ['B' 0], ['B' 129], ['B' 137]}); %FV open; all closed
    LoadSerialMessages('ValveModule2', {['B' 195], ['B' 165], ['B' 153], ['B' 0], ['B' 129]}); % (NO+Valve1); (NO+Valve2); (NO+Valve3); NO-open+AllOthers
    
    switch StimTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1        % Pinene
            OdorVialOutput = {'ValveModule2', 1}; 
            FVOutput = {'ValveModule1', 1}%open FV
        case 2        %2-phenylethanol 
            OdorVialOutput = {'ValveModule2', 2}; %close dummy; NO ODOR flow thru diluent only
            FVOutput = {'ValveModule1', 1}%open FV
        case 3        %Blank
            OdorVialOutput = {'ValveModule2', 3}; %close dummy; NO ODOR flow thru diluent only
            FVOutput = {'ValveModule1', 1}%open FV
        case 4        %2-mb
            OdorVialOutput = {'ValveModule2', 5, 'ValveModule1', 3}; %close dummy; NO ODOR flow thru diluent only
            FVOutput = {'ValveModule1', 1}%open FV+Vial 4 (vial 4 = module1, valves 1 & 8)
    end
    disp(['Trial coming up with Vial ',num2str(StimTypes(currentTrial)),' (Odor = ', char(OdorVials.name(StimTypes(currentTrial))),')']);
    sma = NewStateMachine();
    %sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.GUI.TrigDuration, 'OnsetDelay', 0, 'Channel', 'BNC1');% TTL durstion and source
    
    sma = AddState(sma, 'Name', 'OpenVial', ... % Open olfactometer vial
        'Timer', 0,...
        'StateChangeConditions', {'Tup','SniffSensorOn'},...% open odor vial as dictated by random order in variable 'StimTypes'
        'OutputActions', OdorVialOutput);
    
    sma = AddState(sma, 'Name', 'SniffSensorOn', ...            % start monitoring for sniff
        'Timer', 0,...
        'StateChangeConditions', {'Tup','WaitForEquilibration'},...`
        'OutputActions', {'BNCState',1,'AnalogIn1', 1});%        % AIn.startLogging; send BNC out to trigger on-camera LED
        
    sma = AddState(sma, 'Name', 'WaitForEquilibration', ...     % wait 3 s for odor levels to equilibrate
        'Timer', 5,...
        'StateChangeConditions', {'Tup', 'XSnf0'},...
        'OutputActions', {});
%     
%     sma = AddState(sma, 'Name', 'SniffSensorOn', ...            % start monitoring for sniff
%         'Timer', 0,...
%         'StateChangeConditions', {'Tup','XSnf0'},...`
%         'OutputActions', {'AnalogIn1', 1});%                     % AIn.startLogging
    
    sma = AddState(sma, 'Name', 'XSnf0', ...%                    % Wait for Sniff 0
        'Timer', 0.001,...
        'StateChangeConditions', {'AnalogIn1_1','OpenFV'},...%   %   executes on sniff trigger being exceeded
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'OpenFV', ...%                   % Open FV
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'FVOpenTime'},...
        'OutputActions', FVOutput);%      %   Open valve 4 (FV); sends TTL thru StateMachine output 1
    
    sma = AddState(sma, 'Name', 'FVOpenTime', ...     % wait 3 s for odor levels to equilibrate
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', 'OdorOff'},...
        'OutputActions', {});

    sma = AddState(sma, 'Name', 'OdorOff', ...                    % Turn off FV, send out second TTL
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'CloseVials'},...        %     
        'OutputActions', {'ValveModule1',2});                       %   Close FV

    sma = AddState(sma, 'Name', 'CloseVials', ...                    % Turn off all vials in olfactometer; flow is now back thru NO
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'RecordSniff_PostTrial'},...
        'OutputActions', {'ValveModule2',4});                       %   Close vials
 
    sma = AddState(sma, 'Name', 'RecordSniff_PostTrial', ...                     %record sniff for 5 sec ('ITI')
        'Timer', 5,...
        'StateChangeConditions', {'Tup', 'AnalogOff'},...
        'OutputActions', {}); 
    
    sma = AddState(sma, 'Name', 'AnalogOff', ...                     %record sniff for 5 sec ('ITI')
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'TrialEnd'},...
        'OutputActions', {'AnalogIn1', 2}); 
    
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
%     pause (5);
end