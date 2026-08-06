function [resampled_FMON_table] = process_data(poke_dat, sniff_dat, S)
% Process and align FMON data 

%% Build logical vectors from NiDAQ data
left_poke = poke_dat(1,:) > .25;
right_poke = poke_dat(2,:) > .25;
init_poke = poke_dat(3,:) > .25;
final_vlv = sniff_dat(3,:) > 1;

% Get number of trials and NiDAQ data vector length
ntrials = S.session_data.nTrials; % Number of trials in session
dat_len = length(init_poke);

%% Pull out analog sniff signal
sniff_signal = sniff_dat(1,:);

%% Align Bpod data and pull out event data
first_poke_bonsai = find(init_poke == 1, 1, 'first'); % Get the first poke as recorded by Bonsai
first_poke_bpod = S.session_data.RawEvents.Trial{1, 1}.States.WaitForInitPoke(2) * 800; % Get the first poke as recorded by Bpod

% Pull out trial start timestamp
trial_starts = S.session_data.TrialStartTimestamp * 800; % Copy trial start timestamps from bpod mat & Set to 800 hz sample rate
ts_offset = first_poke_bonsai - trial_starts(1); % Get difference between first trial start time and first Bonsai poke
trial_starts = trial_starts + ts_offset; % Align Bpod start times to bonsai first poke 
trial_starts = round(trial_starts - first_poke_bpod); % then subtract by bpod first poke

% Further align Bpod and Bonsai using first pokes
% Fine tune may not be needed now
first_poke_bpod = round(first_poke_bpod + trial_starts(1)); % Put Bpod first poke in continuous time by adding first trial start
fine_tune = first_poke_bonsai - first_poke_bpod; % Fine tune alignment by comparing first pokes
trial_starts = trial_starts + fine_tune; % Adjust trial starts by fine tune offset 

%% Build full-length vector of Init pokes

% Pull out init pokes for each trial
init_pokes_bpod = zeros(1, ntrials);

for ii = 1:ntrials
    init_pokes_bpod(ii) = S.session_data.RawEvents.Trial{1, ii}.States.WaitForInitPoke(2) * 800;
end

% Put into continuous time
init_pokes_bpod = round(trial_starts + init_pokes_bpod);

%% Build full-length vector to record end of drinking event

% Pull out ConfirmPortOut for each trial. Event starts ITI
drink_out_bpod = zeros(1, ntrials);

% If ConfirmPortOut is not NaN, record time, if ConfirmPortOut is NaN
% record -dat_len for later removal.
for ii = 1:ntrials
    if ~isnan(S.session_data.RawEvents.Trial{1, ii}.States.Drinking(2))
        drink_out_bpod(ii) = S.session_data.RawEvents.Trial{1, ii}.States.Drinking(2) * 800;
    else
        drink_out_bpod(ii) = -dat_len;
    end
end

% Create vector of Bpod Init Pokes
drink_out_bpod = round(trial_starts + drink_out_bpod);
% Filter out trials where ITI started after 5 sec drinking timeout 
% rather than ConfirmPortOut
drink_out_bpod = drink_out_bpod(drink_out_bpod > 0);

%% Get list of ITIs from Bpod Session Data

% Make cell to store ITI [start, end] pairs
iti_ts = cell(ntrials, 1);

% Pull ITI pairs from Bpod Struct
for ii = 1:S.session_data.nTrials
    iti_ts{ii} = S.session_data.RawEvents.Trial{1, ii}.States.ITI([1, 2]);
    iti_ts{ii} = round(iti_ts{ii} * 800 + trial_starts(ii)); % Convert to 800 hz
    iti_ts{ii}(2) = iti_ts{ii}(2) + 1200; % Add 1.5 second odor reset period to ITI total duration
end

% Build logical vector of ITI periods
iti_logical = false(1, dat_len); % Use init_poke to get full session length 

% Loop through each cell and set relevant indices to 1
for i = 1:ntrials
    start_time = iti_ts{i}(1);
    end_time = iti_ts{i}(2);
    
    % Convert time to indices
    start_idx = round(start_time);
    end_idx = round(end_time);
    
    % Set values to 1
    iti_logical(start_idx:end_idx) = 1;
end

