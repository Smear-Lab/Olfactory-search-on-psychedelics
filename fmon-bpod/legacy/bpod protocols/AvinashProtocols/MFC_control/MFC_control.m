function MFC_control
global BpodSystem
clear AOut
%% set up GUI variables
%Variables
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    S.GUI.OutputRange = '0V:5V';    %number of cycles
    S.GUI.SamplingRate = 1000;        %channel for A2D Sniff input
    S.GUI.TriggerMode = 'Master';     % channel for Sniff Trigger TTL output
    S.GUI.LoopDuration = 7200;  % Duration of the sync out SniffTrigger
    S.GUI.LoopMode = {'On';'On';'Off';'Off'};       %MI#1 Air on
    S.GUI.MFC_Flow1 = 100;        %MI#3 N2 on
    S.GUI.MFC_Flow2 = 900;
    S.GUI.MFC_Manual = 1;
end

AOut = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1); %shorter version of last 2 lines
AOut.OutputRange = '0V:5V';             % min to max range (options in BpodWavePlayer)
AOut.SamplingRate = S.GUI.SamplingRate;              % Hz
%AOut.Waveforms{1} = ones(1, 1000)*AOut.Amplitude;      % load array of ones into first of 64 available cells
AOut.TriggerMode = 'Master';           %Normal, Master, or Toggle
%A.TriggerMode = 'Master';           %can change voltage with 'play'; or
%'Toggle can turn the output on or off with the 'play' command
AOut.LoopDuration = [S.GUI.LoopDuration S.GUI.LoopDuration 0 0];
AOut.LoopMode = {'On';'On';'Off';'Off'};
BpodParameterGUI('init', S);
%preload voltages to WavePlayer buffers at steps of 100mV each
for n = 1:50
    AOut.loadWaveform(n, ones(1, 1000)*(5*n/50));
end
n = 1
for n = 1:1000
    if S.GUI.MFC_Manual == 1;
        S = BpodParameterGUI('sync', S);
        disp(n);
        keyboard;
        AOut.play (1, 50*S.GUI.MFC_Flow1/100);
        AOut.play (2, 50*S.GUI.MFC_Flow2/1000);
    else 
        disp(n)
    end
    n = n+1
end    
AOut.stop()
clear AOut
