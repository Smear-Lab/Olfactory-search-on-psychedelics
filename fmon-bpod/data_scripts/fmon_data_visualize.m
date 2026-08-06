%% Preview FMON Data as time series

% Set window
w_beg = 30000;
w_end = 50000; %height(FMON_data); % Full session

% Normalize sniff signal
sniff_scaled = normalize(FMON_data.sniff_signal);

% Sniff Signal resampled to 80hz
plot(sniff_scaled(w_beg:w_end), 'DisplayName', 'Sniff')
hold on

% Final Valve Toggle
plot(FMON_data.odor(w_beg:w_end) * .5, 'DisplayName', 'Final Valves')
hold on

% Poke Activity
plot(FMON_data.left_poke(w_beg:w_end), 'DisplayName', 'Left Poke')
hold on
plot(FMON_data.right_poke(w_beg:w_end), 'DisplayName', 'Right Poke')
hold on
plot(FMON_data.init_poke(w_beg:w_end) * .25, 'DisplayName', 'Init. Poke')
hold on

% ITI True/False
plot(FMON_data.iti(w_beg:w_end) * .25, 'DisplayName', 'ITI')

% Correct/Incorrect
plot(FMON_data.trial_correct(w_beg:w_end) * 1, 'DisplayName', 'Correct')

% Trial Type: 1=Left, 2=Right, 3=Omit
plot(FMON_data.trial_type(w_beg:w_end) * 1, 'DisplayName', 'Trial Type')
legend('show');

xlim([0, w_end-w_beg])

%% Preview SLEAP FMON data 

%% Normalize function
function [y] = normalize(x)

    % Define the new minimum and maximum
    a = -1.5;
    b = 0;
    
    % Normalize x to [a, b]
    y = a + ((x - min(x)) / (max(x) - min(x))) * (b - a);
end