%% Build full-length vector of trial number
trial_num = zeros(1, dat_len);
for ii = 1:ntrials-1
    trial_num(trial_starts(ii):trial_starts(ii+1)) = ii;
end

% Set tails
trial_num(1:trial_starts(1)) = 1;
trial_num(trial_starts(ntrials):end) = ntrials;

%% Build vector of trial type
trial_type_list = zeros(1, ntrials);

for ii = 1:ntrials

    if ~isnan(S.session_data.RawEvents.Trial{1, ii}.States.GoLeft(1))
        trial_type_list(ii) = 1; % 1 = GoLeft
    elseif ~isnan(S.session_data.RawEvents.Trial{1, ii}.States.GoRight(1))
        trial_type_list(ii) = 2; % 2 = GoRight
    elseif ~isnan(S.session_data.RawEvents.Trial{1, ii}.States.Omission(1))
        trial_type_list(ii) = 3; % 3 = Bilateral omission
    end

end

% Put in continuous time
trial_type = zeros(1, dat_len);

for ii = 1:ntrials-1
    trial_type(trial_starts(ii):trial_starts(ii+1)) = trial_type_list(ii);
end

% Set tails
trial_type(1:trial_starts(1)) = trial_type_list(1);
trial_type(trial_starts(ntrials):end) = trial_type_list(end);

%% Build vector of correct/incorrect trials
trial_outcome_list = zeros(1, ntrials);

for ii = 1:ntrials

    if ~isnan(S.session_data.RawEvents.Trial{1, ii}.States.CorrectLeft(1))
        trial_outcome_list(ii) = 1; % 1 = Correct Left
    elseif ~isnan(S.session_data.RawEvents.Trial{1, ii}.States.CorrectRight(1))
        trial_outcome_list(ii) = 1; % 2 = Correct Right
    elseif ~isnan(S.session_data.RawEvents.Trial{1, ii}.States.NoReward(1))
        trial_outcome_list(ii) = 0; % 3 = Incorrect
    end

end

% Put in continuous time
trial_outcome = zeros(1, dat_len);

for ii = 1:ntrials-1
    trial_outcome(trial_starts(ii):trial_starts(ii+1)) = trial_outcome_list(ii);
end

% Set tails
trial_outcome(1:trial_starts(1)) = trial_outcome_list(1);
trial_outcome(trial_starts(ntrials):end) = trial_outcome_list(end);

%% Add returned data to table and resample to match video frames
%trial_num, trial_type, trial_outcome, left_poke,... 
%right_poke, init_poke, final_vlv, sniff_signal

% Build table
FMON_table = table(); 
FMON_table.trial_num = trial_num';
FMON_table.trial_type = trial_type';
FMON_table.trial_correct = trial_outcome';
FMON_table.left_poke = left_poke';
FMON_table.right_poke = right_poke';
FMON_table.init_poke = init_poke';
FMON_table.odor = final_vlv(1:dat_len)';
FMON_table.iti = iti_logical';
FMON_table.sniff_signal = sniff_signal(1:dat_len)';

% Resample to match 80hz video
dataArray = table2array(FMON_table);
[numRows, numCols] = size(dataArray);
newNumRows = round(dat_len / 10);  % The number of rows in the resampled data

% Initialize an array to hold the resampled data
resampledArray = zeros(newNumRows, numCols);

% Define original and new time vectors
originalTime = linspace(1, numRows, numRows);
newTime = linspace(1, numRows, newNumRows);

% Resample each column
for col = 1:numCols
    resampledArray(:, col) = interp1(originalTime, dataArray(:, col), newTime, 'spline');
end

% This code resamples rather than interpolates, and produces edge effects
% dataArray = table2array(FMON_table);
% [numRows, numCols] = size(dataArray);
% newNumRows = round(dat_len/10); % The number of rows in the resampled data
% resampledArray = zeros(newNumRows, numCols);
% for col = 1:numCols
%     resampledArray(:, col) = resample(dataArray(:, col), newNumRows, numRows, 'spline');
% end

% Resampled table
resampled_FMON_table = array2table(resampledArray, 'VariableNames', FMON_table.Properties.VariableNames);
resampled_FMON_table(:, 1:7) = round(resampled_FMON_table(:, 1:7));


end