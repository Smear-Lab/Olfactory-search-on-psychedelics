%{
FMON Data Output
Creates directories and saves data once experiment ends

Written By: Nate Gonzales-Hess (nhess@uoregon.edu)
Last Updated: 7/6/2023
%}
%Clear Bpod TCP Socket
BpodSystem.BonsaiSocket = [];

%% Give time for Bonsai to stop;
java.lang.Thread.sleep(3000);

%% Read in variables from base workspace
BpodSystem = evalin('base', 'BpodSystem');
experimenter = evalin('base', 'experimenter');
trainer = evalin('base', 'trainer');
protocol = evalin('base', 'protocol');
mouse_sex = evalin('base', 'mouse_sex');
mouse_id = evalin('base', 'mouse_id');
initial_weight = evalin('base', 'initial_weight');
thermistor_type = evalin('base','thermistor_type');
odorant = evalin('base', 'odorant');
sniffing = evalin('base', 'sniffing');
side_bias = evalin('base', 'side_bias');
LeftValveVolume = evalin('base', 'LeftValveVolume');
RightValveVolume = evalin('base', 'RightValveVolume');
InitValveVolume = evalin('base', 'InitValveVolume');
drug_dose = evalin('base', 'drug_dose');
drug_dose_total = evalin('base', 'drug_dose_total');


% Set fmon_task as false to ignore decision counts in notes.txt
fmon_task = evalin('base', 'fmon_task_toggle');

%% Create Mouse ID Folder
folderName = 'D:/FMON_data/' + string(mouse_id);
if ~exist(folderName, 'dir')
    mkdir(folderName);
end

%% Create Protocol Folder
folderName = 'D:/FMON_data/' + string(mouse_id) + '/' + protocol;
if ~exist(folderName, 'dir')
    mkdir(folderName);
end

%% Create Session Folder

% Starting folder number
folderNum = 1;

% Loop until we find a folder number that doesn't exist
while exist(fullfile(folderName, num2str(folderNum)), 'dir') == 7
    folderNum = folderNum + 1;
end

% Create the new folder
mkdir(folderName, num2str(folderNum));

% Open or create a new text file. 'w' indicates write mode.
data_directory = folderName + '/' + num2str(folderNum) + '/';

%% Save BpodSystem Data
session_data = BpodSystem.Data;
save(data_directory + 'BpodSessionData.mat', 'session_data') % Maybe copy most recent file as with video?

%% Build Trial Summarry
if isfield(BpodSystem.Data, 'TrialTypes')

    trialtypes = BpodSystem.Data.TrialTypes';
    n = length(trialtypes);
    trialcount = (1:n)';
    start_time = zeros(1, n)';
    end_time = zeros(1, n)';
    iti_time = zeros(1, n)';

    % Vectors for trial initiation and end timestamp
    for i = 1:length(trialtypes)
        iti_time(i) = round(session_data.RawEvents.Trial{1, i}.States.ITI(2) - session_data.RawEvents.Trial{1, i}.States.ITI(1));
        trial_start = session_data.TrialStartTimestamp(i); 
        trial_end = session_data.TrialEndTimestamp(i) - iti_time(i); 
        start_time(i) = trial_start;
        end_time(i) = trial_end;
    end

    % Concatenate Vectors
    summary_mat = horzcat(trialcount, trialtypes, start_time, end_time, iti_time);

    % Save the matrix to a CSV file
    writematrix(summary_mat, data_directory + 'trialsummary.csv');
end

%% Write summary to notes.txt

fileID = fopen(data_directory + 'notes.txt', 'w');

% Check if file opened successfully
if fileID == -1
    error('Failed to open file.');
end

% Note Content
exp = 'Experimenter: ' + string(experimenter);
trn = 'Trainer: ' + string(trainer);
sex = 'Mouse sex: ' + string(mouse_sex);
date = 'Date: ' + string(datetime('now'));
mouse = 'Mouse ID: ' + string(mouse_id);
weight = 'Initial Weight: ' + string(initial_weight);
bias = 'Side Bias: ' + string(side_bias);
odor = 'Odorant: ' + string(odorant);
sniff = 'Sniffing: ' + string(sniffing);
therm = 'Thermistor Type: ' + string(thermistor_type); 
session = ['Session: ', num2str(folderNum)];
drug_dosage = 'Drug Dose: ' + string(drug_dose);
drug_total = 'Total Injection: ' + string(drug_dose_total);

h2o_calib = 'WATER CALIBRATION';
l_port = ['Left Port: ', num2str(LeftValveVolume*10)];
r_port = ['Right Port: ', num2str(RightValveVolume*10)];
i_port = ['Initiation Port: ', num2str(InitValveVolume*10)];

% Get L/R Tallies
left_correct = 0;
left_total = 0;
right_correct = 0;
right_total = 0;

% Loop through trials and count only if event was triggered (is not NaN)
if fmon_task == true
    for ii = 1:length(trialtypes)
        if ~isnan(session_data.RawEvents.Trial{1, ii}.States.GoLeft)
            left_total = left_total + 1;
            if ~isnan(session_data.RawEvents.Trial{1, ii}.States.CorrectLeft)
                left_correct = left_correct + 1;
            end
        end
        if ~isnan(session_data.RawEvents.Trial{1, ii}.States.GoRight)
            right_total = right_total + 1;
            if ~isnan(session_data.RawEvents.Trial{1, ii}.States.CorrectRight)
                right_correct = right_correct + 1;
            end
        end
    end
   
left_ratio = ['L: ', num2str(left_correct), '/', num2str(left_total)];
right_ratio = ['R: ', num2str(right_correct), '/', num2str(right_total)];

else % Assign blank strings
        left_ratio = '';
        right_ratio = '';
end
        
% Write the text to the file
fprintf(fileID, '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n%s\n\n%s\n\n%s\n%s',...
    exp, trn, sex, date, mouse, weight, bias, session, odor, sniff, therm, drug_dosage, drug_total,...
    h2o_calib, l_port, r_port, i_port, 'Experimenter Notes:',...
    left_ratio, right_ratio);

% Close the file
fclose(fileID);

%% Open Notepad to display the file
notes_filename = data_directory + 'notes.txt';
system("start %windir%\system32\notepad.exe " + notes_filename);
%winopen(notes_filename);

%% Copy Newest Video and DAQ Files to session data directory
java.lang.Thread.sleep(5000); % Give time for Bonsai to save
% Specify the directory
folder = 'F:\rawvideos\';

% Get a list of all files in the folder
files = dir(folder);

% Filter out directories
files = files(~[files.isdir]);

% Find the newest file
[~,index] = max([files.datenum]);
video = files(index).name;

% DAQ and Timestamp files
sniff_dat = "NiDAQ_sniff.dat";
poke_dat = "NiDAQ_poke.dat";
camera_timestamp = "rawvideo.txt";

% Check if DAQ files exist, move to data dir if so
if isfile("D:/" + sniff_dat)
    copyfile("D:/" + sniff_dat, data_directory + sniff_dat);
end

if isfile("D:/" + poke_dat)
    copyfile("D:/" + poke_dat, data_directory + poke_dat);
end

% Check if camera timestamp files exists, move to data dir if so
if isfile("D:/" + camera_timestamp)
    copyfile("D:/" + camera_timestamp, data_directory + camera_timestamp);
end

% Copy video to data dir
copyfile("F:/rawvideos/" + video, data_directory + video);

%%
disp('Data successfully saved.')