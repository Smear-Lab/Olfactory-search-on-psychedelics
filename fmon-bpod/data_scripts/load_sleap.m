function [tracking] = load_sleap(mouse_id, session)
    % Import Prelimary SLEAP Tracking
    % 100-0 condition
    %path = "S:/fmon_data/" + num2str(mouse_id) + "/100-0/" + num2str(session) + "/";
    % Prelim SLEAP analysis CSVs
    filename = "S:/fmon_sleap/predictions/csv/mouse_" + num2str(mouse_id) + "_session_" + num2str(session) + ".analysis.csv";
    
    %% Load sleap CSV
    % Supressing warning about automatic column name renaming
    warning('off', 'all');
    sleap_csv = readtable(filename);
    warning('on', 'all');
    % Temporary: just load head and tail_base 
    tracking = sleap_csv(:,[7 8 13 14]);

end