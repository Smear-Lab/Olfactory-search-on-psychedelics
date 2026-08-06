% Set Mouse data to analyze
mouse_id = 2196;
session = 11;
path = "S:/fmon_data/" + num2str(mouse_id) + "/100-0/" + num2str(session) + "/";

% Load Nidaq Data
[sniff_dat, poke_dat] = load_nidaq(mouse_id, session);

% Load Bpod Session Data Struct
S = load_bpod(mouse_id, session);

% Load SLEAP Tracking
SLEAP_data = load_sleap(mouse_id, session);

% Process NiDAQ and Bpod data
FMON_data = process_data(poke_dat, sniff_dat, S);

% Concatenate data tables (trim FMON data to match SLEAP length)
FMON_data = horzcat(FMON_data(1:height(SLEAP_data),:), SLEAP_data);

% Write to CSV
writetable(FMON_data, path + num2str(mouse_id) + "_" + num2str(session) + ".csv");

